import hashlib
import json
import sqlite3
from datetime import UTC, datetime

import pytest
from pydantic import ValidationError

from app.catalogue.facts import AvailableTags, FactsLookup, FrontImage, project_facts
from app.catalogue.importer import build_catalogue
from app.catalogue.models import SourceFormat
from app.catalogue.store import CatalogueStore

CODE = "0123456789012"
SOURCE_URL = "https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz"
EXPORTED_AT = datetime(2026, 10, 6, 6, 53, 46, tzinfo=UTC)


def table(value=0, **extra):
    return {
        "source": "packaging",
        "preparation": "as_sold",
        "per": "100g",
        "per_quantity": 100,
        "per_unit": "g",
        "nutrients": {"sugars": {"value": value, "unit": "g"}},
        **extra,
    }


def raw_product(**extra):
    return {
        "code": CODE,
        "countries_tags": ["en:india"],
        "product_name": "Synthetic oats",
        "ingredients_text": "Oats, milk",
        "allergens_tags": ["en:milk"],
        "traces_tags": [],
        "labels_tags": ["en:high-fibre"],
        "categories_tags": ["en:breakfast-cereals"],
        "schema_version": 1004,
        "last_modified_t": 1791226426,
        "nutrition": {"input_sets": [table()]},
        "images": {
            "selected": {
                "front": {
                    "en": {
                        "rev": "4",
                        "sizes": {"400": {"w": 400, "h": 200}},
                    }
                }
            }
        },
        **extra,
    }


def build(tmp_path, rows=None, source_format: SourceFormat = "off_jsonl"):
    source = tmp_path / "source.jsonl"
    decoded = b"".join(
        (json.dumps(row, ensure_ascii=True) + "\n").encode()
        for row in ([raw_product()] if rows is None else rows)
    )
    source.write_bytes(decoded)
    directory = tmp_path / "database"
    directory.mkdir(exist_ok=True)
    manifest = build_catalogue(
        source,
        directory,
        source_url=SOURCE_URL,
        exported_at=EXPORTED_AT,
        coverage="unverified",
        source_format=source_format,
    )
    return CatalogueStore(directory), manifest, directory, decoded


def test_rich_lookup_roundtrips_source_provenance_zero_and_explicit_unknown(tmp_path):
    store, manifest, _, decoded = build(tmp_path)
    assert store.supports_facts is True
    result = store.lookup_facts(CODE)
    assert result.status == "found"
    assert result.product is not None
    assert result.product.barcode == CODE
    assert result.manifest == manifest
    assert result.manifest is not None
    assert result.manifest.source_sha256 == hashlib.sha256(decoded).hexdigest()
    assert result.manifest.exported_at == EXPORTED_AT
    assert result.details is not None
    assert result.details.provider_schema_version == 1004
    assert result.details.last_modified_at == datetime.fromtimestamp(1791226426, UTC)
    assert result.details.allergens.availability == "available"
    assert result.details.traces.values == []
    assert result.details.nutrition.availability == "direct_tables"
    nutrition = result.details.nutrition.snapshot.tables[0]
    assert nutrition.nutrients["sugars"].value == 0
    assert nutrition.nutrients["added_sugars"].value is None
    assert nutrition.nutrients["added_sugars"].reason == "not_reported"
    assert result.details.nutrition.input_tables[0].provider_source == "packaging"
    assert "allergen_safety_not_assessed" in result.warnings
    payload = result.model_dump_json()
    assert "upstream_api_version" not in payload and '"retrieved_at"' not in payload
    assert FactsLookup.model_validate_json(payload) == result
    assert set(store.lookup(CODE).model_dump()) == {
        "schema_version",
        "requested_barcode",
        "status",
        "manifest",
        "product",
        "warnings",
    }


def test_not_found_has_snapshot_and_no_product_details(tmp_path):
    store, manifest, _, _ = build(tmp_path)
    result = store.lookup_facts("123456789012")
    assert result.status == "not_found"
    assert result.manifest == manifest
    assert result.product is None and result.details is None


