"""Private deletion uses synthetic Firestore and verified recent-owner boundaries."""

import copy
import math
from concurrent.futures import ThreadPoolExecutor
from types import SimpleNamespace

import pytest

from app.accounts.store import FirestorePersonalStore, SyncDeleted, owner_hash
from app.community.auth import AuthenticationInvalid, AuthenticationUnavailable, CommunityRuntime
from app.community.store import StoreQuotaExceeded, StoreUnavailable
from tests.integration.test_personal_sync_api import Runtime, headers, make_client
from tests.unit.test_community_store import NOW, MemoryFirestore
from tests.unit.test_personal_sync import data, request

SECRET = "x" * 32


class DeletionRuntime(Runtime):
    def __init__(self):
        super().__init__()
        self.recent_calls = []

    def verify_recent_account_token(self, token):
        self.recent_calls.append(token)
        if token == "provider-outage":
            raise AuthenticationUnavailable()
        if token not in {"scanner-a", "scanner-b"}:
            raise AuthenticationInvalid()
        return token


def seed_private(store, database, uid):
    owner = owner_hash(uid, SECRET)
    store.replace(owner, request(value=data(name="Synthetic " + uid)))
    database.documents["profile_media/" + uid] = {"schema": 1, "avatar_png": b"synthetic"}
    return owner


def test_delete_is_owner_isolated_cleans_private_media_and_limits_and_preserves_public_facts():
    database = MemoryFirestore()
    store = FirestorePersonalStore(database, clock=lambda: NOW)
    owner = seed_private(store, database, "scanner-a")
    other = seed_private(store, database, "scanner-b")
    public = {
        "community_revisions/synthetic-public": {"source": "synthetic-public-fact"},
        "community_receipts/synthetic-public": {"receipt": "synthetic-public-receipt"},
        "unlabel_service_configuration/ai-active": {"slot": "synthetic-slot"},
    }
    database.documents.update(copy.deepcopy(public))
    other_before = copy.deepcopy(database.documents["unlabel_private_accounts/" + other])
    counts_before = {
        key: copy.deepcopy(value)
        for key, value in database.documents.items()
        if key in {"unlabel_private_limits/accounts", "unlabel_private_limits/writes-2026-10-07"}
    }

    store.delete(owner, "scanner-a")

    assert database.documents["unlabel_private_accounts/" + owner] == {
        "schema_version": "1", "deleted": True
    }
    assert database.documents["profile_deletions/scanner-a"] == {"schema": 1}
    assert "profile_media/scanner-a" not in database.documents
    assert "unlabel_private_limits/owner-" + owner not in database.documents
    assert database.documents["unlabel_private_accounts/" + other] == other_before
    assert database.documents["profile_media/scanner-b"]["avatar_png"] == b"synthetic"
    assert "unlabel_private_limits/owner-" + other in database.documents
    assert "profile_deletions/scanner-b" not in database.documents
    for key, value in public.items():
        assert database.documents[key] == value
    for key, value in counts_before.items():
        assert database.documents[key] == value


def test_delete_is_idempotent_and_stale_reads_writes_cannot_restore_the_library():
    database = MemoryFirestore()
    store = FirestorePersonalStore(database, clock=lambda: NOW)
    owner = seed_private(store, database, "scanner-a")
    stale = request(revision=1)
    store.delete(owner, "scanner-a")
    after = copy.deepcopy(database.documents)
    store.delete(owner, "scanner-a")
    assert database.documents == after
    with pytest.raises(SyncDeleted):
        store.read(owner)
    with pytest.raises(SyncDeleted):
        store.replace(owner, stale)
    assert database.documents == after


def test_delete_without_a_snapshot_still_blocks_future_private_uploads():
    database = MemoryFirestore()
    store = FirestorePersonalStore(database, clock=lambda: NOW)
    owner = owner_hash("scanner-a", SECRET)
    store.delete(owner, "scanner-a")
    with pytest.raises(SyncDeleted):
        store.replace(owner, request())
    assert database.documents["profile_deletions/scanner-a"] == {"schema": 1}


def test_completed_deletion_retries_do_not_consume_firestore_writes(monkeypatch):
    database = MemoryFirestore()
    store = FirestorePersonalStore(database, clock=lambda: NOW)
    owner = seed_private(store, database, "scanner-a")
    store.delete(owner, "scanner-a")
    writes = []
    commit = database.commit

    def recording_commit(**kwargs):
        writes.extend(kwargs["request"]["writes"])
        return commit(**kwargs)

    monkeypatch.setattr(database, "commit", recording_commit)
    store.delete(owner, "scanner-a")
    assert writes == []


def test_first_deletion_without_sync_uses_the_existing_lifetime_admission_slot():
    database = MemoryFirestore()
    store = FirestorePersonalStore(database, clock=lambda: NOW)
    owner = owner_hash("scanner-a", SECRET)
    store.delete(owner, "scanner-a")
    assert database.documents["unlabel_private_limits/accounts"] == {"count": 1}
    store.delete(owner, "scanner-a")
    assert database.documents["unlabel_private_limits/accounts"] == {"count": 1}


