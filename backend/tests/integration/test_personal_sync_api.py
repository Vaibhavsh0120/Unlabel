import copy
import json
from typing import cast

import httpx
import pytest
from fastapi.testclient import TestClient
from pydantic import SecretStr

from app.accounts.models import SyncSnapshot
from app.accounts.store import FirestorePersonalStore
from app.api.v1.community import CommunityRuntimeProtocol
from app.community.auth import AuthenticationInvalid, AuthenticationUnavailable
from app.community.store import FirestoreContributionStore, StoreUnavailable
from app.core.config import Settings
from app.main import create_app
from tests.unit.test_community_store import NOW, MemoryFirestore
from tests.unit.test_personal_sync import data, request


class Runtime:
    def __init__(self):
        self.database = MemoryFirestore()
        self.store = FirestoreContributionStore(self.database)
        self.personal_store = FirestorePersonalStore(self.database, clock=lambda: NOW)
        self.calls = []

    def verify_account_token(self, token):
        self.calls.append(token)
        if token == "provider-outage":
            raise AuthenticationUnavailable()
        if token not in {"scanner-a", "scanner-b"}:
            raise AuthenticationInvalid()
        return token

    def verify_token(self, token):
        return "anonymous-scanner" if token == "anonymous" else self.verify_account_token(token)

    def close(self):
        pass


def forbidden(_):
    pytest.fail("Personal sync must not call live product providers")


def make_client(runtime=None, enabled=True):
    config = Settings(
        _env_file=None,
        community_enabled=runtime is not None,
        community_actor_secret=SecretStr("x" * 32),
        account_sync_enabled=enabled,
    )
    return TestClient(
        create_app(config, httpx.MockTransport(forbidden), cast(CommunityRuntimeProtocol, runtime))
    )


def headers(token="scanner-a"):
    return {"Authorization": "Bearer " + token}


def test_guest_and_disabled_mode_are_typed_without_affecting_product_features():
    runtime = Runtime()
    with make_client(runtime, enabled=False) as client:
        assert client.get("/v1/account/sync", headers=headers()).status_code == 503
        assert client.get("/v1/meta").json()["capabilities"]["account_sync"] is False
        assert client.get("/v1/health").status_code == 200
        assert client.get("/v1/claims/rules").status_code == 200
    assert runtime.calls == []
    with make_client() as client:
        assert client.get("/v1/account/sync").status_code == 503
        assert client.get("/v1/meta").json()["account_sync"]["status"] == "unavailable"


@pytest.mark.parametrize(
    "authorization",
    [None, "Bearer anonymous", "Bearer invalid", "Basic scanner-a", "Bearer scanner-a extra"],
)
def test_personal_routes_require_only_verified_nonanonymous_scanner(authorization):
    runtime = Runtime()
    with make_client(runtime) as client:
        supplied = {"Authorization": authorization} if authorization else {}
        for response in (
            client.get("/v1/account/sync", headers=supplied),
            client.post(
                "/v1/account/sync", headers=supplied, json=request().model_dump(mode="json")
            ),
        ):
            assert response.status_code == 401
            assert response.headers["www-authenticate"] == "Bearer"
            assert response.headers["cache-control"] == "no-store"
            assert response.json()["code"] == "account_authentication_required"
    assert runtime.database.documents == {}


def test_optional_sync_roundtrip_owner_isolation_idempotency_and_cas_conflict():
    runtime = Runtime()
    with make_client(runtime) as client:
        meta = client.get("/v1/meta").json()
        assert meta["account_sync"]["status"] == "ready"
        assert meta["account_sync"]["max_snapshot_bytes"] == 384 * 1024
        empty = client.get("/v1/account/sync", headers=headers())
        assert empty.status_code == 200 and empty.json()["revision"] == 0
        body = request().model_dump(mode="json")
        response = client.post("/v1/account/sync", json=body, headers=headers())
        assert response.status_code == 200 and response.json()["revision"] == 1
        SyncSnapshot.model_validate(response.json())
        assert (
            client.post("/v1/account/sync", json=body, headers=headers()).json() == response.json()
        )
        other = client.get("/v1/account/sync", headers=headers("scanner-b"))
        assert other.json()["revision"] == 0 and other.json()["data"]["saved"] == []
        conflict = client.post(
            "/v1/account/sync", json=request().model_dump(mode="json"), headers=headers()
        )
        assert conflict.status_code == 409
        assert conflict.json() == {
            "schema_version": "1",
            "status": "conflict",
            "code": "account_revision_conflict",
            "current_revision": 1,
        }
        assert "Synthetic scanner" not in conflict.text
        assert "scanner-a" not in json.dumps(runtime.database.documents, default=str)


