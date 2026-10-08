"""Offline research supplements must never impersonate served OFF observations."""

import copy
import gzip
import hashlib
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parents[3] / "scripts/build_popular_dataset.py"


def implementation():
    if not SCRIPT.is_file():
        pytest.fail("The offline popular-products supplement builder is missing")
    spec = importlib.util.spec_from_file_location("popular_dataset", SCRIPT)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def candidate(**identity):
    return {
        "source": {
            "provider": "manufacturer",
            "url": "https://example.org/india/synthetic-cola",
            "retrieved_at": "2026-10-08T04:00:00Z",
            "license": "factual_excerpt_reuse_unverified",
            "reuse_status": "review_required",
        },
        "identity": {
            "barcode": None,
            "name": "Synthetic cola",
            "brand": "Synthetic",
            "variant": "Original",
            "quantity": "250 ml",
            "market": "india",
            "match": "identity_unconfirmed",
            **identity,
        },
        "sections": {"ingredients": {"text": "Water, sugar", "completeness": "complete"}},
        "nutrition": {
            "direct_tables": [
                {
                    "source": "manufacturer",
                    "basis": {"amount": 100, "unit": "mL"},
                    "preparation": "as_sold",
                    "rows": [{"nutrient": "sugars", "value": 10, "unit": "g"}],
                }
            ],
        },
    }


def write_candidates(path, *rows):
    path.write_text(json.dumps({"observations": list(rows)}), encoding="utf-8")


def test_build_deterministic_offline_bundle_with_separate_dates_and_source_sections(tmp_path):
    module = implementation()
    source = tmp_path / "web.json"
    row = candidate()
    row["source"]["source_updated_at"] = "2025-12-01T00:00:00Z"
    write_candidates(source, row)
    first = module.build_dataset([source], [], tmp_path / "first")
    second = module.build_dataset([source], [], tmp_path / "second")
    assert first == second
    assert first["runtime_promotion"] == "none"
    assert first["observation_count"] == 1
    assert (tmp_path / "first/observations.jsonl.gz").read_bytes() == (
        tmp_path / "second/observations.jsonl.gz"
    ).read_bytes()
    observation = json.loads(
        gzip.decompress((tmp_path / "first/observations.jsonl.gz").read_bytes())
    )
    assert observation["source"]["retrieved_at"] != observation["source"]["source_updated_at"]
    assert observation["identity"]["barcode"] is None
    assert observation["eligibility"] == "identity_unconfirmed"
    assert observation["sections"]["ingredients"]["text"] == "Water, sugar"
    assert observation["sections"]["ingredients"]["provenance"]["url"] == row["source"]["url"]
    assert observation["nutrition"]["direct_tables"][0]["rows"][0]["value"] == 10
    assert module.verify_dataset(tmp_path / "first") == first


def test_conflicting_exact_pack_identities_remain_distinct_and_unlinked(tmp_path):
    module = implementation()
    source = tmp_path / "web.json"
    first = candidate(barcode="8900000000001", match="exact_sku")
    first["identity"]["barcode_evidence_url"] = first["source"]["url"]
    second = copy.deepcopy(first)
    second["identity"]["quantity"] = "500 ml"
    second["sections"]["ingredients"]["text"] = "Water, sweetener"
    write_candidates(source, first, second)
    manifest = module.build_dataset([source], [], tmp_path / "out")
    conflict = manifest["barcode_groups"]["8900000000001"]
    assert conflict["eligibility"] == "conflicting"
    assert set(conflict["conflict_fields"]) == {"identity.quantity", "ingredients"}
    assert len(conflict["observation_ids"]) == 2
    assert module.verify_dataset(tmp_path / "out") == manifest


