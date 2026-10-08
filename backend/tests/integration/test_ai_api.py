"""Scanner/machine authorization and shared global selection at the HTTP boundary."""

import json
from typing import cast

import httpx
import pytest
from fastapi.testclient import TestClient
from pydantic import SecretStr

from app.ai.models import MAX_REQUEST_BYTES
from app.ai.store import FirestoreAiSelectionStore
from app.api.v1.community import CommunityRuntimeProtocol
from app.community.auth import AuthenticationInvalid
from app.main import create_app
from tests.integration.test_community_api import FakeRuntime, forbidden
from tests.unit.test_ai_gateway import GEMINI_KEY, OPENAI_KEY, ai_config, provider_of
from tests.unit.test_ai_models import image_dict
from tests.unit.test_ai_providers import envelope
from tests.unit.test_community_store import MemoryFirestore

CONTROL = "synthetic-backend-control-secret-32chars"
SCANNER_HEADERS = {"Authorization": "Bearer alice"}
CONTROL_HEADERS = {"Authorization": "Bearer " + CONTROL}


class AiRuntime(FakeRuntime):
    def __init__(self, database=None):
        super().__init__()
        self.database = database or MemoryFirestore()
        self.ai_store = FirestoreAiSelectionStore(self.database)

    def verify_token(self, token: str) -> str:
        if token not in {"alice", "bob", "invalid", "unavailable"}:
            raise AuthenticationInvalid()
        return super().verify_token(token)


def body():
    return {"images": [image_dict()], "privacy_consent": True}


def client_for(runtime=None, respond=None, **changes):
    active = runtime or AiRuntime()
    config = ai_config(
        **{
            "community_enabled": True,
            "community_project_id": "unlabel-india-catalogue",
            "community_actor_secret": SecretStr("synthetic-actor-ownership-secret-32chars"),
            "ai_control_secret": SecretStr(CONTROL),
            "cors_origins": ["https://unlabel.example"],
            **changes,
        }
    )
    return TestClient(
        create_app(
            config,
            transport=httpx.MockTransport(forbidden),
            community_runtime=cast(CommunityRuntimeProtocol, active),
            ai_transport=httpx.MockTransport(
                respond
                or (lambda incoming: httpx.Response(200, json=envelope(provider_of(incoming))))
            ),
        )
    )


def test_authenticated_scanner_receives_qualified_private_facts_without_retaining_images_or_raw_output():
    runtime = AiRuntime()
    with client_for(runtime) as client:
        response = client.post("/v1/ai/extract", json=body(), headers=SCANNER_HEADERS)
        assert response.status_code == 200
        assert response.headers["cache-control"] == "no-store"
        result = response.json()
        assert result["status"] == "extracted"
        assert result["extraction"]["evidence"] == "machine_extracted_unverified"
        assert result['storage']['status'] == 'private_unverified'
        assert result["ai"] == {
            "scope": "global",
            "provider": "gemini",
            "model": "gemini-3.5-flash-lite",
            "revision": 1,
        }
        meta = client.get("/v1/meta")
        assert meta.json()["capabilities"]["ai_extraction"] is True
        assert meta.json()["capabilities"]["ai_explanations"] is False
        for secret in (GEMINI_KEY, OPENAI_KEY, CONTROL, "private-subject"):
            assert secret not in response.text and secret not in meta.text
    assert runtime.closed
    documents = repr(runtime.database.documents)
    for private in (
        GEMINI_KEY,
        OPENAI_KEY,
        CONTROL,
        "private-subject",
        "data_base64",
        body()["images"][0]["data_base64"],
    ):
        assert private not in documents
    staged = [value for key, value in runtime.database.documents.items()
              if key.startswith('unlabel_machine_staging/')]
    assert len(staged) == 1
    facts = json.loads(staged[0]['items'][0]['facts_json'])
    assert facts['ingredients'] == 'Oats, milk'
    assert 'regions' not in facts
    assert not any(key.startswith('community_') for key in runtime.database.documents)
    assert runtime.database.documents["unlabel_ai_limits/global"]["count"] == 1


def test_staging_outage_keeps_useful_reading_and_does_not_switch_global_key(monkeypatch):
    from app.community.store import StoreUnavailable
    runtime = AiRuntime()
    def unavailable(*args):
        raise StoreUnavailable()
    monkeypatch.setattr(runtime.ai_store, 'stage', unavailable)
    with client_for(runtime) as client:
        result = client.post('/v1/ai/extract', json=body(), headers=SCANNER_HEADERS)
    assert result.status_code == 200
    assert result.json()['storage'] == {
        'status': 'not_stored', 'reason': 'unavailable', 'content_sha256': None, 'deduplicated': False,
    }
    assert result.json()['extraction']['ingredients'] == 'Oats, milk'
    assert result.json()['ai']['revision'] == 1


