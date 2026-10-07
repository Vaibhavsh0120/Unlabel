import json
from pathlib import Path

import httpx
import pytest
from fastapi.testclient import TestClient

from app.core.config import Settings
from app.main import create_app
from app.schemas.products import ProductLookup


def payload():
    return {
        "schema_version": "1",
        "client_request_id": "4ca97170-4077-4af4-bc75-b1d4b632f01f",
        "capture_session_id": "960f1c01-981d-4fe6-8394-31c4470e7936",
        "input_revision": 2,
        "confirmed": True,
        "completeness": "complete",
        "rows": [
            {
                "row_id": "protein-line",
                "table_id": "back-panel",
                "nutrient": "protein",
                "value": 4,
                "unit": "g",
                "basis": {"kind": "serving", "amount": 40, "unit": "g"},
                "preparation": "as_sold",
            }
        ],
    }


def make_client():
    def forbidden(request):
        raise AssertionError("Confirmed normalization must not contact OFF")

    return TestClient(
        create_app(
            Settings(_env_file=None, cors_origins=["https://unlabel.example"]),
            httpx.MockTransport(forbidden),
        )
    )


def test_confirmed_intake_normalizes_and_echoes_revision_without_provider_or_persistence():
    with make_client() as client:
        result = client.post("/v1/nutrition/normalize", json=payload())
    assert result.status_code == 200
    data = result.json()
    assert data["client_request_id"] == payload()["client_request_id"]
    assert data["input_revision"] == 2
    assert data["assessment_basis"] == "user_confirmed_label"
    assert data["snapshot"]["tables"][0]["nutrients"]["protein"]["value"] == 10
    assert data["snapshot"]["tables"][0]["nutrients"]["added_sugars"]["value"] is None
    assert result.headers["cache-control"] == "no-store"


@pytest.mark.parametrize(
    "field,value",
    [
        ("confirmed", False),
        ("input_revision", True),
        ("profile", {"name": "SECRET-NAME"}),
        ("provider_api_key", "SECRET-KEY"),
    ],
)
def test_invalid_and_private_inputs_are_rejected_without_echoing_values(field, value):
    data = payload()
    data[field] = value
    with make_client() as client:
        response = client.post("/v1/nutrition/normalize", json=data)
    assert response.status_code == 422
    assert "SECRET" not in response.text
    assert all("input" not in item for item in response.json()["detail"])


def test_oversized_declared_and_streamed_bodies_are_rejected_with_cors():
    with make_client() as client:
        for body in [b"x" * 32769, iter([b"x" * 20000, b"x" * 20000])]:
            response = client.post(
                "/v1/nutrition/normalize",
                content=body,
                headers={"Content-Type": "application/json", "Origin": "https://unlabel.example"},
            )
            assert response.status_code == 413
            assert response.headers["access-control-allow-origin"] == "https://unlabel.example"
        assert client.post("/v1/nutrition/normalize", json=payload()).status_code == 200


def test_post_preflight_and_old_strict_fixture_are_compatible():
    with make_client() as client:
        response = client.options(
            "/v1/nutrition/normalize",
            headers={
                "Origin": "https://unlabel.example",
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "Content-Type",
            },
        )
        assert response.status_code == 200
        meta = client.get("/v1/meta").json()
        assert meta["capabilities"]["nutrition_normalization"] is True
        assert meta["capabilities"]["nutrition_analysis"] is True
        assert meta["capabilities"]["label_reports"] is True
        assert meta["report_version"] == "label-report-v1"
    fixture = (
        Path(__file__).resolve().parents[3] / "contracts/examples/product-lookup-v1.synthetic.json"
    )
    ProductLookup.model_validate(json.loads(fixture.read_text()))


@pytest.mark.parametrize(
    "token",
    [
        "1e-400",
        "-1e-400",
        "1000000.0000000000001",
        "NaN",
        "Infinity",
        "1e-99999999999999999999",
        "0e-9999999999999999999999",
    ],
)
def test_json_numeric_tokens_cannot_silently_become_zero_or_bypass_bounds(token):
    raw = json.dumps(payload()).replace('"value": 4', f'"value": {token}')
    with make_client() as client:
        response = client.post(
            "/v1/nutrition/normalize", content=raw, headers={"Content-Type": "application/json"}
        )
    assert response.status_code == 422
    assert token not in response.text


def test_validation_errors_are_bounded_even_with_many_private_extra_fields():
    data = payload()
    data.update({f"SECRET-{index}": 1 for index in range(1000)})
    with make_client() as client:
        response = client.post("/v1/nutrition/normalize", json=data)
    assert response.status_code == 422
    assert len(response.json()["detail"]) == 32
    assert response.json()["errors_truncated"] is True
    assert len(response.content) < 10000
    assert "SECRET" not in response.text


async def test_actual_asgi_chunk_budget_is_checked_before_inner_application():
    from app.core.body_limit import RequestBodyLimit

    calls = []

    async def inner(scope, receive, send):
        calls.append(await receive())

    scope = {"type": "http", "method": "POST", "path": "/other", "headers": []}
    for sizes, rejected in [([16000, 16000], False), ([16000, 17000], True)]:
        messages = [
            {"type": "http.request", "body": b"x" * size, "more_body": index == 0}
            for index, size in enumerate(sizes)
        ]
        sent = []

        async def receive(message_queue=messages):
            return message_queue.pop(0)

        async def send(message, buffer=sent):
            buffer.append(message)

        calls.clear()
        await RequestBodyLimit(inner)(scope, receive, send)
        if rejected:
            assert calls == []
            assert sent[0]["status"] == 413
        else:
            assert len(calls[0]["body"]) == 32000