def test_legacy_identity_database_remains_readable_without_invented_facts(tmp_path):
    store, _, directory, _ = build(tmp_path, source_format="off_csv_projection")
    assert store.supports_facts is False
    assert store.lookup(CODE).status == "found"
    assert store.lookup_facts(CODE).status == "unavailable"
    assert store.lookup_facts(CODE).warnings == ["identity_snapshot_has_no_details"]
    with sqlite3.connect(directory / "catalogue.sqlite3") as connection:
        assert connection.execute("PRAGMA user_version").fetchone()[0] == 1
        assert (
            connection.execute(
                "SELECT name FROM sqlite_master WHERE name='catalogue_facts'"
            ).fetchone()
            is None
        )


def test_sparse_missing_tags_and_community_empty_are_distinct(tmp_path):
    missing = {"code": CODE, "countries_tags": ["en:india"]}
    empty = {
        "code": "123456789012",
        "countries_tags": ["en:india"],
        "allergens_tags": [],
        "traces_tags": [],
    }
    store, _, _, _ = build(tmp_path, [missing, empty])
    missing_result = store.lookup_facts(CODE)
    assert missing_result.details is not None
    assert missing_result.details.allergens.availability == "missing"
    assert missing_result.product is not None
    assert missing_result.product.allergen_tags == []
    assert missing_result.details.nutrition.availability == "missing"
    assert missing_result.details.nutrition.snapshot.tables == []
    assert missing_result.details.image is None
    empty_result = store.lookup_facts("123456789012")
    assert empty_result.details is not None
    assert empty_result.details.allergens.availability == "available"
    assert "allergen_safety_not_assessed" in store.lookup_facts("123456789012").warnings


@pytest.mark.parametrize("value", [True, "en:milk", ["x"] * 101, ["x" * 257], ["\ud800"]])
def test_invalid_tags_remain_unknown(value):
    details, warnings = project_facts(raw_product(allergens_tags=value), CODE)
    assert details.allergens.availability == "invalid"
    assert details.allergens.values == []
    assert "allergens_tags_invalid" in warnings


@pytest.mark.parametrize("modified", [True, "123", -1, 10**100])
def test_invalid_modified_timestamp_is_bounded_unknown(modified):
    details, warnings = project_facts(raw_product(last_modified_t=modified), CODE)
    assert details.last_modified_at is None
    assert "provider_modified_at_invalid" in warnings


@pytest.mark.parametrize("schema", [True, "1004", -1, 2_147_483_648])
def test_unknown_schema_type_is_not_coerced(schema):
    details, warnings = project_facts(raw_product(schema_version=schema), CODE)
    assert details.provider_schema_version is None
    assert "provider_schema_version_invalid" in warnings


@pytest.mark.parametrize(
    "barcode,folder",
    [
        ("01234567", "000/000/123/4567"),
        ("012345678901", "001/234/567/8901"),
        ("0123456789012", "012/345/678/9012"),
        ("01234567890123", "123/456/789/0123"),
        ("12345678901234", "123/456/789/01234"),
    ],
)
def test_image_url_uses_off_disk_path_without_changing_lookup_barcode(barcode, folder):
    details, _ = project_facts(raw_product(), barcode)
    image = details.image
    assert image is not None
    assert (
        image.url == f"https://images.openfoodfacts.org/images/products/{folder}/front_en.4.400.jpg"
    )
    assert image.revision == 4 and type(image.revision) is int
    assert (image.width, image.height) == (400, 200)
    assert image.license == "CC-BY-SA-3.0"


@pytest.mark.parametrize("barcode", ["00000000", "0000000000001"])
def test_image_path_with_too_few_significant_digits_stays_unknown(barcode):
    details, warnings = project_facts(raw_product(), barcode)
    assert details.image is None
    assert "selected_front_image_invalid" in warnings