def test_off_legacy_aggregates_never_become_direct_tables_and_private_fields_are_dropped(tmp_path):
    module = implementation()
    source = tmp_path / "off.jsonl"
    source.write_text(
        json.dumps(
            {
                "source": {
                    "provider": "open_food_facts",
                    "url": "https://world.openfoodfacts.org/api/v3.6/product/8900000000001.json",
                    "retrieved_at": "2026-10-08T04:00:00Z",
                    "license": "ODbL-1.0 / DbCL-1.0",
                },
                "product": {
                    "code": "8900000000001",
                    "countries_tags": ["en:india"],
                    "product_name": "Synthetic cola",
                    "brands": "Synthetic",
                    "quantity": "250 ml",
                    "ingredients_text": "Water, sugar",
                    "nutriments": {"sugars_100g": 99},
                    "creator": "private-contributor",
                    "images": {"1": {"uploader": "private-person"}},
                },
            }
        )
        + "\n",
        encoding="utf-8",
    )
    module.build_dataset([], [source], tmp_path / "out")
    data = gzip.decompress((tmp_path / "out/observations.jsonl.gz").read_bytes())
    observation = json.loads(data)
    assert observation["nutrition"]["availability"] == "legacy_aggregate_only"
    assert observation["nutrition"]["direct_tables"] == []
    assert observation["nutrition"]["legacy_aggregates"]["sugars_100g"] == 99
    assert b"private-contributor" not in data and b"private-person" not in data
    assert observation["source"]["provider"] == "open_food_facts"


def test_off_exact_response_barcode_disagreement_is_rejected(tmp_path):
    module = implementation()
    source = tmp_path / "off.jsonl"
    source.write_text(
        json.dumps(
            {
                "source": {
                    "provider": "open_food_facts",
                    "url": "https://world.openfoodfacts.org/api/v3.6/product/8900000000001.json",
                    "retrieved_at": "2026-10-08T04:00:00Z",
                    "license": "ODbL-1.0 / DbCL-1.0",
                },
                "product": {"code": "8900000000002", "countries_tags": ["en:india"]},
            }
        )
        + "\n",
        encoding="utf-8",
    )
    with pytest.raises(ValueError, match="barcode"):
        module.build_dataset([], [source], tmp_path / "out")
    assert not (tmp_path / "out/manifest.json").exists()


@pytest.mark.parametrize(
    "mutation",
    [
        lambda row: row["source"].update(retrieved_at="2026-10-08"),
        lambda row: row["source"].update(retrieved_at="2999-01-01T00:00:00Z"),
        lambda row: row["source"].update(url="https://user:password@example.org/source"),
        lambda row: row["identity"].update(barcode="20052000", match="exact_sku"),
        lambda row: row["sections"]["ingredients"].update(text="x" * 16001),
        lambda row: row["nutrition"]["direct_tables"][0]["rows"][0].update(value=float("inf")),
        lambda row: row["nutrition"]["direct_tables"][0].update(source="packaging"),
    ],
)
def test_invalid_dates_urls_identity_and_size_fail_closed(tmp_path, mutation):
    module = implementation()
    source = tmp_path / "web.json"
    row = candidate()
    mutation(row)
    write_candidates(source, row)
    with pytest.raises(ValueError):
        module.build_dataset([source], [], tmp_path / "out")
    assert not (tmp_path / "out/manifest.json").exists()


def test_qualified_values_remain_qualified_and_missing_is_not_zero(tmp_path):
    module = implementation()
    source = tmp_path / "web.json"
    row = candidate()
    row["nutrition"]["direct_tables"][0]["rows"] += [
        {
            "nutrient": "trans_fat",
            "value": 0.1,
            "qualifier": "less_than",
            "unit": "g",
            "raw_label": "Trans fat <0.1 g",
        },
        {"nutrient": "protein", "value": None, "qualifier": "unknown", "unit": "g"},
    ]
    write_candidates(source, row)
    module.build_dataset([source], [], tmp_path / "out")
    observation = json.loads(gzip.decompress((tmp_path / "out/observations.jsonl.gz").read_bytes()))
    rows = observation["nutrition"]["direct_tables"][0]["rows"]
    assert rows[1]["qualifier"] == "less_than" and rows[1]["value"] == 0.1
    assert rows[2]["value"] is None


def test_duplicate_json_keys_and_conflicting_observation_ids_are_rejected(tmp_path):
    module = implementation()
    source = tmp_path / "web.json"
    source.write_text('{"observations":[],"observations":[]}', encoding="utf-8")
    with pytest.raises(ValueError, match="duplicate"):
        module.build_dataset([source], [], tmp_path / "out")
    row = candidate()
    row["observation_id"] = "0" * 64
    write_candidates(source, row)
    with pytest.raises(ValueError, match="observation"):
        module.build_dataset([source], [], tmp_path / "out")


