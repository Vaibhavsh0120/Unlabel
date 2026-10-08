import json
import threading
from pathlib import Path
from typing import cast
from uuid import UUID

import httpx
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from pydantic import SecretStr, ValidationError

from app.api.v1.community import CommunityRuntimeProtocol
from app.catalogue.facts import FactsLookup
from app.community.auth import AuthenticationInvalid, AuthenticationUnavailable
from app.community.models import CommunityLookup, ContributionReceipt, PreparedContribution
from app.community.service import verify_provider_references
from app.community.store import StoreConflict, StoreQuotaExceeded, StoreUnavailable
from app.core.config import Settings
from app.main import create_app
from tests.community_fixtures import NOW, candidate_revision, contribution_dict

CODE = "0123456789012"
SUBMISSION = "10000000-0000-4000-8000-000000000001"


def forbidden(request):
    raise AssertionError("Community endpoints must not call live OFF")


def test_disabled_community_endpoints_are_typed_unavailable_without_breaking_existing_api():
    with TestClient(create_app(Settings(_env_file=None), httpx.MockTransport(forbidden))) as client:
        for path in (
            f"/v1/community/products/{CODE}",
            f"/v1/community/contributions/{SUBMISSION}",
            f"/v1/products/{CODE}/resolved",
        ):
            response = client.get(path)
            assert response.status_code == 503
            assert response.headers["cache-control"] == "no-store"
        meta = client.get("/v1/meta").json()
        assert meta["community"]["status"] == "not_configured"
        assert meta["community"]["provider_connectivity"] == "not_checked"
        assert meta["capabilities"]["community_contributions"] is False
        assert meta["capabilities"]["community_lookup"] is False
        assert meta["capabilities"]["resolved_product_lookup"] is False
        assert client.get("/v1/health").status_code == 200
        assert client.get("/v1/claims/rules").status_code == 200
        assert len(client.get("/openapi.json").json()["paths"]) == 24


def test_community_secrets_are_typed_and_short_actor_secrets_are_rejected():
    settings = Settings(
        _env_file=None,
        community_service_account_json=SecretStr('{"private_key":"synthetic-secret"}'),
        community_actor_secret=SecretStr("x" * 32),
    )
    assert isinstance(settings.community_service_account_json, SecretStr)
    assert isinstance(settings.community_actor_secret, SecretStr)
    assert "synthetic-secret" not in repr(settings)
    with pytest.raises(ValidationError):
        Settings(_env_file=None, community_actor_secret=SecretStr("short"))


@pytest.mark.parametrize(
    "field,value", [("community_project_id", "../private"), ("community_database_id", "other")]
)
def test_community_configuration_rejects_unbounded_or_unintended_targets(field, value):
    with pytest.raises(ValidationError):
        Settings(_env_file=None, **{field: value})


def test_community_input_size_number_redaction_and_authorization_preflight():
    settings = Settings(_env_file=None, cors_origins=["https://unlabel.example"])
    with TestClient(create_app(settings, httpx.MockTransport(forbidden))) as client:
        for body in (b"x" * 32769, iter([b"x" * 20000, b"x" * 20000])):
            response = client.post(
                "/v1/community/contributions",
                content=body,
                headers={"Content-Type": "application/json", "Origin": "https://unlabel.example"},
            )
            assert response.status_code == 413
            assert response.headers["access-control-allow-origin"] == "https://unlabel.example"
        response = client.post(
            "/v1/community/contributions",
            content='{"private":"SECRET-NAME", "value":1e-400}',
            headers={"Content-Type": "application/json"},
        )
        assert response.status_code == 422
        assert response.json()["detail"][0]["type"] == "invalid_json_number"
        assert "SECRET" not in response.text
        response = client.options(
            "/v1/community/contributions",
            headers={
                "Origin": "https://unlabel.example",
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "Authorization,Content-Type",
            },
        )
        assert response.status_code == 200


def test_community_extra_fields_do_not_echo_private_values_or_field_names():
    with TestClient(create_app(Settings(_env_file=None), httpx.MockTransport(forbidden))) as client:
        response = client.post(
            "/v1/community/contributions", json={"SECRET-field": {"private": "SECRET-value"}}
        )
    assert response.status_code == 422
    assert "SECRET" not in response.text
    assert all("input" not in item for item in response.json()["detail"])
    assert len(json.dumps(response.json())) < 10000


