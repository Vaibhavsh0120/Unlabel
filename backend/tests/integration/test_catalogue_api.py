import json
import sqlite3
from datetime import UTC, datetime

import httpx
import pytest
from fastapi.testclient import TestClient

from app.catalogue.importer import build_catalogue
from app.core.config import Settings
from app.main import create_app


def test_indexed_catalogue_serves_exact_product_and_fresh_replacement_manifest_without_off(
    tmp_path,
):
    source = tmp_path / "source.jsonl"
    directory = tmp_path / "catalogue"
    directory.mkdir()

    def build(name):
        source.write_text(
            json.dumps(
                {"code": "0123456789012", "countries_tags": ["en:india"], "product_name": name}
            )
            + "\n"
        )
        return build_catalogue(
            source,
            directory,
            source_url="https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz",
            exported_at=datetime(2026, 10, 6, tzinfo=UTC),
        )

    first = build("First synthetic product")
    settings = Settings(_env_file=None, catalogue_directory=str(directory))
    with TestClient(create_app(settings, httpx.MockTransport(forbidden))) as client:
        result = client.get("/v1/catalogue/products/0123456789012")
        assert result.status_code == 200
        assert result.json()["manifest"]["snapshot_id"] == first.snapshot_id
        assert result.json()["manifest"]["coverage"] == "sample"
        assert "upstream_api_version" not in result.text
        assert result.json()["product"]["ingredients_text"] is None
        assert "allergen_safety_not_assessed" in result.json()["warnings"]
        assert client.get("/v1/catalogue/products/123456789012").status_code == 404
        assert client.get("/v1/meta").json()["capabilities"]["catalogue_lookup"] is True
        second = build("Second synthetic product")
        updated = client.get("/v1/catalogue/products/0123456789012").json()
        assert updated["product"]["name"] == "Second synthetic product"
        assert updated["manifest"]["snapshot_id"] == second.snapshot_id


def test_catalogue_paths_are_backend_relative_and_empty_is_inactive():
    assert Settings(_env_file=None, catalogue_directory=" ").catalogue_path() is None
    from pathlib import Path

    expected = Path(__file__).resolve().parents[2] / "storage/runtime/india"
    assert (
        Settings(_env_file=None, catalogue_directory="storage/runtime/india").catalogue_path()
        == expected.resolve()
    )


@pytest.mark.parametrize("field", ["warnings", "snapshot_id"])
def test_corrupt_unicode_in_snapshot_is_unavailable_instead_of_serialization_failure(
    tmp_path, field
):
    source = tmp_path / "source.jsonl"
    source.write_text(json.dumps({"code": "0123456789012", "countries_tags": ["en:india"]}) + "\n")
    build_catalogue(
        source,
        tmp_path,
        source_url="https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz",
        exported_at=datetime(2026, 10, 6, tzinfo=UTC),
    )
    settings = Settings(_env_file=None, catalogue_directory=str(tmp_path))
    with TestClient(create_app(settings, httpx.MockTransport(forbidden))) as client:
        with sqlite3.connect(tmp_path / "catalogue.sqlite3") as connection:
            table = "catalogue_products" if field == "warnings" else "catalogue_manifest"
            original = json.loads(connection.execute(f"SELECT data FROM {table}").fetchone()[0])
            original[field] = ["\ud800"] if field == "warnings" else "\ud800"
            connection.execute(f"UPDATE {table} SET data=?", (json.dumps(original),))
        response = client.get("/v1/catalogue/products/0123456789012")
        assert response.status_code == 503
        assert response.json()["warnings"] == ["catalogue_unavailable"]


def forbidden(request):
    raise AssertionError("Catalogue requests must not contact OFF")


def test_unconfigured_catalogue_is_explicit_without_disabling_other_backend_features():
    with TestClient(create_app(Settings(_env_file=None), httpx.MockTransport(forbidden))) as client:
        response = client.get("/v1/catalogue/products/0123456789012")
        assert response.status_code == 503
        assert response.json()["status"] == "unavailable"
        assert response.json()["manifest"] is None
        assert response.json()["product"] is None
        assert response.json()["warnings"] == ["catalogue_not_configured"]
        assert response.headers["cache-control"] == "no-store"
        meta = client.get("/v1/meta").json()
        assert meta["catalogue"]["status"] == "not_configured"
        assert meta["capabilities"]["catalogue_lookup"] is False
        assert meta["capabilities"]["nutrition_normalization"] is True
        assert client.get("/v1/health").json()["status"] == "ready"


def test_invalid_catalogue_barcode_uses_redacted_error_and_no_provider():
    with TestClient(create_app(Settings(_env_file=None), httpx.MockTransport(forbidden))) as client:
        response = client.get("/v1/catalogue/products/SECRET")
        assert response.status_code == 422
        assert "SECRET" not in response.text


def test_missing_configured_catalogue_returns_unavailable_without_creating_a_database(tmp_path):
    settings = Settings(_env_file=None, catalogue_directory=str(tmp_path))
    with TestClient(create_app(settings, httpx.MockTransport(forbidden))) as client:
        response = client.get("/v1/catalogue/products/0123456789012")
        assert response.status_code == 503
        assert response.json()["warnings"] == ["catalogue_unavailable"]
        assert client.get("/v1/meta").json()["catalogue"]["status"] == "unavailable"
    assert not list(tmp_path.iterdir())