def test_image_legacy_language_and_lc_fallback_ignore_arbitrary_urls():
    image = {"rev": 2, "sizes": {"400": {"w": 200, "h": 400}}}
    details, _ = project_facts(raw_product(images={"front_hi": image}), CODE)
    assert details.image is not None
    assert details.image.language == "hi"
    details, _ = project_facts(raw_product(images={"front_ta": image}, lc="ta"), CODE)
    assert details.image is not None
    assert details.image.language == "ta"
    details, _ = project_facts(
        raw_product(
            images={"front_ta": image},
            lc="../../private",
            image_front_url="https://evil.test/private",
            selected_images={"front": {"en": "x"}},
        ),
        CODE,
    )
    assert details.image is None


@pytest.mark.parametrize(
    "revision", [True, 1.5, 0, -1, "01", "../../evil", "2\n", "2/3", "9" * 100]
)
def test_invalid_selected_revision_never_creates_an_image_url(revision):
    images = {"front_en": {"rev": revision, "sizes": {"400": {"w": 400, "h": 200}}}}
    details, warnings = project_facts(raw_product(images=images), CODE)
    assert details.image is None
    assert "selected_front_image_invalid" in warnings


@pytest.mark.parametrize(
    "sizes", [{}, {"100": {"w": 100}}, {"400": True}, {"400": {"w": 401}}, {"400": {"h": "200"}}]
)
def test_selected_image_requires_available_valid_400_size(sizes):
    details, _ = project_facts(raw_product(images={"front_en": {"rev": 4, "sizes": sizes}}), CODE)
    assert details.image is None


def test_legacy_aggregated_nutrition_is_explicitly_unsupported_not_guessed():
    data = raw_product(nutrition=None, nutrition_legacy_present=True)
    details, _ = project_facts(data, CODE)
    assert details.nutrition.availability == "legacy_unsupported"
    assert details.nutrition.snapshot.tables == []
    assert "legacy_aggregated_nutrition_not_used" in details.nutrition.warnings
    data = raw_product(nutrition=None, nutriments={"sugars_100g": 5})
    assert project_facts(data, CODE)[0].nutrition.availability == "legacy_unsupported"


def test_qualified_computed_and_estimate_table_values_are_excluded():
    tables = [
        table(
            nutrients={
                "sugars": {"value_computed": 4, "unit": "g"},
                "fat": {"value": 2, "modifier": "<", "unit": "g"},
            }
        ),
        table(9, source="estimate"),
    ]
    details, _ = project_facts(raw_product(nutrition={"input_sets": tables}), CODE)
    assert details.nutrition.availability == "direct_tables"
    assert details.nutrition.snapshot.original_rows == []
    assert details.nutrition.snapshot.tables[0].nutrients["sugars"].value is None
    assert {
        "qualified_value_excluded",
        "computed_or_missing_value_excluded",
        "unsupported_table_source",
    }.issubset(details.nutrition.warnings)


def test_conflicting_direct_tables_preserve_evidence_and_status():
    details, _ = project_facts(raw_product(nutrition={"input_sets": [table(1), table(2)]}), CODE)
    assert details.nutrition.snapshot.status == "needs_correction"
    assert [table.nutrients["sugars"].value for table in details.nutrition.snapshot.tables] == [
        1,
        2,
    ]
    assert "provider_tables_disagree" in details.nutrition.warnings


@pytest.mark.parametrize("nutrition", [True, [], "unrecognized"])
def test_malformed_nutrition_container_is_explicitly_invalid(nutrition):
    details, _ = project_facts(raw_product(nutrition=nutrition), CODE)
    assert details.nutrition.availability == "invalid"
    assert details.nutrition.snapshot.tables == []


@pytest.mark.parametrize(
    "input_sets",
    [
        True,
        [table()] * 17,
        [table(source="unknown")],
        [table(source_nutrient_count=201)],
        [table(invalid_source_nutrient_count=True)],
    ],
)
def test_invalid_or_projected_overbudget_direct_tables_are_unknown(input_sets):
    details, _ = project_facts(raw_product(nutrition={"input_sets": input_sets}), CODE)
    assert details.nutrition.availability == "invalid"
    assert details.nutrition.snapshot.tables == []