class FakeStore:
    def __init__(self):
        self.receipts = {}
        self.calls = []
        self.error: Exception | None = None
        self.revisions = []

    def submit(self, actor_id: str, prepared: PreparedContribution, baseline=None):
        if self.error:
            raise self.error
        existing = self.receipts.get((actor_id, prepared.request.submission_id))
        if existing is not None:
            if existing.content_sha256 != prepared.content_sha256:
                raise StoreConflict()
            return existing
        verify_provider_references(prepared.request, baseline)
        self.calls.append((actor_id, prepared, baseline))
        receipt = ContributionReceipt(
            submission_id=prepared.request.submission_id,
            revision_id="a" * 64,
            barcode=prepared.request.barcode,
            content_sha256=prepared.content_sha256,
            factual_sha256=prepared.factual_sha256,
            status="candidate" if prepared.auto_eligible else "provisional",
            submitted_at=NOW,
        )
        self.receipts[(actor_id, prepared.request.submission_id)] = receipt
        return receipt

    def receipt(self, actor_id: str, submission_id: UUID):
        if self.error:
            raise self.error
        return self.receipts.get((actor_id, submission_id))

    def lookup(self, barcode: str):
        if self.error:
            raise self.error
        return CommunityLookup(
            requested_barcode=barcode,
            status="found" if self.revisions else "not_found",
            revisions=self.revisions,
        )


class FakeRuntime:
    def __init__(self):
        self.store = FakeStore()
        self.closed = False
        self.tokens = []

    def verify_token(self, token: str) -> str:
        self.tokens.append(token)
        if token == "invalid":
            raise AuthenticationInvalid()
        if token == "unavailable":
            raise AuthenticationUnavailable()
        return f"private-subject-{token}"

    def close(self):
        self.closed = True


def enabled_client(runtime: FakeRuntime, **changes):
    settings = Settings(
        _env_file=None,
        community_enabled=True,
        community_project_id="unlabel-india-catalogue",
        community_actor_secret=SecretStr("x" * 32),
        **changes,
    )
    return TestClient(
        create_app(
            settings,
            httpx.MockTransport(forbidden),
            community_runtime=cast(CommunityRuntimeProtocol, runtime),
        )
    )


def test_confirmed_facts_are_automatically_submitted_and_receipts_are_owned_and_private():
    runtime = FakeRuntime()
    with enabled_client(runtime) as client:
        meta = client.get("/v1/meta").json()
        assert meta["community"]["status"] == "ready"
        assert meta["capabilities"]["community_contributions"] is True
        response = client.post(
            "/v1/community/contributions",
            json=contribution_dict(),
            headers={"Authorization": "Bearer alice"},
        )
        assert response.status_code == 200
        assert response.json()["status"] == "candidate"
        assert "private-subject" not in response.text
        actor_id = runtime.store.calls[0][0]
        assert len(actor_id) == 64 and actor_id != "private-subject-alice"
        receipt = client.get(
            f"/v1/community/contributions/{SUBMISSION}", headers={"Authorization": "Bearer alice"}
        )
        assert receipt.status_code == 200 and receipt.json() == response.json()
        other = client.get(
            f"/v1/community/contributions/{SUBMISSION}", headers={"Authorization": "Bearer bob"}
        )
        assert other.status_code == 404
        assert "alice" not in other.text and actor_id not in other.text
    assert runtime.closed is True


@pytest.mark.parametrize(
    "header", [None, "Basic alice", "Bearer", "Bearer ", "Bearer invalid", "Bearer alice extra"]
)
def test_write_requires_a_verified_anonymous_token(header):
    runtime = FakeRuntime()
    with enabled_client(runtime) as client:
        response = client.post(
            "/v1/community/contributions",
            json=contribution_dict(),
            headers={} if header is None else {"Authorization": header},
        )
    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"
    assert runtime.store.calls == []


@pytest.mark.parametrize(
    "error,status", [(StoreConflict(), 409), (StoreQuotaExceeded(), 429), (StoreUnavailable(), 503)]
)
def test_store_failures_are_safe_and_do_not_disable_other_endpoints(error, status):
    runtime = FakeRuntime()
    runtime.store.error = error
    with enabled_client(runtime) as client:
        response = client.post(
            "/v1/community/contributions",
            json=contribution_dict(),
            headers={"Authorization": "Bearer alice"},
        )
        assert response.status_code == status
        assert client.get("/v1/health").status_code == 200
        assert client.get("/v1/claims/rules").status_code == 200
    assert "private" not in response.text