def test_unadmitted_deletion_cannot_bypass_the_lifetime_document_limit():
    from app.accounts.store import MAX_ACCOUNTS

    database = MemoryFirestore()
    store = FirestorePersonalStore(database, clock=lambda: NOW)
    database.documents["unlabel_private_limits/accounts"] = {"count": MAX_ACCOUNTS}
    before = copy.deepcopy(database.documents)
    with pytest.raises(StoreQuotaExceeded):
        store.delete(owner_hash("scanner-a", SECRET), "scanner-a")
    assert database.documents == before


def test_admitted_account_can_delete_when_sync_admission_and_daily_limits_are_exhausted():
    from app.accounts.store import ACCOUNT_WRITES_PER_DAY, GLOBAL_WRITES_PER_DAY, MAX_ACCOUNTS

    database = MemoryFirestore()
    store = FirestorePersonalStore(database, clock=lambda: NOW)
    owner = seed_private(store, database, "scanner-a")
    database.documents["unlabel_private_limits/accounts"] = {"count": MAX_ACCOUNTS}
    database.documents["unlabel_private_limits/writes-2026-10-07"] = {
        "count": GLOBAL_WRITES_PER_DAY
    }
    database.documents["unlabel_private_limits/owner-" + owner] = {
        "day": "2026-10-07", "count": ACCOUNT_WRITES_PER_DAY
    }
    store.delete(owner, "scanner-a")
    assert "profile_media/scanner-a" not in database.documents
    assert database.documents["unlabel_private_accounts/" + owner] == {
        "schema_version": "1", "deleted": True
    }
    assert database.documents["unlabel_private_limits/accounts"] == {"count": MAX_ACCOUNTS}


def test_delete_racing_a_stale_upload_always_finishes_with_only_tombstones():
    database = MemoryFirestore()
    store = FirestorePersonalStore(database, clock=lambda: NOW)
    owner = seed_private(store, database, "scanner-a")

    def upload():
        try:
            store.replace(owner, request(revision=1, value=data(name="Stale upload")))
        except SyncDeleted:
            pass

    with ThreadPoolExecutor(max_workers=2) as executor:
        upload_future = executor.submit(upload)
        delete_future = executor.submit(store.delete, owner, "scanner-a")
        upload_future.result()
        delete_future.result()
    assert database.documents["unlabel_private_accounts/" + owner] == {
        "schema_version": "1", "deleted": True
    }
    assert "profile_media/scanner-a" not in database.documents
    assert "unlabel_private_limits/owner-" + owner not in database.documents


@pytest.mark.parametrize("failure", ["abort_reads", "abort_commits"])
def test_exhausted_deletion_contention_preserves_the_full_private_account(failure):
    database = MemoryFirestore()
    store = FirestorePersonalStore(database, clock=lambda: NOW)
    owner = seed_private(store, database, "scanner-a")
    before = copy.deepcopy(database.documents)
    setattr(database, failure, 3)
    with pytest.raises(StoreUnavailable):
        store.delete(owner, "scanner-a")
    assert database.documents == before


@pytest.mark.parametrize("uid", ["", "a" * 129, "other/owner", "bad\x00owner", None])
def test_invalid_media_document_identity_fails_before_any_write(uid):
    database = MemoryFirestore()
    store = FirestorePersonalStore(database, clock=lambda: NOW)
    from app.community.store import StoreUnavailable

    with pytest.raises(StoreUnavailable):
        store.delete("a" * 64, uid)
    assert database.documents == {}


def verifier(monkeypatch, provider, authenticated_at):
    from firebase_admin import auth

    import app.community.auth as module

    now = NOW.timestamp()
    monkeypatch.setattr(module, "time", SimpleNamespace(time=lambda: now))
    decoded = {
        "uid": "scanner-a", "sub": "scanner-a", "aud": "unlabel-india-catalogue",
        "iss": "https://securetoken.google.com/unlabel-india-catalogue",
        "exp": now + 3600, "firebase": {"sign_in_provider": provider},
    }
    if authenticated_at != "missing":
        decoded["auth_time"] = authenticated_at
    monkeypatch.setattr(auth, "verify_id_token", lambda *args, **kwargs: decoded)
    return CommunityRuntime(SimpleNamespace(), SimpleNamespace(), "unlabel-india-catalogue")


@pytest.mark.parametrize("provider", ["password", "google.com"])
@pytest.mark.parametrize("age", [0, 299, 300])
def test_recent_account_verifier_accepts_only_supported_recent_nonanonymous_owner(monkeypatch, provider, age):
    runtime = verifier(monkeypatch, provider, NOW.timestamp() - age)
    assert runtime.verify_recent_account_token("opaque-token") == "scanner-a"


@pytest.mark.parametrize("authenticated_at", [
    "missing", None, True, False, "1700000000", [], {},
    NOW.timestamp() - 301, NOW.timestamp() + 1, math.nan, math.inf, -math.inf,
])
def test_recent_account_verifier_rejects_missing_boolean_old_future_and_invalid_claims(monkeypatch, authenticated_at):
    runtime = verifier(monkeypatch, "password", authenticated_at)
    with pytest.raises(AuthenticationInvalid):
        runtime.verify_recent_account_token("opaque-token")