@pytest.mark.parametrize("damage", ["missing", "extra", "different-key"])
def test_facts_identity_count_and_key_mismatch_is_rejected_at_startup(tmp_path, damage):
    _, _, directory, _ = build(tmp_path)
    with sqlite3.connect(directory / "catalogue.sqlite3") as connection:
        if damage == "missing":
            connection.execute("DELETE FROM catalogue_facts")
        elif damage == "extra":
            connection.execute("INSERT INTO catalogue_facts VALUES ('123456789012','{}')")
        else:
            connection.execute("UPDATE catalogue_facts SET barcode='123456789012'")
    with pytest.raises(ValueError, match="facts"):
        CatalogueStore(directory)


@pytest.mark.parametrize(
    "damage",
    [
        "image-identity",
        "allergen-identity",
        "record-bounds",
        "unknown-key",
        "warning-type",
        "numeric-token",
        "table-provenance",
        "missing-nutrient-cell",
    ],
)
def test_corrupt_facts_cannot_be_returned_as_a_valid_exact_record(tmp_path, damage):
    store, _, directory, _ = build(tmp_path)
    with sqlite3.connect(directory / "catalogue.sqlite3") as connection:
        record = json.loads(connection.execute("SELECT data FROM catalogue_facts").fetchone()[0])
        if damage == "image-identity":
            record["details"]["image"]["url"] = record["details"]["image"]["url"].replace(
                "012/", "987/"
            )
        elif damage == "allergen-identity":
            record["details"]["allergens"]["values"] = ["en:soybeans"]
        elif damage == "record-bounds":
            record["details"]["labels"]["values"] = ["x"] * 101
        elif damage == "unknown-key":
            record["details"]["secret"] = "unmapped payload"
        elif damage == "warning-type":
            record["warnings"] = "must be an array"
        elif damage == "table-provenance":
            record["details"]["nutrition"]["input_tables"][0]["table_id"] = "different-table"
        elif damage == "missing-nutrient-cell":
            del record["details"]["nutrition"]["snapshot"]["tables"][0]["nutrients"]["sugars"]
        raw = json.dumps(record)
        if damage == "numeric-token":
            raw = raw.replace('"value": 0.0', '"value": 1e-400')
            assert "1e-400" in raw
        connection.execute("UPDATE catalogue_facts SET data=?", (raw,))
    with pytest.raises(ValueError):
        store.lookup_facts(CODE)


def test_output_contracts_reject_untrusted_urls_and_false_availability():
    with pytest.raises(ValidationError):
        FrontImage(url="https://evil.test/image.jpg", language="en", revision=1)
    with pytest.raises(ValidationError):
        AvailableTags(availability="missing", values=["en:milk"])
    with pytest.raises(ValidationError):
        FactsLookup(requested_barcode=CODE, status="found")


def test_empty_nutrition_cannot_claim_direct_tables_are_available(tmp_path):
    store, _, directory, _ = build(tmp_path, [raw_product(nutrition=None)])
    with sqlite3.connect(directory / "catalogue.sqlite3") as connection:
        record = json.loads(connection.execute("SELECT data FROM catalogue_facts").fetchone()[0])
        record["details"]["nutrition"]["availability"] = "direct_tables"
        connection.execute("UPDATE catalogue_facts SET data=?", (json.dumps(record),))
    with pytest.raises(ValueError, match="requires at least one"):
        store.lookup_facts(CODE)


def test_facts_sql_injection_and_unsupported_barcode_is_rejected_before_query(tmp_path):
    store, _, directory, _ = build(tmp_path)
    before = (directory / "catalogue.sqlite3").read_bytes()
    for code in ("0123456789012' OR 1=1 --", "１２３４５６７８", "123456789"):
        with pytest.raises(ValueError):
            store.lookup_facts(code)
    assert (directory / "catalogue.sqlite3").read_bytes() == before