def test_authentication_outage_is_not_an_invalid_token_and_never_reaches_store():
    runtime = FakeRuntime()
    with enabled_client(runtime) as client:
        response = client.post(
            "/v1/community/contributions",
            json=contribution_dict(),
            headers={"Authorization": "Bearer unavailable"},
        )
    assert response.status_code == 503
    assert runtime.store.calls == []


def test_public_candidate_lookup_and_resolved_sources_do_not_expose_ownership_or_call_off():
    runtime = FakeRuntime()
    runtime.store.revisions = [candidate_revision()]
    with enabled_client(runtime) as client:
        response = client.get(f"/v1/community/products/{CODE}")
        assert response.status_code == 200
        assert (
            response.json()["revisions"][0]["review_state"]
            == "submitter_confirmed_not_moderator_reviewed"
        )
        resolved = client.get(f"/v1/products/{CODE}/resolved")
        assert resolved.status_code == 200
        assert resolved.json()["community"]["revisions"][0]["facts"]["barcode"] == CODE
        assert resolved.json()["off_snapshot"]["status"] == "unavailable"
        assert "actor_id" not in resolved.text and "private-subject" not in resolved.text
        assert runtime.tokens == []


def test_enabled_missing_credentials_is_unavailable_without_breaking_startup():
    settings = Settings(_env_file=None, community_enabled=True)
    with TestClient(create_app(settings, httpx.MockTransport(forbidden))) as client:
        assert client.get("/v1/meta").json()["community"]["status"] == "unavailable"
        assert client.get(f"/v1/community/products/{CODE}").status_code == 503
        assert client.get("/v1/health").status_code == 200


def test_barcode_less_ocr_observation_is_staged_and_never_appears_in_public_lookup():
    runtime = FakeRuntime()
    body = contribution_dict(
        barcode=None,
        observation_state="provisional",
        capture_method="ocr_unconfirmed",
        confirmed=False,
        front_confirmed=False,
        back_confirmed=False,
        same_product_confirmed=False,
    )
    with enabled_client(runtime) as client:
        response = client.post(
            "/v1/community/contributions", json=body, headers={"Authorization": "Bearer alice"}
        )
        assert response.status_code == 200 and response.json()["status"] == "provisional"
        assert response.json()["barcode"] is None
        assert client.get(f"/v1/community/products/{CODE}").status_code == 404
    assert runtime.store.calls[0][2] is None


def test_provider_reference_requires_actual_available_snapshot_before_storage():
    runtime = FakeRuntime()
    body = contribution_dict(
        provider_references=[
            {
                "provider": "off_snapshot",
                "source_id": "synthetic-catalogue",
                "barcode": CODE,
                "fields": ["identity.name"],
            }
        ]
    )
    with enabled_client(runtime) as client:
        response = client.post(
            "/v1/community/contributions", json=body, headers={"Authorization": "Bearer alice"}
        )
    assert response.status_code == 409
    assert runtime.store.calls == []


def snapshot_fixture():
    path = (
        Path(__file__).resolve().parents[3] / "contracts/examples/catalogue-facts-v1.synthetic.json"
    )
    return FactsLookup.model_validate_json(path.read_text(encoding="utf-8"))


class FakeCatalogue:
    def lookup_facts(self, barcode):
        assert barcode == CODE
        return snapshot_fixture()


def test_exact_snapshot_is_passed_to_storage_for_conflict_and_reference_checks(tmp_path):
    runtime = FakeRuntime()
    with enabled_client(runtime, catalogue_directory=str(tmp_path)) as client:
        cast(FastAPI, client.app).state.catalogue = FakeCatalogue()
        response = client.post(
            "/v1/community/contributions",
            json=contribution_dict(
                provider_references=[
                    {
                        "provider": "off_snapshot",
                        "source_id": "synthetic-catalogue",
                        "barcode": CODE,
                        "fields": ["identity.name"],
                    }
                ]
            ),
            headers={"Authorization": "Bearer alice"},
        )
    assert response.status_code == 200
    assert runtime.store.calls[0][2].manifest.snapshot_id == "synthetic-catalogue"