@pytest.mark.parametrize("method,body", [("GET", None), ("POST", {})])
def test_private_query_parameters_do_not_select_owners_or_echo_secrets(method, body):
    runtime = Runtime()
    with make_client(runtime) as client:
        response = client.request(
            method, "/v1/account/sync?uid=SECRET-OTHER-OWNER", json=body, headers=headers()
        )
        assert response.status_code == 422 and "SECRET" not in response.text
        assert response.headers["cache-control"] == "no-store"
    assert runtime.calls == []


def test_private_get_body_and_unmodeled_private_post_values_are_rejected_redacted():
    runtime = Runtime()
    with make_client(runtime) as client:
        response = client.request(
            "GET", "/v1/account/sync", json={"SECRET-UID": "SECRET"}, headers=headers()
        )
        assert response.status_code == 422 and "SECRET" not in response.text
        body = request().model_dump(mode="json")
        body["data"]["SECRET-UID"] = "SECRET-private"
        response = client.post("/v1/account/sync", json=body, headers=headers())
        assert response.status_code == 422 and "SECRET" not in response.text
        body = request().model_dump(mode="json")
        body["data"]["saved"][0]["report"]["SECRET-METADATA"] = "SECRET-private"
        response = client.post("/v1/account/sync", json=body, headers=headers())
        assert response.status_code == 422 and "SECRET" not in response.text


def test_account_body_cap_is_bounded_on_actual_chunks_other_routes_remain_32kib():
    runtime = Runtime()
    with make_client(runtime) as client:
        for value in (b"x" * (512 * 1024 + 1), iter([b"x" * 300000, b"x" * 300000])):
            response = client.post("/v1/account/sync", content=value, headers=headers())
            assert response.status_code == 413 and "512 KiB" in response.text
        value = request(value=data(count=10)).model_dump(mode="json")
        assert len(json.dumps(value).encode()) > 32768
        assert client.post("/v1/account/sync", json=value, headers=headers()).status_code == 200
        response = client.post("/v1/reports/check", content=b"x" * 32769)
        assert response.status_code == 413 and "32 KiB" in response.text


@pytest.mark.parametrize("number", ["NaN", "Infinity", "1e-9999", "1e9999"])
def test_private_invalid_json_numbers_are_redacted(number):
    with make_client(Runtime()) as client:
        response = client.post(
            "/v1/account/sync",
            content='{"SECRET":' + number + "}",
            headers=headers() | {"Content-Type": "application/json"},
        )
        assert response.status_code == 422 and "SECRET" not in response.text


def test_account_storage_and_auth_outages_are_safe_and_failures_do_not_modify_data(monkeypatch):
    runtime = Runtime()
    with make_client(runtime) as client:
        assert client.get("/v1/account/sync", headers=headers("provider-outage")).status_code == 503
        before = copy.deepcopy(runtime.database.documents)

        def broken(_):
            raise StoreUnavailable()

        monkeypatch.setattr(runtime.personal_store, "read", broken)
        response = client.get("/v1/account/sync", headers=headers())
        assert response.status_code == 503
        assert runtime.database.documents == before


def test_transactional_admission_returns_typed_429_without_partial_account_creation():
    from app.accounts.store import MAX_ACCOUNTS

    runtime = Runtime()
    runtime.database.documents["unlabel_private_limits/accounts"] = {"count": MAX_ACCOUNTS}
    before = copy.deepcopy(runtime.database.documents)
    with make_client(runtime) as client:
        response = client.post(
            "/v1/account/sync", json=request().model_dump(mode="json"), headers=headers()
        )
    assert response.status_code == 429
    assert response.json()["code"] == "account_sync_limit"
    assert runtime.database.documents == before


def test_new_openapi_is_additive_and_existing_response_components_unchanged():
    from pathlib import Path

    from app.accounts.models import SyncFailure, SyncRequest, SyncSnapshot

    old = json.loads(
        (
            Path(__file__).resolve().parents[3] / "contracts/schemas/backend-v0.6.0.openapi.json"
        ).read_text()
    )
    with make_client() as client:
        current = client.get("/openapi.json").json()
    assert len(current["paths"]) == 21
    for name, path in old["paths"].items():
        assert current["paths"][name] == path
    for name, schema in old["components"]["schemas"].items():
        assert current["components"]["schemas"][name] == schema
    for model in (SyncRequest, SyncSnapshot, SyncFailure):
        assert model.__name__ in current["components"]["schemas"]
