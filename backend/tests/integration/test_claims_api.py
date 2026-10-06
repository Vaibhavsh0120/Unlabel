import json
from pathlib import Path

import httpx
import pytest
from fastapi.testclient import TestClient

from app.claims.models import ClaimsResponse, ClaimsRulesResponse, EvidenceResponse
from app.core.config import Settings
from app.main import create_app

KNOWLEDGE = Path(__file__).resolve().parents[3] / "knowledge"


def payload():
    return {
        "schema_version": "1",
        "client_request_id": "4ca97170-4077-4af4-bc75-b1d4b632f01f",
        "capture_session_id": "960f1c01-981d-4fe6-8394-31c4470e7936",
        "input_revision": 2,
        "confirmed": True,
        "completeness": "partial",
        "selected_table_id": "back-panel",
        "context": {
            "food_category": "ordinary_general_food",
            "form": "solid",
            "preparation": "as_sold",
        },
        "claims": [
            {"claim_id": "front-low-sugar", "claim": "low_sugar", "region_id": "front-text"}
        ],
        "rows": [
            {
                "row_id": "sugar-line",
                "table_id": "back-panel",
                "nutrient": "sugars",
                "value": 5,
                "unit": "g",
                "basis": {"kind": "quantity", "amount": 100, "unit": "g"},
                "preparation": "as_sold",
            }
        ],
    }


def make_client(directory=KNOWLEDGE):
    def forbidden(request):
        raise AssertionError("Claim checks must not contact OFF")

    return TestClient(
        create_app(
            Settings(
                _env_file=None,
                claims_knowledge_directory=str(directory),
                cors_origins=["https://unlabel.example"],
            ),
            httpx.MockTransport(forbidden),
        )
    )


def test_confirmed_claims_rules_evidence_and_metadata_without_provider():
    with make_client() as client:
        result = client.post("/v1/claims/check", json=payload())
        assert result.status_code == 200
        parsed = ClaimsResponse.model_validate_json(result.content)
        assert parsed.assessments[0].status == "supported"
        assert parsed.input_revision == 2 and parsed.assessments[0].region_id == "front-text"
        assert result.headers["cache-control"] == "no-store"
        rules = ClaimsRulesResponse.model_validate_json(client.get("/v1/claims/rules").content)
        assert len(rules.rules) == 7
        for source in rules.rules[0].source_ids:
            evidence = client.get(f"/v1/evidence/{source}")
            assert evidence.status_code == 200
            parsed_evidence = EvidenceResponse.model_validate_json(evidence.content)
            assert parsed_evidence.source is not None
            assert parsed_evidence.source.source_id == source
        assert client.get("/v1/evidence/unknown-source").status_code == 404
        assert client.get("/v1/meta").json()["capabilities"]["claim_checks"]
        assert client.get("/v1/meta").json()["knowledge_version"] == parsed.knowledge_version


def test_missing_knowledge_disables_only_claims(tmp_path):
    with make_client(tmp_path) as client:
        for method, path, options in [
            ("POST", "/v1/claims/check", {"json": payload()}),
            ("GET", "/v1/claims/rules", {}),
            ("GET", "/v1/evidence/fssai-ac-2018-general", {}),
        ]:
            response = client.request(method, path, **options)
            assert response.status_code == 503
            assert str(tmp_path) not in response.text
        assert client.get("/v1/health").status_code == 200
        assert not client.get("/v1/meta").json()["capabilities"]["claim_checks"]


@pytest.mark.parametrize(
    "token", ["1e-400", "-1e-400", "5.00000000000000001", "NaN", "Infinity", "1e9999"]
)
@pytest.mark.parametrize("path", ["/v1/claims/check", "/v1/claims/check/"])
def test_claim_json_numbers_are_checked_before_redirect_or_model(token, path):
    raw = json.dumps(payload()).replace('"value": 5', f'"value": {token}')
    with make_client() as client:
        response = client.post(
            path, content=raw, headers={"Content-Type": "application/json"}, follow_redirects=False
        )
    assert response.status_code == 422
    assert token not in response.text


def test_unconfirmed_private_inputs_and_extras_are_redacted():
    data = payload()
    data["confirmed"] = False
    data["rows"][0]["private-secret"] = "private input marker"
    data.update({f"private-name-{i}": "private input marker" for i in range(100)})
    with make_client() as client:
        response = client.post("/v1/claims/check", json=data)
    assert response.status_code == 422 and response.json()["errors_truncated"]
    assert len(response.json()["detail"]) == 32
    assert "private-name" not in response.text and "private input marker" not in response.text


def test_claim_body_limit_and_cors():
    with make_client() as client:
        response = client.post(
            "/v1/claims/check", content=b"x" * 32769, headers={"Origin": "https://unlabel.example"}
        )
        assert response.status_code == 413
        assert response.headers["access-control-allow-origin"] == "https://unlabel.example"
        preflight = client.options(
            "/v1/claims/check",
            headers={
                "Origin": "https://unlabel.example",
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "Content-Type",
            },
        )
        assert preflight.status_code == 200


def test_claim_deep_json_is_sanitized():
    with make_client() as client:
        response = client.post(
            "/v1/claims/check",
            content="[" * 1500 + "0" + "]" * 1500,
            headers={"Content-Type": "application/json"},
        )
    assert response.status_code == 422 and len(response.content) < 1000


def test_tampered_packaged_knowledge_never_falls_back_to_source(tmp_path):
    from app.claims.bundle import build_knowledge_bundle

    directory = tmp_path / "packaged"
    build_knowledge_bundle(KNOWLEDGE, directory)
    with make_client(directory) as client:
        receipt = client.get("/v1/meta").json()["knowledge_artifact"]
        assert receipt["knowledge_version"] == "claims-2026-10-06.1"
        assert len(receipt["files"]) == 2
    rule = directory / "rules/claims/reviewed-v1.json"
    rule.write_bytes(rule.read_bytes() + b" ")
    with make_client(directory) as client:
        assert client.get("/v1/claims/rules").status_code == 503
        assert not client.get("/v1/meta").json()["capabilities"]["claim_checks"]


def test_vercel_knowledge_default_requires_packaged_path(monkeypatch):
    monkeypatch.setenv("VERCEL", "1")
    settings = Settings(_env_file=None)
    assert settings.claims_knowledge_path().as_posix().endswith("/backend/app/claims/data")


def test_hosted_directory_override_still_requires_receipt(tmp_path, monkeypatch):
    from app.claims.bundle import build_knowledge_bundle

    directory = tmp_path / "hosted-bundle"
    build_knowledge_bundle(KNOWLEDGE, directory)
    (directory / "receipt.json").unlink()
    monkeypatch.setenv("VERCEL", "1")
    with make_client(directory) as client:
        assert client.get("/v1/claims/rules").status_code == 503
        assert not client.get("/v1/meta").json()["capabilities"]["claim_checks"]
