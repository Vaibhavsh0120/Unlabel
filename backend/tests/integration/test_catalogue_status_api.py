import gzip
import hashlib
import json
import sqlite3
from datetime import UTC, datetime

import httpx
import pytest
from fastapi.testclient import TestClient

from app.catalogue.bundle import build_bundle
from app.catalogue.importer import build_catalogue
from app.catalogue.models import CatalogLookup
from app.catalogue.status import CatalogueStatus
from app.core.config import Settings
from app.main import create_app


def forbidden(request):
    raise AssertionError("Catalogue and status must not call the upstream provider")


@pytest.fixture
def packaged(tmp_path):
    source = tmp_path / "source"
    source.mkdir()
    decoded = (
        json.dumps(
            {
                "code": "0123456789012",
                "countries_tags": ["en:india"],
                "product_name": "Synthetic product",
            }
        )
        + "\n"
    ).encode()
    compressed = gzip.compress(decoded, mtime=0)
    (source / "india-products.jsonl.gz").write_bytes(compressed)
    (source / "bundle.json").write_text(
        json.dumps(
            {
                "schema_version": "1",
                "source_file": "india-products.jsonl.gz",
                "source_format": "off_csv_projection",
                "coverage": "unverified",
                "source_url": "https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz",
                "exported_at": "2020-01-31T12:00:00Z",
                "compressed_bytes": len(compressed),
                "compressed_sha256": hashlib.sha256(compressed).hexdigest(),
                "decoded_bytes": len(decoded),
                "decoded_sha256": hashlib.sha256(decoded).hexdigest(),
                "expected_input_rows": 1,
                "indexed_products": 1,
                "unsupported_barcodes": 0,
                "market_tag": "en:india",
                "database_license": "ODbL-1.0",
                "contents_license": "DbCL-1.0",
                "attribution": "Product data from Open Food Facts",
                "refresh_interval_months": 9,
            }
        )
    )
    output = tmp_path / "package"
    receipt = build_bundle(source, output)
    return output, receipt


def test_verified_bundle_status_and_lookup_keep_age_artifact_and_no_upstream(packaged):
    directory, receipt = packaged
    settings = Settings(
        _env_file=None,
        catalogue_directory=str(directory),
        catalogue_require_receipt=True,
        cors_origins=["https://unlabel.example"],
    )
    with TestClient(create_app(settings, httpx.MockTransport(forbidden))) as client:
        response = client.get("/v1/catalogue", headers={"Origin": "https://unlabel.example"})
        assert response.status_code == 200
        result = CatalogueStatus.model_validate_json(response.content)
        assert result.manifest.indexed_products == 1
        assert result.freshness.status == "refresh_due"
        assert result.freshness.refresh_due_at == datetime(2020, 10, 31, 12, tzinfo=UTC)
        assert result.artifact.database_sha256 == receipt["database_sha256"]
        assert result.artifact.database_bytes == (directory / "catalogue.sqlite3").stat().st_size
        assert "nutrition_tables_not_included" in result.field_limits
        assert response.headers["cache-control"] == "no-store"
        assert response.headers["access-control-allow-origin"] == "https://unlabel.example"
        found = client.get("/v1/catalogue/products/0123456789012")
        assert found.status_code == 200
        assert "snapshot_refresh_due" in found.json()["warnings"]
        assert "snapshot_coverage_unverified" in found.json()["warnings"]
        absent = client.get("/v1/catalogue/products/123456789012")
        assert absent.status_code == 404
        assert absent.json()["manifest"]["snapshot_id"] == receipt["snapshot_id"]
        assert client.get("/v1/meta").json()["catalogue"]["artifact"] == response.json()["artifact"]


