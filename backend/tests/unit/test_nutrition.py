from copy import deepcopy

import pytest
from pydantic import ValidationError

from app.schemas.nutrition import NormalizeRequest, NutrientRow
from app.services.parsing.nutrition import normalize_rows


def row(**overrides):
    payload = {
        "row_id": "protein-1",
        "table_id": "back-table",
        "nutrient": "protein",
        "value": 5,
        "unit": "g",
        "basis": {"kind": "quantity", "amount": 100, "unit": "g"},
        "preparation": "as_sold",
    }
    payload.update(overrides)
    return NutrientRow.model_validate(payload)


def request_payload():
    return {
        "schema_version": "1",
        "client_request_id": "37fb20bb-927d-4a01-8b96-f4097b64a946",
        "capture_session_id": "b7a110fe-033e-4ba2-8fb9-856fc5501e85",
        "input_revision": 0,
        "confirmed": True,
        "completeness": "complete",
        "rows": [row().model_dump(mode="json")],
    }


def test_mass_serving_normalizes_to_100g_and_retains_original_rows():
    submitted = row(basis={"kind": "serving", "amount": 40, "unit": "g"}, value=5.6)
    snapshot = normalize_rows([submitted], completeness="complete")
    table = snapshot.tables[0]
    assert snapshot.status == "complete"
    assert table.original_basis.kind == "serving"
    assert table.original_basis.amount == 40
    assert table.normalized_basis.model_dump() == {"kind": "quantity", "amount": 100, "unit": "g"}
    assert table.nutrients["protein"].value == 14
    assert table.nutrients["protein"].source_row_ids == ["protein-1"]
    assert snapshot.original_rows == [submitted]


def test_volume_basis_stays_volume_and_uses_no_density_assumption():
    snapshot = normalize_rows(
        [row(basis={"kind": "quantity", "amount": 250, "unit": "mL"}, value=8)]
    )
    table = snapshot.tables[0]
    assert table.normalized_basis.unit == "mL"
    assert table.normalized_basis.amount == 100
    assert table.nutrients["protein"].value == 3.2
    assert len(snapshot.tables) == 1


@pytest.mark.parametrize(
    ("nutrient", "value", "unit", "expected"),
    [("energy", 418.4, "kJ", 100), ("sodium", 120, "mg", 0.12), ("salt", 500, "ug", 0.0005)],
)
def test_units_are_converted_without_health_interpretation(nutrient, value, unit, expected):
    snapshot = normalize_rows([row(nutrient=nutrient, value=value, unit=unit)])
    cell = snapshot.tables[0].nutrients[nutrient]
    assert cell.value == expected
    assert cell.unit == ("kcal" if nutrient == "energy" else "g")
    assert cell.reason is None
    assert cell.conversion


def test_zero_is_preserved_and_absent_or_unknown_are_distinct():
    snapshot = normalize_rows(
        [
            row(nutrient="sugars", value=0),
            row(row_id="added-1", nutrient="added_sugars", value=None),
        ],
        completeness="complete",
    )
    cells = snapshot.tables[0].nutrients
    assert cells["sugars"].value == 0
    assert cells["sugars"].reason is None
    assert cells["added_sugars"].value is None
    assert cells["added_sugars"].reason == "unknown_value"
    assert cells["fibre"].value is None
    assert cells["fibre"].reason == "not_reported"
    assert cells["fibre"].source_row_ids == []
    assert snapshot.status == "partial"


def test_sugar_salt_and_available_total_carbohydrates_are_not_inferred():
    snapshot = normalize_rows(
        [
            row(nutrient="sugars", value=12),
            row(row_id="sodium-1", nutrient="sodium", value=0.12),
            row(row_id="carb-1", nutrient="carbohydrates", value=20),
        ],
        completeness="complete",
    )
    cells = snapshot.tables[0].nutrients
    assert cells["added_sugars"].value is None
    assert cells["salt"].value is None
    assert cells["carbohydrates_total"].value is None
    assert len(cells) == 11
    assert snapshot.status == "complete"


def test_unmeasured_serving_retains_its_values_without_100g_guess():
    submitted = row(basis={"kind": "serving", "amount": None, "unit": None}, value=7)
    snapshot = normalize_rows([submitted], completeness="complete")
    table = snapshot.tables[0]
    assert table.normalized_basis.model_dump() == {"kind": "serving", "amount": None, "unit": None}
    assert table.nutrients["protein"].value == 7
    assert table.nutrients["protein"].reason == "conversion_missing_basis"
    assert "conversion_missing_basis" in snapshot.warnings
    assert snapshot.status == "partial"


def test_separate_table_ids_never_merge_mass_and_volume_values():
    snapshot = normalize_rows(
        [
            row(value=4),
            row(
                row_id="volume-1",
                table_id="drink-table",
                value=8,
                basis={"kind": "quantity", "amount": 100, "unit": "mL"},
            ),
        ],
        completeness="complete",
    )
    assert [table.source_table_id for table in snapshot.tables] == ["back-table", "drink-table"]
    assert [table.nutrients["protein"].value for table in snapshot.tables] == [4, 8]
    assert snapshot.status == "complete"


@pytest.mark.parametrize(
    "changes",
    [
        {"preparation": "as_prepared"},
        {"basis": {"kind": "quantity", "amount": 100, "unit": "mL"}},
        {"basis": {"kind": "quantity", "amount": 50, "unit": "g"}},
    ],
)
def test_same_table_inconsistent_context_requires_correction_and_preserves_both(changes):
    snapshot = normalize_rows(
        [row(value=5), row(row_id="second-1", value=9, **changes)], completeness="complete"
    )
    assert snapshot.status == "needs_correction"
    assert "inconsistent_table_context" in snapshot.warnings
    assert len(snapshot.tables) == 2
    assert snapshot.original_rows[0].value == 5
    assert snapshot.original_rows[1].value == 9


