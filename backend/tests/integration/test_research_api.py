"""The configured app serves web products independently of OFF or authentication."""

from pathlib import Path

import httpx
import pytest
from fastapi.testclient import TestClient

from app.core.config import Settings
from app.main import create_app
from app.research_catalogue.store import build_research_bundle

ROOT = Path(__file__).resolve().parents[3]


def test_real_researched_bundle_is_searchable_and_keeps_unknown_barcode(tmp_path):
    build_research_bundle(ROOT / "data/catalogue/popular-india-v1", tmp_path / "research")

    def no_off_reads(_request):
        raise AssertionError("Researched products cannot require a live OFF call")

    app = create_app(
        Settings(_env_file=None, research_catalogue_directory=str(tmp_path / "research")),
        transport=httpx.MockTransport(no_off_reads),
    )
    with TestClient(app) as client:
        meta = client.get("/v1/meta").json()
        assert meta["capabilities"]["research_catalogue"] is True
        assert meta["research_catalogue"]["observation_count"] >= 155
        assert meta["capabilities"]["catalogue_search"] is False
        result = client.get(
            "/v1/researched/products/search", params={"q": "Coca Cola Original"}
        ).json()
        assert result["status"] == "ready"
        item = next(item for item in result["candidates"] if item["provider"] == "manufacturer")
        assert item["identity"]["barcode"] is None
        response = client.get("/v1/researched/products/" + item["entry_id"])
        assert response.status_code == 200 and response.headers["cache-control"] == "no-store"
        observed = response.json()["observation"]
        assert observed["observation_id"] == item["entry_id"]
        assert observed["source"]["provider"] == "manufacturer"
        assert observed["sections"]["ingredients"]["text"]
        assert client.get("/v1/researched/products/search", params={"q": "x"}).status_code == 422


def test_bad_research_bundle_leaves_other_service_operations_usable(tmp_path):
    with TestClient(
        create_app(Settings(_env_file=None, research_catalogue_directory=str(tmp_path)))
    ) as client:
        assert client.get("/v1/health").status_code == 200
        assert client.get("/v1/meta").json()["capabilities"]["research_catalogue"] is False
        response = client.get("/v1/researched/products/search", params={"q": "Pepsi"})
        assert response.status_code == 503
        assert response.json()["status"] == "unavailable"


@pytest.mark.parametrize("change", ["tamper", "remove"])
def test_changed_active_research_bundle_keeps_metadata_and_capabilities_consistent(
    tmp_path, change
):
    directory = tmp_path / "research"
    build_research_bundle(ROOT / "data/catalogue/popular-india-v1", directory)

    def no_off_reads(_request):
        raise AssertionError("Research metadata cannot fall back to a live provider")

    app = create_app(
        Settings(_env_file=None, research_catalogue_directory=str(directory)),
        transport=httpx.MockTransport(no_off_reads),
    )
    with TestClient(app) as client:
        original = client.get("/v1/meta").json()
        assert original["research_catalogue"]["status"] == "ready"
        assert original["capabilities"]["research_catalogue"] is True
        database = directory / "research.sqlite3"
        if change == "tamper":
            with database.open("ab") as stream:
                stream.write(b"private-tamper-fixture")
        else:
            database.unlink()

        response = client.get("/v1/meta")
        assert response.status_code == 200
        meta = response.json()
        assert meta["research_catalogue"] == {"status": "unavailable"}
        assert meta["capabilities"]["research_catalogue"] is False
        assert meta["capabilities"]["product_lookup"] is True
        assert meta["backend_version"] == original["backend_version"]
        assert "private-tamper-fixture" not in response.text
        assert client.get("/v1/health").status_code == 200
        for path, params in (
            ("/v1/researched/products/search", {"q": "Pepsi"}),
            ("/v1/researched/products/" + "a" * 64, None),
            ("/v1/researched/products/by-barcode/12345678", None),
        ):
            result = client.get(path, params=params)
            assert result.status_code == 503 and result.json()["status"] == "unavailable"