@pytest.mark.parametrize("damage", ["missing_receipt", "receipt_hash", "database", "manifest"])
def test_bad_packaged_artifact_disables_only_catalogue_and_redacts_paths(packaged, damage):
    directory, receipt = packaged
    if damage == "missing_receipt":
        (directory / "receipt.json").unlink()
    elif damage == "database":
        with (directory / "catalogue.sqlite3").open("ab") as stream:
            stream.write(b"damage")
    else:
        receipt["database_sha256" if damage == "receipt_hash" else "source_sha256"] = "f" * 64
        (directory / "receipt.json").write_text(json.dumps(receipt))
    settings = Settings(
        _env_file=None, catalogue_directory=str(directory), catalogue_require_receipt=True
    )
    with TestClient(create_app(settings, httpx.MockTransport(forbidden))) as client:
        response = client.get("/v1/catalogue")
        assert response.status_code == 503
        result = CatalogueStatus.model_validate_json(response.content)
        assert result.status == "unavailable" and result.manifest is None
        assert str(directory) not in response.text
        assert client.get("/v1/catalogue/products/0123456789012").status_code == 503
        assert client.get("/v1/health").status_code == 200
        meta = client.get("/v1/meta").json()
        assert meta["capabilities"]["catalogue_lookup"] is False
        assert meta["capabilities"]["nutrition_normalization"] is True


def test_status_unconfigured_remains_explicit_without_creating_files():
    with TestClient(create_app(Settings(_env_file=None), httpx.MockTransport(forbidden))) as client:
        response = client.get("/v1/catalogue")
        assert response.status_code == 503
        assert CatalogueStatus.model_validate_json(response.content).status == "not_configured"


def test_runtime_replacement_of_packaged_snapshot_is_refused(packaged, tmp_path):
    directory, _ = packaged
    settings = Settings(
        _env_file=None, catalogue_directory=str(directory), catalogue_require_receipt=True
    )
    with TestClient(create_app(settings, httpx.MockTransport(forbidden))) as client:
        assert client.get("/v1/catalogue").status_code == 200
        source = tmp_path / "replacement.jsonl"
        source.write_text(
            json.dumps(
                {
                    "code": "0123456789012",
                    "countries_tags": ["en:india"],
                    "product_name": "New sample",
                }
            )
            + "\n"
        )
        build_catalogue(
            source,
            directory,
            source_url="https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz",
            exported_at=datetime(2026, 10, 5, tzinfo=UTC),
        )
        assert client.get("/v1/catalogue").status_code == 503
        assert client.get("/v1/catalogue/products/0123456789012").status_code == 503


def test_full_warning_list_does_not_break_existing_lookup_contract(packaged):
    directory, _ = packaged
    with sqlite3.connect(directory / "catalogue.sqlite3") as connection:
        row = json.loads(connection.execute("SELECT data FROM catalogue_products").fetchone()[0])
        row["warnings"] = [f"synthetic_warning_{index}" for index in range(100)]
        connection.execute("UPDATE catalogue_products SET data=?", (json.dumps(row),))
    settings = Settings(_env_file=None, catalogue_directory=str(directory))
    with TestClient(create_app(settings, httpx.MockTransport(forbidden))) as client:
        response = client.get("/v1/catalogue/products/0123456789012")
        assert response.status_code == 200
        result = CatalogLookup.model_validate_json(response.content)
        assert result.warnings == row["warnings"]


@pytest.mark.parametrize("date", ["0001-01-01T00:00:00+01:00", "9999-12-31T23:59:59-01:00"])
def test_unrepresentable_local_source_date_is_unavailable_without_crashing_other_routes(
    packaged, date
):
    directory, _ = packaged
    with sqlite3.connect(directory / "catalogue.sqlite3") as connection:
        manifest = json.loads(
            connection.execute("SELECT data FROM catalogue_manifest").fetchone()[0]
        )
        manifest["exported_at"] = date
        connection.execute("UPDATE catalogue_manifest SET data=?", (json.dumps(manifest),))
    settings = Settings(_env_file=None, catalogue_directory=str(directory))
    with TestClient(create_app(settings, httpx.MockTransport(forbidden))) as client:
        assert client.get("/v1/catalogue").status_code == 503
        assert client.get("/v1/catalogue/products/0123456789012").status_code == 503
        assert client.get("/v1/meta").json()["catalogue"]["status"] == "unavailable"
        assert client.get("/v1/health").status_code == 200