def test_equivalent_duplicate_units_preserve_all_evidence_ids():
    snapshot = normalize_rows(
        [
            row(nutrient="sodium", value=0.12),
            row(row_id="sodium-2", nutrient="sodium", value=120, unit="mg"),
        ],
        completeness="complete",
    )
    cell = snapshot.tables[0].nutrients["sodium"]
    assert cell.value == 0.12
    assert cell.source_row_ids == ["protein-1", "sodium-2"]
    assert snapshot.status == "complete"


def test_conflicting_duplicate_values_have_no_first_or_last_winner():
    rows = [row(value=5), row(row_id="protein-2", value=7)]
    forward = normalize_rows(rows, completeness="complete")
    reverse = normalize_rows(list(reversed(rows)), completeness="complete")
    for snapshot in (forward, reverse):
        cell = snapshot.tables[0].nutrients["protein"]
        assert cell.value is None
        assert cell.reason == "conflicting_values"
        assert set(cell.source_row_ids) == {"protein-1", "protein-2"}
        assert snapshot.status == "needs_correction"


def test_tiny_basis_is_bounded_without_infinity_or_exception():
    snapshot = normalize_rows(
        [row(value=1, basis={"kind": "quantity", "amount": 5e-324, "unit": "g"})],
        completeness="complete",
    )
    cell = snapshot.tables[0].nutrients["protein"]
    assert cell.value is None
    assert cell.reason == "conversion_out_of_bounds"
    assert snapshot.status == "needs_correction"
    assert "Infinity" not in snapshot.model_dump_json()


def test_unrepresentable_positive_value_is_not_reported_as_zero():
    snapshot = normalize_rows([row(value=5e-324, unit="ug")], completeness="complete")
    cell = snapshot.tables[0].nutrients["protein"]
    assert cell.value is None
    assert cell.reason == "conversion_out_of_bounds"
    assert snapshot.status == "needs_correction"


@pytest.mark.parametrize("invalid", [True, False, "5", -1, 1000001, float("nan"), float("inf")])
def test_nutrient_value_rejects_non_numeric_nonfinite_and_out_of_bounds(invalid):
    with pytest.raises(ValidationError):
        row(value=invalid)


@pytest.mark.parametrize(
    ("nutrient", "unit"),
    [("energy", "g"), ("protein", "kcal"), ("sodium", "kJ")],
)
def test_nutrient_units_must_match_the_quantity(nutrient, unit):
    with pytest.raises(ValidationError):
        row(nutrient=nutrient, unit=unit)


@pytest.mark.parametrize(
    "basis",
    [
        {"kind": "quantity", "amount": None, "unit": None},
        {"kind": "quantity", "amount": 0, "unit": "g"},
        {"kind": "quantity", "amount": True, "unit": "g"},
        {"kind": "quantity", "amount": "100", "unit": "g"},
        {"kind": "quantity", "amount": float("nan"), "unit": "g"},
        {"kind": "quantity", "amount": 100001, "unit": "g"},
        {"kind": "serving", "amount": 40, "unit": None},
        {"kind": "serving", "amount": None, "unit": "g"},
        {"kind": "quantity", "amount": 100, "unit": "ml"},
    ],
)
def test_basis_requires_valid_paired_amount_and_unit(basis):
    with pytest.raises(ValidationError):
        row(basis=basis)


def test_normalization_request_accepts_json_numbers_and_rejects_duplicate_ids():
    payload = request_payload()
    parsed = NormalizeRequest.model_validate(payload)
    assert parsed.rows[0].value == 5
    assert parsed.confirmed is True
    payload["rows"].append(deepcopy(payload["rows"][0]))
    with pytest.raises(ValidationError):
        NormalizeRequest.model_validate(payload)


@pytest.mark.parametrize("confirmed", [False, 1, "true", None])
def test_request_requires_explicit_boolean_confirmation(confirmed):
    payload = request_payload()
    payload["confirmed"] = confirmed
    with pytest.raises(ValidationError):
        NormalizeRequest.model_validate(payload)


@pytest.mark.parametrize("revision", [True, "1", -1, 2147483648])
def test_request_revision_is_a_bounded_strict_integer(revision):
    payload = request_payload()
    payload["input_revision"] = revision
    with pytest.raises(ValidationError):
        NormalizeRequest.model_validate(payload)


@pytest.mark.parametrize("identifier", ["", "space id", "हिंदी", "a" * 65, "\ud800"])
def test_identifiers_are_bounded_ascii_tokens(identifier):
    with pytest.raises(ValidationError):
        row(row_id=identifier)


def test_request_forbids_unrelated_fields_and_has_a_row_count_bound():
    payload = request_payload()
    payload["allergy_profile"] = ["milk"]
    with pytest.raises(ValidationError):
        NormalizeRequest.model_validate(payload)
    del payload["allergy_profile"]
    payload["rows"][0]["image"] = "data:image/png;base64,not-accepted"
    with pytest.raises(ValidationError):
        NormalizeRequest.model_validate(payload)
    del payload["rows"][0]["image"]
    payload["rows"] = []
    with pytest.raises(ValidationError):
        NormalizeRequest.model_validate(payload)
    payload["rows"] = [
        row(row_id=f"protein-{index}").model_dump(mode="json") for index in range(65)
    ]
    with pytest.raises(ValidationError):
        NormalizeRequest.model_validate(payload)
