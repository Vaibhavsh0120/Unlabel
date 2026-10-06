import json
import tomllib
from pathlib import Path

import httpx
import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app import __version__
from app.core.config import Settings
from app.main import create_app


def client_with(response):
    return TestClient(
        create_app(
            Settings(_env_file=None, cors_origins=["https://unlabel.example"]),
            transport=httpx.MockTransport(lambda request: response),
        )
    )


def test_service_endpoints_do_not_call_provider_and_future_features_are_disabled():
    def forbidden(request):
        raise AssertionError("Health/meta must not call OFF")

    with TestClient(create_app(Settings(_env_file=None), httpx.MockTransport(forbidden))) as client:
        assert client.get("/v1/health").json()["provider_connectivity"] == "not_checked"
        meta = client.get("/v1/meta").json()
        assert meta["backend_version"] == "0.2.1"
        assert meta["capabilities"]["product_lookup"] is True
        assert {key for key, enabled in meta["capabilities"].items() if enabled} == {
            "product_lookup",
            "nutrition_lookup",
            "nutrition_normalization",
        }
        assert client.get("/v1/analyze").status_code == 404
        assert client.get("/openapi.json").json()["info"]["version"] == "0.2.1"


@pytest.mark.parametrize(
    "barcode", ["abc", "123", "123456789", "123456789012345", "１２３４５６７８"]
)
def test_invalid_barcodes_never_reach_provider(barcode):
    def forbidden(request):
        raise AssertionError("Invalid barcode reached OFF")

    with TestClient(create_app(Settings(_env_file=None), httpx.MockTransport(forbidden))) as client:
        assert client.get(f"/v1/products/{barcode}").status_code == 422


@pytest.mark.parametrize(
    ("status", "expected", "state"),
    [
        (404, 404, "not_found"),
        (429, 429, "rate_limited"),
        (503, 503, "unavailable"),
        (200, 502, "incompatible_response"),
    ],
)
def test_failure_contract_http_statuses_and_cache_policy(status, expected, state):
    with client_with(httpx.Response(status, text="invalid")) as client:
        response = client.get("/v1/products/0123456789012")
        assert response.status_code == expected
        assert response.json()["status"] == state
        assert response.json()["product"] is None
        assert response.headers["cache-control"] == "no-store"


def test_found_api_serializes_provenance_and_filters_provider_internals():
    data = {
        "status": "success",
        "product": {
            "code": "0123456789012",
            "product_name": "Fixture",
            "internal_secret": "do-not-expose",
        },
    }
    with client_with(httpx.Response(200, json=data)) as client:
        response = client.get("/v1/products/0123456789012")
        assert response.status_code == 200
        assert response.json()["source"]["database_license"] == "ODbL-1.0"
        assert "internal_secret" not in response.text
        assert response.json()["product"]["insights"]["nutri_score_grade"] is None


@pytest.mark.parametrize(
    ("field", "value", "output_field", "expected"),
    [
        ("product_name", "\ud800", "name", None),
        ("allergens_tags", ["en:milk\udfff"], "allergen_tags", []),
    ],
)
def test_invalid_unicode_provider_fields_do_not_break_response_serialization(
    field, value, output_field, expected
):
    data = {"status": "success", "product": {"code": "0123456789012", field: value}}
    with client_with(httpx.Response(200, content=json.dumps(data).encode())) as client:
        response = client.get("/v1/products/0123456789012")
        assert response.status_code == 200
        assert response.json()["product"][output_field] == expected
        assert f"{field}_invalid" in response.json()["warnings"]
        assert "allergen_safety_not_assessed" in response.json()["warnings"]


def test_exact_origin_cors_does_not_treat_cors_as_auth():
    with client_with(httpx.Response(404)) as client:
        good = client.get("/v1/health", headers={"Origin": "https://unlabel.example"})
        assert good.headers["access-control-allow-origin"] == "https://unlabel.example"
        other = client.get("/v1/health", headers={"Origin": "https://other.example"})
        assert other.status_code == 200
        assert "access-control-allow-origin" not in other.headers
        preflight = client.options(
            "/v1/products/0123456789012",
            headers={"Origin": "https://unlabel.example", "Access-Control-Request-Method": "GET"},
        )
        assert preflight.status_code == 200


@pytest.mark.parametrize(
    "origins",
    [
        ["*"],
        ["https://example.org/path"],
        ["null"],
        ["https://example.org:bad"],
        [" https://example.org"],
    ],
)
def test_invalid_cors_config_is_rejected(origins):
    with pytest.raises(ValidationError):
        Settings(_env_file=None, cors_origins=origins)


def test_backend_version_matches_manifest_without_changing_frontend():
    backend = Path(__file__).resolve().parents[2]
    assert (
        tomllib.loads((backend / "pyproject.toml").read_text())["project"]["version"] == __version__
    )
    assert "version: 0.0.0+1" in (backend.parent / "frontend/pubspec.yaml").read_text()
