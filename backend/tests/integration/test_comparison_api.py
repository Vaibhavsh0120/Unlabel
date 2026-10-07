"""Comparison transport limits, sanitized validation, independent readiness."""

import json

from fastapi.testclient import TestClient

from app.core.config import Settings
from app.main import create_app
from tests.unit.test_comparison import payload


def test_current_comparison_works_without_auth_catalogue_or_cloud():
    with TestClient(
        create_app(Settings(_env_file=None, cors_origins=["https://app.example"]))
    ) as client:
        response = client.post(
            "/v1/reports/compare", json=payload(), headers={"Origin": "https://app.example"}
        )
        assert response.status_code == 200
        assert response.json()["storage"] == "read_only"
        assert response.headers["cache-control"] == "no-store"
        assert response.headers["access-control-allow-origin"] == "https://app.example"
        meta = client.get("/v1/meta").json()
        assert meta["capabilities"]["comparison"] is True
        assert meta["comparison_version"] == "sourced-nutrient-comparison-v1"


def test_redacted_invalid_numbers_and_actual_body_limit():
    with TestClient(create_app(Settings(_env_file=None))) as client:
        value = payload()
        value["a"]["observation"]["confirmed"] = False
        value["a"]["observation"]["identity"]["name"] = "DO-NOT-ECHO"
        response = client.post("/v1/reports/compare", json=value)
        assert response.status_code == 422
        assert "DO-NOT-ECHO" not in response.text
        for number in ("NaN", "1e-999", "1.0000000000000000000001"):
            body = json.dumps(payload()).replace(
                '"input_revision": 3', f'"input_revision": {number}'
            )
            response = client.post(
                "/v1/reports/compare", content=body, headers={"Content-Type": "application/json"}
            )
            assert response.status_code == 422
        response = client.post("/v1/reports/compare", content=b" " * 65537)
        assert response.status_code == 413
        assert response.json()["detail"] == "Request body exceeds 64 KiB"
        assert response.headers["cache-control"] == "no-store"
        # No Content-Length: enforce the actual accumulated ASGI chunks too.
        response = client.post("/v1/reports/compare", content=iter([b" " * 32768, b" " * 32769]))
        assert response.status_code == 413
        assert response.json()["detail"] == "Request body exceeds 64 KiB"


def test_disallowed_origin_and_preflight():
    with TestClient(
        create_app(Settings(_env_file=None, cors_origins=["https://app.example"]))
    ) as client:
        assert (
            "access-control-allow-origin"
            not in client.post(
                "/v1/reports/compare", json=payload(), headers={"Origin": "https://other.example"}
            ).headers
        )
        response = client.options(
            "/v1/reports/compare",
            headers={
                "Origin": "https://app.example",
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "Content-Type",
            },
        )
        assert response.status_code == 200