def test_resolved_preserves_available_snapshot_during_community_outage(tmp_path):
    runtime = FakeRuntime()
    runtime.store.error = StoreUnavailable()
    with enabled_client(runtime, catalogue_directory=str(tmp_path)) as client:
        cast(FastAPI, client.app).state.catalogue = FakeCatalogue()
        response = client.get(f"/v1/products/{CODE}/resolved")
    assert response.status_code == 200
    assert response.json()["off_snapshot"]["status"] == "found"
    assert response.json()["community"]["status"] == "unavailable"


def test_resolved_preserves_snapshot_when_community_is_disabled(tmp_path):
    settings = Settings(_env_file=None, catalogue_directory=str(tmp_path))
    with TestClient(create_app(settings, httpx.MockTransport(forbidden))) as client:
        cast(FastAPI, client.app).state.catalogue = FakeCatalogue()
        response = client.get(f"/v1/products/{CODE}/resolved")
    assert response.status_code == 200
    assert response.json()["off_snapshot"]["status"] == "found"
    assert response.json()["community"]["status"] == "unavailable"


def test_exact_retry_keeps_receipt_when_referenced_snapshot_becomes_unavailable(tmp_path):
    runtime = FakeRuntime()
    body = contribution_dict(
        provider_references=[
            {
                "provider": "off_snapshot",
                "source_id": "synthetic-catalogue",
                "barcode": CODE,
                "fields": ["identity.name"],
            }
        ]
    )
    with enabled_client(runtime, catalogue_directory=str(tmp_path)) as client:
        cast(FastAPI, client.app).state.catalogue = FakeCatalogue()
        first = client.post(
            "/v1/community/contributions", json=body, headers={"Authorization": "Bearer alice"}
        )
        cast(FastAPI, client.app).state.catalogue = None
        retry = client.post(
            "/v1/community/contributions", json=body, headers={"Authorization": "Bearer alice"}
        )
    assert first.status_code == 200 and retry.json() == first.json()
    assert len(runtime.store.calls) == 1


def test_runtime_initialization_and_shutdown_run_off_event_loop_and_report_no_connectivity_proof(
    monkeypatch,
):
    import app.main as main

    runtime = FakeRuntime()
    thread_ids = []
    request_thread = []

    def factory(project_id, database_id, account):
        assert (project_id, database_id, account) == (
            "unlabel-india-catalogue",
            "unlabel",
            "synthetic-account",
        )
        thread_ids.append(threading.get_ident())
        return runtime

    monkeypatch.setattr(main, "create_runtime", factory)
    app = main.create_app(
        Settings(
            _env_file=None,
            community_enabled=True,
            community_project_id="unlabel-india-catalogue",
            community_service_account_json=SecretStr("synthetic-account"),
            community_actor_secret=SecretStr("x" * 32),
        ),
        httpx.MockTransport(forbidden),
    )

    @app.get("/test-event-loop")
    async def event_loop():
        request_thread.append(threading.get_ident())
        return {}

    with TestClient(app) as client:
        client.get("/test-event-loop")
        meta = client.get("/v1/meta").json()["community"]
        assert meta["status"] == "ready" and meta["provider_connectivity"] == "not_checked"
    assert thread_ids[0] != request_thread[0]
    assert runtime.closed is True


def test_invalid_runtime_credentials_fail_closed_without_exposing_provider_errors(monkeypatch):
    import app.main as main

    def unavailable(*args):
        raise AuthenticationUnavailable()

    monkeypatch.setattr(main, "create_runtime", unavailable)
    settings = Settings(
        _env_file=None,
        community_enabled=True,
        community_project_id="unlabel-india-catalogue",
        community_service_account_json=SecretStr("private-invalid-account"),
        community_actor_secret=SecretStr("x" * 32),
    )
    with TestClient(main.create_app(settings, httpx.MockTransport(forbidden))) as client:
        assert client.get("/v1/health").status_code == 200
        response = client.get(f"/v1/community/products/{CODE}")
        assert response.status_code == 503 and "private-invalid-account" not in response.text
        assert client.get("/v1/meta").json()["community"]["status"] == "unavailable"