@pytest.mark.parametrize("target", ["observations.jsonl.gz", "manifest.json"])
def test_bundle_tampering_is_detected(tmp_path, target):
    module = implementation()
    source = tmp_path / "web.json"
    write_candidates(source, candidate())
    module.build_dataset([source], [], tmp_path / "out")
    path = tmp_path / "out" / target
    if target.endswith(".gz"):
        path.write_bytes(path.read_bytes() + b"tamper")
    else:
        manifest = json.loads(path.read_text(encoding="utf-8"))
        manifest["observation_count"] = 2
        path.write_text(json.dumps(manifest), encoding="utf-8")
    with pytest.raises(ValueError):
        module.verify_dataset(tmp_path / "out")


def test_self_consistent_hash_tampering_cannot_change_immutable_observation(tmp_path):
    module = implementation()
    source = tmp_path / "web.json"
    write_candidates(source, candidate())
    module.build_dataset([source], [], tmp_path / "out")
    compressed = tmp_path / "out/observations.jsonl.gz"
    manifest_path = tmp_path / "out/manifest.json"
    observation = json.loads(gzip.decompress(compressed.read_bytes()))
    observation["sections"]["ingredients"]["text"] = "Tampered label"
    decoded = (json.dumps(observation, sort_keys=True, separators=(",", ":")) + "\n").encode()
    packed = gzip.compress(decoded, mtime=0)
    compressed.write_bytes(packed)
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest.update(
        compressed_sha256=hashlib.sha256(packed).hexdigest(),
        compressed_bytes=len(packed),
        decoded_sha256=hashlib.sha256(decoded).hexdigest(),
        decoded_bytes=len(decoded),
    )
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    with pytest.raises(ValueError, match="observation"):
        module.verify_dataset(tmp_path / "out")


def test_cli_help_and_verify_have_no_network_or_import_side_effect(tmp_path):
    implementation()
    result = subprocess.run([sys.executable, str(SCRIPT), "--help"], capture_output=True, text=True)
    assert result.returncode == 0 and "--verify" in result.stdout
    assert not list(tmp_path.iterdir())


def test_candidate_ids_cannot_refer_to_contradictory_content(tmp_path):
    module = implementation()
    source = tmp_path / "web.json"
    first = candidate()
    first["candidate_id"] = "synthetic-product"
    second = copy.deepcopy(first)
    second["identity"]["quantity"] = "500 ml"
    write_candidates(source, first, second)
    with pytest.raises(ValueError, match="candidate"):
        module.build_dataset([source], [], tmp_path / "out")


def test_decoded_work_budget_is_checked_before_publication(tmp_path, monkeypatch):
    module = implementation()
    source = tmp_path / "web.json"
    write_candidates(source, candidate())
    monkeypatch.setattr(module, "MAX_DATASET_BYTES", 100)
    with pytest.raises(ValueError, match="byte"):
        module.build_dataset([source], [], tmp_path / "out")
    assert not (tmp_path / "out/manifest.json").exists()


def test_separately_hosted_facts_cannot_inherit_manufacturer_source_and_license(tmp_path):
    module = implementation()
    source = tmp_path / "web.json"
    row = candidate()
    row["sections"]["ingredients"]["source_url"] = "https://other-retailer.example/product"
    write_candidates(source, row)
    with pytest.raises(ValueError, match="own source"):
        module.build_dataset([source], [], tmp_path / "out")


def test_unknown_off_country_type_cannot_establish_india_identity(tmp_path):
    module = implementation()
    source = tmp_path / "off.json"
    source.write_text(
        json.dumps(
            [
                {
                    "source": {
                        "provider": "open_food_facts",
                        "url": "https://world.openfoodfacts.org/api/v3.6/product/8900000000001.json",
                        "retrieved_at": "2026-10-08T04:00:00Z",
                        "license": "ODbL-1.0 / DbCL-1.0",
                    },
                    "product": {
                        "code": "8900000000001",
                        "countries_tags": "en:india",
                        "product_name": "Synthetic cola",
                        "brands": "Synthetic",
                        "quantity": "250 ml",
                    },
                }
            ]
        ),
        encoding="utf-8",
    )
    with pytest.raises(ValueError, match="countries"):
        module.build_dataset([], [source], tmp_path / "out")