def test_anonymous_session_cannot_delete_even_with_a_recent_auth_time(monkeypatch):
    runtime = verifier(monkeypatch, "anonymous", NOW.timestamp())
    with pytest.raises(AuthenticationInvalid):
        runtime.verify_recent_account_token("opaque-token")


def test_delete_api_uses_recent_verified_uid_and_stale_post_is_rejected():
    runtime = DeletionRuntime()
    owner = seed_private(runtime.personal_store, runtime.database, "scanner-a")
    other = seed_private(runtime.personal_store, runtime.database, "scanner-b")
    with make_client(runtime) as client:
        response = client.delete("/v1/account/sync", headers=headers())
        assert response.status_code == 200
        assert response.json() == {"status": "deleted"}
        assert response.headers["Cache-Control"] == "no-store"
        assert runtime.recent_calls == ["scanner-a"]
        assert "scanner-b" not in response.text and owner not in response.text
        after = copy.deepcopy(runtime.database.documents)
        stale = client.post(
            "/v1/account/sync", headers=headers(),
            json=request(revision=1).model_dump(mode="json"),
        )
        assert stale.status_code == 401
        assert stale.json()["code"] == "account_authentication_required"
        assert runtime.database.documents == after
        assert client.get("/v1/account/sync", headers=headers()).status_code == 401
        assert client.get("/v1/account/sync", headers=headers("scanner-b")).status_code == 200
        assert client.delete("/v1/account/sync", headers=headers()).status_code == 200
        assert runtime.database.documents["unlabel_private_accounts/" + other]["revision"] == 1


def test_first_delete_at_capacity_is_typed_without_partial_private_purge():
    from app.accounts.store import MAX_ACCOUNTS

    runtime = DeletionRuntime()
    runtime.database.documents["unlabel_private_limits/accounts"] = {"count": MAX_ACCOUNTS}
    runtime.database.documents["profile_media/scanner-a"] = {"schema": 1}
    before = copy.deepcopy(runtime.database.documents)
    with make_client(runtime) as client:
        response = client.delete("/v1/account/sync", headers=headers())
    assert response.status_code == 429
    assert response.json()["code"] == "account_sync_limit"
    assert response.headers["Cache-Control"] == "no-store"
    assert runtime.database.documents == before


def test_delete_storage_outage_is_typed_without_claiming_cleanup(monkeypatch):
    runtime = DeletionRuntime()
    seed_private(runtime.personal_store, runtime.database, "scanner-a")
    before = copy.deepcopy(runtime.database.documents)

    def unavailable(owner, uid):
        raise StoreUnavailable()

    monkeypatch.setattr(runtime.personal_store, "delete", unavailable)
    with make_client(runtime) as client:
        response = client.delete("/v1/account/sync", headers=headers())
    assert response.status_code == 503
    assert response.json()["code"] == "account_sync_unavailable"
    assert response.headers["Cache-Control"] == "no-store"
    assert runtime.database.documents == before


@pytest.mark.parametrize("token,status", [
    (None, 401), ("anonymous", 401), ("stale-auth", 401), ("provider-outage", 503),
])
def test_delete_api_rejects_unverified_stale_or_unavailable_auth_without_writes(token, status):
    runtime = DeletionRuntime()
    seed_private(runtime.personal_store, runtime.database, "scanner-a")
    before = copy.deepcopy(runtime.database.documents)
    with make_client(runtime) as client:
        response = client.delete("/v1/account/sync", headers=headers(token) if token else {})
    assert response.status_code == status
    assert response.headers["Cache-Control"] == "no-store"
    assert runtime.database.documents == before
    assert "stale-auth" not in response.text and "provider-outage" not in response.text


@pytest.mark.parametrize("suffix,body", [
    ("?uid=scanner-b", b""), ("?", b"{}"), ("", b"{}"),
    ("", b'{"uid":"scanner-b","private":"synthetic-secret"}'),
])
def test_delete_rejects_query_and_actual_body_before_authentication(suffix, body):
    runtime = DeletionRuntime()
    before = copy.deepcopy(runtime.database.documents)
    with make_client(runtime) as client:
        response = client.request("DELETE", "/v1/account/sync" + suffix, headers=headers(), content=body)
    assert response.status_code == 422
    assert runtime.recent_calls == []
    assert runtime.database.documents == before
    assert "scanner-b" not in response.text and "synthetic-secret" not in response.text


def test_delete_preflight_allows_authorized_frontend_without_authenticating():
    runtime = DeletionRuntime()
    with make_client(runtime, cors_origins=["http://localhost:7357"]) as client:
        response = client.options("/v1/account/sync", headers={
            "Origin": "http://localhost:7357",
            "Access-Control-Request-Method": "DELETE",
            "Access-Control-Request-Headers": "Authorization",
        })
    assert response.status_code == 200
    assert "DELETE" in response.headers["Access-Control-Allow-Methods"]
    assert runtime.recent_calls == []