@pytest.mark.parametrize(
    "authorization,status",
    [
        (None, 401),
        ("Bearer invalid", 401),
        ("Basic alice", 401),
        ("Bearer unavailable", 503),
        ("Bearer " + CONTROL, 401),
    ],
)
def test_photo_extraction_requires_verified_scanner_authentication(authorization, status):
    calls = []

    def respond(incoming):
        calls.append(incoming)
        raise AssertionError("Denied identity reached an AI provider")

    with client_for(respond=respond) as client:
        headers = {"Authorization": authorization} if authorization is not None else {}
        response = client.post("/v1/ai/extract", json=body(), headers=headers)
    assert response.status_code == status
    assert response.headers["cache-control"] == "no-store"
    assert calls == []


@pytest.mark.parametrize(
    "authorization", [None, "Bearer alice", "Bearer wrong-machine-key", CONTROL, "Basic " + CONTROL]
)
def test_machine_controls_cannot_be_called_with_scanner_or_malformed_authorization(authorization):
    with client_for() as client:
        headers = {"Authorization": authorization} if authorization is not None else {}
        assert client.get("/v1/ai/active", headers=headers).status_code == 401
        response = client.post(
            "/v1/ai/control/activate",
            json={"credential_id": "openai-primary", "expected_revision": 1},
            headers=headers,
        )
        assert response.status_code == 401
        assert CONTROL not in response.text


def test_machine_switch_is_global_across_deployed_app_instances_and_requires_current_revision():
    database = MemoryFirestore()
    calls = []

    def respond(incoming):
        provider = provider_of(incoming)
        calls.append(provider)
        return httpx.Response(200, json=envelope(provider))

    with (
        client_for(AiRuntime(database), respond) as first,
        client_for(AiRuntime(database), respond) as second,
    ):
        assert (
            first.post("/v1/ai/extract", json=body(), headers=SCANNER_HEADERS).json()["ai"][
                "provider"
            ]
            == "gemini"
        )
        before = first.get("/v1/ai/active", headers=CONTROL_HEADERS).json()
        response = first.post(
            "/v1/ai/control/activate",
            json={"credential_id": "openai-primary", "expected_revision": before["revision"]},
            headers=CONTROL_HEADERS,
        )
        assert response.status_code == 200
        assert response.json()["scope"] == "global"
        stale = second.post(
            "/v1/ai/control/activate",
            json={"credential_id": "gemini-primary", "expected_revision": before["revision"]},
            headers=CONTROL_HEADERS,
        )
        assert stale.status_code == 409
        for client in (first, second):
            response = client.post(
                "/v1/ai/extract", json=body(), headers={"Authorization": "Bearer bob"}
            )
            assert response.status_code == 200
            assert response.json()["ai"]["provider"] == "openai"
            assert response.json()["ai"]["revision"] == before["revision"] + 1
            assert all(secret not in response.text for secret in (GEMINI_KEY, OPENAI_KEY, CONTROL))
    assert calls == ["gemini", "openai", "openai"]


def test_missing_machine_control_secret_does_not_disable_scanner_extraction():
    with client_for(ai_control_secret=None) as client:
        assert client.get("/v1/ai/active", headers=CONTROL_HEADERS).status_code == 503
        assert (
            client.post("/v1/ai/extract", json=body(), headers=SCANNER_HEADERS).status_code == 200
        )


@pytest.mark.parametrize(
    "changes",
    [
        {"ai_enabled": False},
        {"gemini_api_key": None, "openai_api_key": None},
        {"community_enabled": False},
    ],
)
def test_unconfigured_ai_leaves_health_and_non_ai_workflows_usable(changes):
    with client_for(**changes) as client:
        assert (
            client.post("/v1/ai/extract", json=body(), headers=SCANNER_HEADERS).status_code == 503
        )
        assert client.get("/v1/health").status_code == 200
        assert client.get("/v1/claims/rules").status_code == 200
        assert client.get("/v1/meta").json()["capabilities"]["ai_extraction"] is False


@pytest.mark.parametrize(
    "extra",
    [
        {"provider": "openai"},
        {"model": "caller-model"},
        {"api_key": "private-caller-secret"},
        {"endpoint": "https://unexpected.test/"},
    ],
)
def test_scanners_cannot_select_a_different_provider_model_key_or_origin(extra):
    with client_for() as client:
        response = client.post("/v1/ai/extract", json={**body(), **extra}, headers=SCANNER_HEADERS)
        assert response.status_code == 422
        assert "private-caller-secret" not in response.text
        active = client.get("/v1/ai/active", headers=CONTROL_HEADERS).json()
        assert active["credential_id"] == "gemini-primary" and active["revision"] == 1


@pytest.mark.parametrize(
    "payload",
    [
        {"credential_id": "not-configured", "expected_revision": 1},
        {
            "credential_id": "openai-primary",
            "expected_revision": 1,
            "api_key": "private-extra-secret",
        },
    ],
)
def test_control_only_activates_existing_server_key_slots_without_accepting_a_new_key(payload):
    with client_for() as client:
        response = client.post("/v1/ai/control/activate", json=payload, headers=CONTROL_HEADERS)
        assert response.status_code == 422
        assert "private-extra-secret" not in response.text