def test_bulk_acquisition_directory_and_unrecognized_outputs_are_never_overwritten(tmp_path):
    module = implementation()
    source = tmp_path / "web.json"
    write_candidates(source, candidate())
    output = tmp_path / "out"
    output.mkdir()
    original = b"original bulk acquisition bytes"
    (output / "india-products.jsonl.gz").write_bytes(original)
    with pytest.raises(ValueError, match="bulk"):
        module.build_dataset([source], [], output)
    assert (output / "india-products.jsonl.gz").read_bytes() == original


@pytest.mark.parametrize("number", ["1e999", "1e-999", "1.00000000000000001"])
def test_invalid_numeric_tokens_are_rejected_before_normalization(tmp_path, number):
    module = implementation()
    source = tmp_path / "web.json"
    source.write_text(
        json.dumps({"observations": [candidate()]}).replace('"value": 10', '"value": ' + number),
        encoding="utf-8",
    )
    with pytest.raises(ValueError, match="number"):
        module.build_dataset([source], [], tmp_path / "out")


def test_long_off_ingredient_declaration_is_preserved_and_bounded(tmp_path):
    module = implementation()
    source = tmp_path / "off.json"
    declaration = "Synthetic ingredient, " * 200
    source.write_text(
        json.dumps(
            [
                {
                    "source": {
                        "provider": "open_food_facts",
                        "url": "https://world.openfoodfacts.org/api/v3.6/product/8900000000001.json",
                        "retrieved_at": "2026-10-08T04:00:00Z",
                        "license": "ODbL-1.0 / DbCL-1.0",
                    },
                    "product": {
                        "code": "8900000000001",
                        "countries_tags": ["en:india"],
                        "ingredients_text": declaration,
                    },
                }
            ]
        ),
        encoding="utf-8",
    )
    module.build_dataset([], [source], tmp_path / "out")
    data = gzip.decompress((tmp_path / "out/observations.jsonl.gz").read_bytes())
    assert json.loads(data)["raw_projection"]["ingredients_text"] == declaration


def test_off_string_values_are_unknown_and_multiline_declaration_keeps_source(tmp_path):
    module = implementation()
    source = tmp_path / "off.json"
    record = {
        "source": {
            "provider": "open_food_facts",
            "url": "https://world.openfoodfacts.org/api/v3.6/product/8900000000001.json",
            "retrieved_at": "2026-10-08T04:00:00Z",
            "license": "ODbL-1.0 / DbCL-1.0",
        },
        "product": {
            "code": "8900000000001",
            "countries_tags": ["en:india"],
            "product_name": "Synthetic",
            "brands": "Synthetic",
            "quantity": "7",
            "ingredients_text": "Water,\nSugar",
            "nutrition": {
                "input_sets": [
                    {
                        "source": "packaging",
                        "preparation": "as_sold",
                        "per": "100g",
                        "per_quantity": 100,
                        "per_unit": "g",
                        "nutrients": {"salt": {"value": "1.275", "unit": "g"}},
                    }
                ]
            },
        },
    }
    source.write_text(json.dumps([record]))
    module.build_dataset([], [source], tmp_path / "out")
    observation = json.loads(gzip.decompress((tmp_path / "out/observations.jsonl.gz").read_bytes()))
    assert observation["eligibility"] == "identity_unconfirmed"
    assert observation["sections"]["ingredients"]["text"] == "Water,\nSugar"
    assert observation["nutrition"]["direct_tables"][0]["rows"][0]["value"] is None
    assert observation["nutrition"]["direct_tables"][0]["rows"][0]["qualifier"] == "unknown"
    assert (
        observation["raw_projection"]["nutrition"]["input_sets"][0]["nutrients"]["salt"]["value"]
        == "1.275"
    )
