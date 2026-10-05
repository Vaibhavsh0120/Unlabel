import json

import httpx
import pytest

from app.core.config import Settings
from app.providers.products.nutrition import NutritionProvider
from app.providers.products.open_food_facts import OpenFoodFactsProvider


def table(per="100g", preparation="as_sold", source="packaging", **nutrients):
    return {
        "per": per,
        "preparation": preparation,
        "source": source,
        "per_quantity": 100 if per != "serving" else 40,
        "per_unit": "ml" if per == "100ml" else "g",
        "nutrients": nutrients,
    }


async def lookup(product=None, status=200, exception=None):
    def handle(request):
        assert request.url.host == "world.openfoodfacts.org"
        assert request.url.path == "/api/v3.6/product/0123456789012.json"
        assert "nutrition" in request.url.params["fields"]
        if exception:
            raise exception
        return httpx.Response(
            status, content=json.dumps({"status": "success", "product": product}).encode()
        )

    async with httpx.AsyncClient(transport=httpx.MockTransport(handle)) as client:
        return await NutritionProvider(
            OpenFoodFactsProvider(client, Settings(_env_file=None))
        ).lookup("0123456789012")


def product(*tables):
    return {"code": "0123456789012", "nutrition": {"input_sets": list(tables)}}


async def test_direct_values_keep_zero_missing_source_and_separate_volume_prepared_tables():
    result = await lookup(
        product(
            table(fat={"value": 0, "unit": "g"}, sugars={"value": 12, "unit": "g"}),
            table("100ml", "prepared", proteins={"value": 4, "unit": "g"}),
        )
    )
    assert result.status == "found"
    assert result.snapshot.status == "partial"
    a, b = result.snapshot.tables
    assert a.nutrients["fat"].value == 0
    assert a.nutrients["added_sugars"].value is None
    assert a.normalized_basis.unit == "g"
    assert b.normalized_basis.unit == "mL"
    assert b.preparation == "as_prepared"
    assert result.input_tables[0].provider_source == "packaging"
    assert result.assessment_basis == "open_food_facts_community_data"
    assert result.source.database_license == "ODbL-1.0"


async def test_aggregate_computed_estimate_and_qualified_values_are_not_exact_facts():
    data = product(
        table(
            sugars={"value_computed": 6, "unit": "g"},
            fat={"value": 1, "unit": "g", "modifier": "<"},
        ),
        table(source="estimate", **{"added-sugars": {"value": 0, "unit": "g"}}),
    )
    data["nutrition"]["aggregated_set"] = {"nutrients": {"sugars": {"value": 100}}}
    result = await lookup(data)
    assert result.status == "found"
    assert result.snapshot.tables[0].nutrients["sugars"].value is None
    assert result.snapshot.tables[0].nutrients["fat"].value is None
    assert result.snapshot.tables[0].nutrients["added_sugars"].value is None
    assert "qualified_value_excluded" in result.warnings
    assert "unsupported_table_source" in result.warnings


@pytest.mark.parametrize("value", [True, "3", -1])
async def test_bad_provider_numbers_remain_unknown(value):
    result = await lookup(product(table(fat={"value": value, "unit": "g"})))
    assert result.status == "found"
    assert result.snapshot.tables[0].nutrients["fat"].value is None
    assert "invalid_nutrient_value" in result.warnings


@pytest.mark.parametrize("token", ["1e-400", "NaN", "Infinity", "1e-99999999999999999999"])
async def test_invalid_json_numeric_tokens_are_incompatible_not_zero(token):
    def handle(request):
        raw = json.dumps(product(table(fat={"value": 7, "unit": "g"})))
        raw = raw.replace('"value": 7', f'"value": {token}')
        return httpx.Response(200, content='{"status":"success","product":' + raw + "}")

    async with httpx.AsyncClient(transport=httpx.MockTransport(handle)) as client:
        result = await NutritionProvider(
            OpenFoodFactsProvider(client, Settings(_env_file=None))
        ).lookup("0123456789012")
    assert result.status == "incompatible_response"
    assert result.snapshot is None


async def test_sparse_product_and_legacy_flat_fields_are_unknown_not_guessed():
    result = await lookup({"code": "0123456789012", "nutriments": {"sugars_100g": 3}})
    assert result.status == "found"
    assert result.snapshot.tables == []
    assert "nutrition_input_sets_missing" in result.warnings


@pytest.mark.parametrize(
    ("status", "expected"), [(404, "not_found"), (429, "rate_limited"), (503, "unavailable")]
)
async def test_nutrition_failures_match_existing_provider_contract(status, expected):
    result = await lookup(status=status)
    assert result.status == expected
    assert result.snapshot is None


async def test_unrelated_identity_and_timeout_do_not_produce_nutrition():
    mismatch = await lookup({"code": "9876543210987"})
    assert mismatch.status == "incompatible_response"
    timeout = await lookup(exception=httpx.ReadTimeout("provider-private"))
    assert timeout.status == "unavailable"
    assert "provider-private" not in timeout.model_dump_json()


async def test_table_budget_and_ambiguous_basis_are_unknown():
    too_many = await lookup(product(*[table()] * 17))
    assert too_many.snapshot.tables == []
    assert "nutrition_input_sets_invalid" in too_many.warnings
    bad = table(fat={"value": 1, "unit": "g"})
    bad["per_unit"] = "ml"
    result = await lookup(product(bad))
    assert result.snapshot.tables == []
    assert "invalid_table_basis" in result.warnings


async def test_many_supported_tables_stay_inside_output_row_budget():
    nutrients = {
        "energy-kcal": {"value": 100, "unit": "kcal"},
        "energy-kj": {"value": 418.4, "unit": "kJ"},
        **{
            key: {"value": 1, "unit": "g"}
            for key in (
                "fat",
                "saturated-fat",
                "carbohydrates",
                "carbohydrates-total",
                "sugars",
                "added-sugars",
                "fiber",
                "proteins",
                "sodium",
                "salt",
            )
        },
    }
    result = await lookup(product(*[table(**nutrients)] * 16))
    assert result.status == "found"
    assert len(result.snapshot.original_rows) <= 64
    assert "nutrition_row_budget_exceeded" in result.warnings


async def test_energy_unit_key_mismatch_is_not_normalized_as_a_fact():
    result = await lookup(product(table(**{"energy-kcal": {"value": 100, "unit": "kJ"}})))
    assert result.snapshot.tables[0].nutrients["energy"].value is None
    assert "invalid_nutrient_value" in result.warnings


async def test_empty_provider_table_does_not_invent_an_original_nutrient_row():
    result = await lookup(product(table()))
    assert result.snapshot.original_rows == []
    assert result.snapshot.tables[0].nutrients["energy"].reason == "not_reported"


async def test_disagreeing_provider_tables_are_preserved_and_flagged_for_review():
    result = await lookup(
        product(table(fat={"value": 2, "unit": "g"}), table(fat={"value": 4, "unit": "g"}))
    )
    assert [t.nutrients["fat"].value for t in result.snapshot.tables] == [2, 4]
    assert result.snapshot.status == "needs_correction"
    assert "provider_tables_disagree" in result.warnings
