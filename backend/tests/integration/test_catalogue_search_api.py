import json
import sqlite3
from datetime import UTC, datetime

import httpx
import pytest
from fastapi.testclient import TestClient

from app.catalogue.importer import build_catalogue
from app.core.config import Settings
from app.main import create_app


def forbidden(request):
    raise AssertionError("Snapshot discovery must never contact OFF")


@pytest.fixture
def indexed(tmp_path):
    source = tmp_path / "source.jsonl"
    source.write_text(
        "".join(
            json.dumps(
                {
                    "code": f"89000000{i:05}",
                    "countries_tags": ["en:india"],
                    "product_name": "Whole oats",
                }
            )
            + "\n"
            for i in range(3)
        ),
        encoding="utf-8",
    )
    manifest = build_catalogue(
        source,
        tmp_path,
        source_url="https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz",
        exported_at=datetime(2026, 10, 6, tzinfo=UTC),
    )
    return tmp_path, manifest


def test_indexed_search_api_is_no_store_bounded_and_never_live(indexed):
    directory, manifest = indexed
    with TestClient(
        create_app(
            Settings(_env_file=None, catalogue_directory=str(directory)),
            httpx.MockTransport(forbidden),
        )
    ) as client:
        response = client.get("/v1/catalogue/search", params={"q": "whole oa", "limit": 2})
        assert response.status_code == 200
        body = response.json()
        assert body["status"] == "ready" and body["matched_count"] == 3
        assert body["manifest"]["snapshot_id"] == manifest.snapshot_id
        assert body["manifest"]["database_license"] == "ODbL-1.0"
        assert len(body["candidates"]) == 2
        assert body["next_cursor"]
        assert response.headers["cache-control"] == "no-store"
        assert client.get("/v1/meta").json()["capabilities"]["catalogue_search"] is True
        last = client.get(
            "/v1/catalogue/search",
            params={"q": "whole oa", "limit": 2, "cursor": body["next_cursor"]},
        )
        assert last.status_code == 200 and len(last.json()["candidates"]) == 1
        assert (
            client.get("/v1/catalogue/search", params={"q": "absent"}).json()["status"]
            == "not_found"
        )
        assert client.get("/v1/catalogue/products/8900000000000").status_code == 200


@pytest.mark.parametrize(
    "params",
    [
        {},
        {"q": "a"},
        {"q": "SECRET\x00"},
        {"q": "x" * 129},
        {"q": "oats", "limit": 21},
        {"q": "oats", "cursor": "SECRET"},
    ],
)
def test_search_validation_is_redacted_422(indexed, params):
    directory, _ = indexed
    with TestClient(
        create_app(
            Settings(_env_file=None, catalogue_directory=str(directory)),
            httpx.MockTransport(forbidden),
        )
    ) as client:
        response = client.get("/v1/catalogue/search", params=params)
        assert response.status_code == 422
        assert "SECRET" not in response.text
        assert response.headers["cache-control"] == "no-store"


@pytest.mark.parametrize("state", ["unconfigured", "missing", "old"])
def test_discovery_unavailable_is_additive_and_does_not_create_files(indexed, state):
    directory, _ = indexed
    if state == "old":
        with sqlite3.connect(directory / "catalogue.sqlite3") as connection:
            for table in (
                "catalogue_search_terms",
                "catalogue_search_prefixes",
                "catalogue_search_counts",
                "catalogue_search_format",
            ):
                connection.execute(f"DROP TABLE {table}")
    elif state == "missing":
        directory = directory / "empty"
        directory.mkdir()
    config = Settings(
        _env_file=None, catalogue_directory="" if state == "unconfigured" else str(directory)
    )
    with TestClient(create_app(config, httpx.MockTransport(forbidden))) as client:
        response = client.get("/v1/catalogue/search", params={"q": "oats"})
        assert response.status_code == 503
        assert response.json()["status"] == "unavailable"
        assert response.json()["candidates"] == []
        assert client.get("/v1/meta").json()["capabilities"]["catalogue_search"] is False
        if state == "old":
            assert client.get("/v1/catalogue/products/8900000000000/facts").status_code == 200
        if state == "missing":
            assert not list(directory.iterdir())


def test_immutable_bundle_search_checks_loaded_receipt_snapshot(indexed):
    from app.catalogue.status import CatalogueArtifact

    directory, manifest = indexed
    application = create_app(
        Settings(_env_file=None, catalogue_directory=str(directory)), httpx.MockTransport(forbidden)
    )
    with TestClient(application) as client:
        application.state.catalogue_artifact = CatalogueArtifact(
            database_sha256="0" * 64,
            database_bytes=(directory / "catalogue.sqlite3").stat().st_size,
            source_sha256=manifest.source_sha256,
            snapshot_id="different",
        )
        result = client.get("/v1/catalogue/search", params={"q": "oa"})
        assert result.status_code == 503
        assert result.json()["candidates"] == []
