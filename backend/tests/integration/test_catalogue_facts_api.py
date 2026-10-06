import json
import sqlite3
from datetime import UTC, datetime

import httpx
import pytest
from fastapi.testclient import TestClient

from app.catalogue.facts import FactsLookup
from app.catalogue.importer import build_catalogue
from app.core.config import Settings
from app.main import create_app

CODE = "0123456789012"


def forbidden(request):
    raise AssertionError("Snapshot facts must not call OFF")


@pytest.fixture
def database(tmp_path):
    source = tmp_path / "source.jsonl"
    source.write_text(
        json.dumps(
            {
                "code": CODE,
                "countries_tags": ["en:india"],
                "product_name": "Synthetic oats",
                "allergens_tags": ["en:milk"],
                "traces_tags": [],
                "schema_version": 1004,
                "last_modified_t": 1791226426,
                "nutrition": {
                    "input_sets": [
                        {
                            "source": "packaging",
                            "preparation": "as_sold",
                            "per": "100g",
                            "per_quantity": 100,
                            "per_unit": "g",
                            "nutrients": {"sugars": {"value": 0, "unit": "g"}},
                        }
                    ]
                },
            }
        )
        + "\n"
    )
    directory = tmp_path / "store"
    directory.mkdir()
    build_catalogue(
        source,
        directory,
        source_url="https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz",
        exported_at=datetime(2020, 1, 1, tzinfo=UTC),
        coverage="unverified",
    )
    return directory


def test_facts_reads_snapshot_provenance_and_direct_zero_without_network(database):
    config = Settings(
        _env_file=None, catalogue_directory=str(database), cors_origins=["https://unlabel.example"]
    )
    with TestClient(create_app(config, httpx.MockTransport(forbidden))) as client:
        result = client.get(
            f"/v1/catalogue/products/{CODE}/facts", headers={"Origin": "https://unlabel.example"}
        )
        assert result.status_code == 200
        facts = FactsLookup.model_validate_json(result.content)
        assert facts.product.barcode == CODE
        assert facts.details.nutrition.snapshot.tables[0].nutrients["sugars"].value == 0
        assert facts.details.allergens.values == ["en:milk"]
        assert "snapshot_refresh_due" in facts.warnings
        assert "snapshot_coverage_unverified" in facts.warnings
        assert result.headers["cache-control"] == "no-store"
        assert result.headers["access-control-allow-origin"] == "https://unlabel.example"
        meta = client.get("/v1/meta").json()
        assert meta["capabilities"]["catalogue_facts"] is True
        assert "nutrition_direct_tables_only" in meta["catalogue"]["field_limits"]
        absent = client.get("/v1/catalogue/products/123456789012/facts")
        assert absent.status_code == 404
        assert absent.json()["manifest"] == result.json()["manifest"]
        assert absent.json()["details"] is None
        invalid = client.get("/v1/catalogue/products/secret-key/facts")
        assert invalid.status_code == 422 and "secret-key" not in invalid.text
        assert client.get(f"/v1/catalogue/products/{CODE}").status_code == 200


@pytest.mark.parametrize("damage", ["legacy", "missing_row", "invalid_json", "source_date"])
def test_facts_degrade_without_disabling_live_or_other_service(database, damage):
    with sqlite3.connect(database / "catalogue.sqlite3") as connection:
        if damage == "legacy":
            connection.execute("DROP TABLE catalogue_facts")
        elif damage == "missing_row":
            connection.execute("DELETE FROM catalogue_facts")
        elif damage == "invalid_json":
            connection.execute("UPDATE catalogue_facts SET data='broken'")
        else:
            manifest = json.loads(
                connection.execute("SELECT data FROM catalogue_manifest").fetchone()[0]
            )
            manifest["exported_at"] = "9999-12-31T23:59:59-01:00"
            connection.execute("UPDATE catalogue_manifest SET data=?", (json.dumps(manifest),))
    config = Settings(_env_file=None, catalogue_directory=str(database))
    with TestClient(create_app(config, httpx.MockTransport(forbidden))) as client:
        response = client.get(f"/v1/catalogue/products/{CODE}/facts")
        assert response.status_code == 503
        assert "broken" not in response.text and str(database) not in response.text
        FactsLookup.model_validate_json(response.content)
        assert client.get("/v1/health").status_code == 200
        assert client.get("/v1/meta").json()["capabilities"]["nutrition_normalization"] is True
        if damage == "legacy":
            assert client.get(f"/v1/catalogue/products/{CODE}").status_code == 200
            assert client.get("/v1/meta").json()["capabilities"]["catalogue_facts"] is False


def test_unconfigured_facts_are_explicit_and_do_not_call_upstream():
    with TestClient(create_app(Settings(_env_file=None), httpx.MockTransport(forbidden))) as client:
        response = client.get(f"/v1/catalogue/products/{CODE}/facts")
        assert response.status_code == 503
        assert response.json()["warnings"] == ["catalogue_not_configured"]
        assert client.get("/v1/meta").json()["capabilities"]["catalogue_facts"] is False
