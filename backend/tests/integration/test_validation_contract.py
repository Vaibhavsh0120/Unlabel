import httpx
import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.core.config import Settings
from app.main import create_app
from app.schemas.errors import ValidationErrorDetail, ValidationFailure

ROUTES = [
    ("/v1/health", "get"),
    ("/v1/meta", "get"),
    ("/v1/products/{barcode}", "get"),
    ("/v1/products/{barcode}/nutrition", "get"),
    ("/v1/nutrition/normalize", "post"),
    ("/v1/catalogue/products/{barcode}", "get"),
]


@pytest.mark.parametrize("token", ["NaN", "1e-9999", "1.234567890123456789"])
def test_raw_json_numeric_rejection_matches_shared_422_schema(token):
    with make_client() as client:
        response = client.post(
            "/v1/nutrition/normalize",
            content='{"value":' + token + "}",
            headers={"Content-Type": "application/json"},
        )
    assert response.status_code == 422
    assert token not in response.text
    assert ValidationFailure.model_validate(response.json()).errors_truncated is False


def make_client():
    def forbidden(request):
        raise AssertionError("Invalid input must not contact the product provider")

    return TestClient(create_app(Settings(_env_file=None), httpx.MockTransport(forbidden)))


def normalize_payload():
    return {
        "client_request_id": "4ca97170-4077-4af4-bc75-b1d4b632f01f",
        "capture_session_id": "960f1c01-981d-4fe6-8394-31c4470e7936",
        "input_revision": 0,
        "confirmed": True,
        "completeness": "complete",
        "rows": [
            {
                "row_id": "protein-line",
                "table_id": "back-panel",
                "nutrient": "protein",
                "value": 4,
                "unit": "g",
                "basis": {"kind": "quantity", "amount": 100, "unit": "g"},
                "preparation": "as_sold",
            }
        ],
    }


def test_openapi_422_schema_matches_the_redacted_validation_response():
    with make_client() as client:
        response = client.get("/v1/products/SECRET-BARCODE")
        operation = client.get("/openapi.json").json()["paths"]["/v1/products/{barcode}"]["get"]

    assert response.status_code == 422
    assert "SECRET-BARCODE" not in response.text
    assert set(response.json()) == {"detail", "errors_truncated"}
    assert ValidationFailure.model_validate(response.json()).errors_truncated is False
    assert response.json()["detail"] == [
        {
            "loc": ["path", "barcode"],
            "type": "string_pattern_mismatch",
            "msg": "Invalid request data",
        }
    ]
    assert response.headers["cache-control"] == "no-store"
    assert operation["responses"]["422"]["content"]["application/json"]["schema"] == {
        "$ref": "#/components/schemas/ValidationFailure"
    }


@pytest.mark.parametrize("path,method", ROUTES)
def test_every_route_documents_the_shared_422_contract(path, method):
    with make_client() as client:
        document = client.get("/openapi.json").json()

    assert document["paths"][path][method]["responses"]["422"]["content"]["application/json"][
        "schema"
    ] == {"$ref": "#/components/schemas/ValidationFailure"}
    failure = document["components"]["schemas"]["ValidationFailure"]
    detail = document["components"]["schemas"]["ValidationErrorDetail"]
    assert failure["additionalProperties"] is False
    assert set(failure["required"]) == {"detail", "errors_truncated"}
    assert failure["properties"]["detail"]["maxItems"] == 32
    assert failure["properties"]["detail"]["items"] == {
        "$ref": "#/components/schemas/ValidationErrorDetail"
    }
    assert failure["properties"]["errors_truncated"]["type"] == "boolean"
    assert detail["additionalProperties"] is False
    assert set(detail["required"]) == {"loc", "type", "msg"}


@pytest.mark.parametrize("extra_count", [1, 32, 33])
def test_private_extra_fields_are_redacted_and_error_truncation_matches_the_contract(extra_count):
    payload = normalize_payload()
    payload.update(
        {f"SECRET-private-field-{index}": "SECRET-VALUE" for index in range(extra_count)}
    )
    with make_client() as client:
        response = client.post("/v1/nutrition/normalize", json=payload)

    assert response.status_code == 422
    assert "SECRET" not in response.text
    failure = ValidationFailure.model_validate(response.json())
    assert len(failure.detail) == min(extra_count, 32)
    assert failure.errors_truncated is (extra_count > 32)
    assert all(
        item.model_dump()
        == {
            "loc": ["body", "<unknown_field>"],
            "type": "extra_forbidden",
            "msg": "Invalid request data",
        }
        for item in failure.detail
    )


@pytest.mark.parametrize("location", ["response", "detail"])
def test_validation_models_forbid_unpublished_fields(location):
    with make_client() as client:
        response = client.get("/v1/products/SECRET-BARCODE")
    payload = response.json()
    ValidationFailure.model_validate(payload)
    target = payload if location == "response" else payload["detail"][0]
    target["input"] = "SECRET-VALUE"
    with pytest.raises(ValidationError, match="Extra inputs are not permitted"):
        ValidationFailure.model_validate(payload)


def test_validation_models_enforce_handler_types_and_the_32_error_limit():
    detail = {"loc": ["body", "rows", 0], "type": "value_error", "msg": "Invalid request data"}
    assert ValidationErrorDetail.model_validate(detail).loc == ["body", "rows", 0]
    with pytest.raises(ValidationError):
        ValidationFailure.model_validate({"detail": [detail], "errors_truncated": "false"})
    with pytest.raises(ValidationError):
        ValidationFailure.model_validate({"detail": [detail] * 33, "errors_truncated": True})
    with pytest.raises(ValidationError):
        ValidationErrorDetail.model_validate({**detail, "loc": [True]})
    with pytest.raises(ValidationError):
        ValidationErrorDetail.model_validate({**detail, "msg": "SECRET-VALUE"})