def test_ai_four_mib_budget_applies_only_to_exact_extraction_path_and_actual_chunks():
    with client_for() as client:
        raw = json.dumps(body(), separators=(",", ":")).encode()
        full = raw + b" " * (MAX_REQUEST_BYTES - len(raw))
        response = client.post(
            "/v1/ai/extract",
            content=full,
            headers={**SCANNER_HEADERS, "Content-Type": "application/json"},
        )
        assert response.status_code == 200
        for data in (
            full + b" ",
            iter([b"x" * (MAX_REQUEST_BYTES // 2), b"x" * (MAX_REQUEST_BYTES // 2 + 1)]),
        ):
            response = client.post(
                "/v1/ai/extract",
                content=data,
                headers={**SCANNER_HEADERS, "Content-Type": "application/json"},
            )
            assert response.status_code == 413
            assert response.headers["cache-control"] == "no-store"
        for path in (
            "/v1/ai/control/activate",
            "/v1/ai/extract-extra",
            "/v1/nutrition/normalize",
            "/v1/community/contributions",
        ):
            response = client.post(path, content=b"x" * 32769)
            assert response.status_code == 413
            assert "32 KiB" in response.text


@pytest.mark.parametrize(
    "raw",
    [
        json.dumps({"images": [image_dict()]})[:-1]
        + ',"privacy_consent":false,"privacy_consent":true}',
        '{"private-field":"private-value","value":NaN}',
        '{"private-field":"private-value","value":1e-400}',
    ],
)
def test_ambiguous_consent_nonfinite_and_unrepresentable_numbers_are_rejected_without_echo(raw):
    with client_for() as client:
        response = client.post(
            "/v1/ai/extract",
            content=raw,
            headers={**SCANNER_HEADERS, "Content-Type": "application/json"},
        )
    assert response.status_code == 422
    assert "private-field" not in response.text and "private-value" not in response.text


def test_duplicate_control_json_is_rejected_instead_of_using_last_credential_id():
    raw = (
        '{"credential_id":"gemini-primary","credential_id":"openai-primary","expected_revision":1}'
    )
    with client_for() as client:
        response = client.post(
            "/v1/ai/control/activate",
            content=raw,
            headers={**CONTROL_HEADERS, "Content-Type": "application/json"},
        )
        assert response.status_code == 422


def test_invalid_image_and_private_extra_fields_are_sanitized_before_provider_admission():
    data = body()
    data["images"][0]["data_base64"] = "private-photo-payload"
    data["private-field"] = "private-value"
    with client_for() as client:
        response = client.post("/v1/ai/extract", json=data, headers=SCANNER_HEADERS)
    assert response.status_code == 422
    assert not any(
        private in response.text
        for private in ("private-photo-payload", "private-field", "private-value")
    )


def test_global_admission_remains_shared_across_http_app_instances():
    database = MemoryFirestore()
    calls = []

    def respond(incoming):
        calls.append(provider_of(incoming))
        return httpx.Response(200, json=envelope())

    with (
        client_for(AiRuntime(database), respond, ai_daily_request_limit=1) as first,
        client_for(AiRuntime(database), respond, ai_daily_request_limit=1) as second,
    ):
        assert first.post("/v1/ai/extract", json=body(), headers=SCANNER_HEADERS).status_code == 200
        response = second.post(
            "/v1/ai/extract", json=body(), headers={"Authorization": "Bearer bob"}
        )
        assert response.status_code == 429
        assert response.json()["code"] == "ai_admission_limit"
    assert calls == ["gemini"]


@pytest.mark.parametrize(
    "mode,status,code",
    [("refusal", 502, "ai_invalid_response"), ("busy", 503, "ai_busy"), ("quota", 429, "ai_quota")],
)
def test_provider_errors_are_qualified_private_and_do_not_leak_response_or_key(mode, status, code):
    def respond(_):
        if mode == "busy":
            raise httpx.PoolTimeout("private-provider-error" + GEMINI_KEY)
        if mode == "quota":
            return httpx.Response(
                429, text="private-provider-error" + GEMINI_KEY, headers={"Retry-After": "7200"}
            )
        return httpx.Response(
            200, json={"promptFeedback": {"blockReason": "private-provider-error"}}
        )

    with client_for(respond=respond, ai_failover_enabled=False) as client:
        response = client.post("/v1/ai/extract", json=body(), headers=SCANNER_HEADERS)
    assert response.status_code == status
    assert response.json()["code"] == code
    assert response.headers["cache-control"] == "no-store"
    assert "private-provider-error" not in response.text and GEMINI_KEY not in response.text
    if mode == "quota":
        assert int(response.headers["retry-after"]) == 7200


def test_cors_allows_authorized_photo_requests_without_credentials_or_private_cache():
    with client_for() as client:
        response = client.options(
            "/v1/ai/extract",
            headers={
                "Origin": "https://unlabel.example",
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "Authorization,Content-Type",
            },
        )
    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "https://unlabel.example"
    assert "access-control-allow-credentials" not in response.headers
