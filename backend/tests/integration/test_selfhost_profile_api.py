"""Owner/profile CAS and gateway boundaries on a disposable PostgreSQL database."""

import base64
import os
import random
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from types import SimpleNamespace
from uuid import uuid4

import httpx
import pytest
from fastapi.testclient import TestClient
from pydantic import SecretStr

psycopg = pytest.importorskip("psycopg")
psycopg_pool = pytest.importorskip("psycopg_pool")
jwt = pytest.importorskip("jwt")
sql = psycopg.sql

from app.accounts.models import PersonalData, SyncRequest  # noqa: E402
from app.accounts.store import SyncConflict, SyncDeleted, owner_hash  # noqa: E402
from app.community.auth import AuthenticationInvalid  # noqa: E402
from app.selfhost import entrypoint  # noqa: E402
from app.selfhost.private_store import PostgresPersonalStore, PostgresProfileStore  # noqa: E402
from app.selfhost.profile import ProfileUpdate  # noqa: E402
from app.selfhost.runtime import IdentityRuntime  # noqa: E402
from tests.unit.test_selfhost_profile import encoded, png  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
ACTOR_SECRET = "synthetic-profile-test-owner-secret"
IDENTITIES = {"alice": uuid4(), "bob": uuid4()}


@pytest.fixture(scope="module")
def database():
    dsn = os.environ.get("UNLABEL_TEST_POSTGRES_ADMIN_DSN")
    if not dsn:
        pytest.skip("Explicit disposable-database connection required")
    name, role = "unlabel_test_profile_" + uuid4().hex, "profile_test_" + uuid4().hex
    with psycopg.connect(dsn, autocommit=True) as admin:
        admin.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(name)))
        try:
            admin.execute(sql.SQL("CREATE ROLE {} NOLOGIN").format(sql.Identifier(role)))
            connection_string = psycopg.conninfo.make_conninfo(dsn, dbname=name)
            with psycopg.connect(connection_string) as connection:
                for migration in sorted((ROOT / "backend/migrations/next_major").glob("*.sql")):
                    # Grants are tested with a unique disposable role, never a production login.
                    source = migration.read_text().replace("TO unlabel_api", "TO " + role)
                    connection.execute(source, prepare=False)

            def configure(connection):
                connection.execute(sql.SQL("SET ROLE {}").format(sql.Identifier(role)))
                connection.commit()

            with psycopg_pool.ConnectionPool(
                connection_string,
                min_size=1,
                max_size=4,
                configure=configure,
                kwargs={"options": "-c statement_timeout=5000 -c lock_timeout=1500"},
            ) as pool:
                yield pool, connection_string
        finally:
            admin.execute(sql.SQL("DROP DATABASE {} WITH (FORCE)").format(sql.Identifier(name)))
            admin.execute(sql.SQL("DROP ROLE IF EXISTS {}").format(sql.Identifier(role)))


@pytest.fixture
def pool(database):
    pool, dsn = database
    with psycopg.connect(dsn) as connection:
        connection.execute("TRUNCATE accounts.users,accounts.deletion_markers CASCADE")
        for identity in IDENTITIES.values():
            connection.execute(
                "INSERT INTO accounts.users(id,auth_subject,owner_hash) VALUES(%s,%s,%s)",
                (identity, identity, owner_hash(str(identity), ACTOR_SECRET)),
            )
    return pool


@pytest.fixture
def app(pool, monkeypatch):
    class Runtime:
        def __init__(self, resources):
            self.personal_store = PostgresPersonalStore(pool, lambda uid: None)
            self.store = self.ai_store = None

        def verify_account_token(self, token):
            if token not in IDENTITIES:
                raise AuthenticationInvalid()
            return str(IDENTITIES[token])

        def close(self):
            pass

    resources = SimpleNamespace(
        pool=pool, research=None, catalogue=None, start=lambda: None, close=lambda: None
    )
    monkeypatch.setattr(entrypoint, "Resources", lambda _: resources)
    monkeypatch.setattr(entrypoint, "IdentityRuntime", Runtime)
    requests = []

    def handler(request):
        requests.append(request)
        if request.url.params.get("token_hash") == "bad-redirect":
            return httpx.Response(302, headers={"Location": "https://malicious.invalid/"})
        if request.url.params.get("token_hash") == "good-redirect":
            return httpx.Response(
                302, headers={"Location": "https://frontend.example/#/account-signin"}
            )
        if request.url.params.get("token_hash") == "oversize":
            return httpx.Response(200, content=b"x" * 262145)
        return httpx.Response(200, json={"status": "ready"})

    settings = SimpleNamespace(
        frontend_url="https://frontend.example",
        identity_url="http://identity.internal:9999",
        actor_secret=SecretStr(ACTOR_SECRET),
        web_push_private_key=None,
        web_push_public_key="",
    )
    application = entrypoint.create_platform_app(
        settings, identity_transport=httpx.MockTransport(handler)
    )
    with TestClient(application) as client:
        yield client, application, requests


def bearer(name="alice"):
    return {"Authorization": "Bearer " + name}


def test_staging_reports_community_unavailable_without_disabling_accounts(app):
    client, _, _ = app
    metadata = client.get("/v1/meta").json()
    assert metadata["capabilities"]["account_sync"] is True
    assert metadata["capabilities"]["community_lookup"] is False
    assert metadata["capabilities"]["community_contributions"] is False
    assert metadata["capabilities"]["ai_extraction"] is False
    assert client.get("/v1/community/products/12345678").status_code == 503
    assert client.get("/v1/account/sync", headers=bearer()).status_code == 200


def test_http_profile_is_owner_scoped_and_cas_conflicts_do_not_leak_data(app):
    client, _, _ = app
    first = client.get("/v1/account/profile", headers=bearer())
    assert first.status_code == 200 and first.json()["revision"] == 0
    result = client.put(
        "/v1/account/profile",
        headers=bearer(),
        json={
            "expected_revision": 0,
            "display_name": "Private Alice",
            "gender": "female",
            "avatar_png_base64": encoded(png()),
        },
    )
    assert result.status_code == 200
    assert result.json()["avatar_source"] == "custom" and result.json()["revision"] == 1
    assert result.headers["cache-control"] == "no-store"
    other = client.get("/v1/account/profile", headers=bearer("bob"))
    assert other.json()["revision"] == 0 and other.json()["display_name"] is None
    stale = client.put("/v1/account/profile", headers=bearer(), json={"expected_revision": 0})
    assert stale.status_code == 409 and stale.json()["current_revision"] == 1
    assert "Private Alice" not in stale.text and "avatar_png_base64" not in stale.text


def test_invalid_sessions_and_guest_tokens_cannot_access_profile(app):
    client, _, _ = app
    for headers in ({}, bearer("guest"), bearer("expired"), {"Authorization": "Basic invalid"}):
        assert client.get("/v1/account/profile", headers=headers).status_code == 401
        assert (
            client.put(
                "/v1/account/profile", headers=headers, json={"expected_revision": 0}
            ).status_code
            == 401
        )


def test_large_valid_avatar_exceeds_old_global_cap_but_succeeds_with_profile_limit(app):
    client, _, _ = app
    noise = random.Random(42)
    rows = []
    for _ in range(192):
        part = noise.randbytes(192 * 2)
        rows.append(b"\0" + part + part)
    image = png(raw=b"".join(rows))
    assert 32768 < len(image) <= 96 * 1024
    result = client.put(
        "/v1/account/profile",
        headers=bearer(),
        json={
            "expected_revision": 0,
            "avatar_png_base64": encoded(image),
        },
    )
    assert result.status_code == 200
    assert base64.b64decode(result.json()["avatar_png_base64"]) == image


def test_profile_rejects_query_body_duplicates_and_secret_values_are_redacted(app):
    client, _, _ = app
    assert client.get("/v1/account/profile?owner=bob", headers=bearer()).status_code == 422
    assert (
        client.request("GET", "/v1/account/profile", headers=bearer(), content=b"{}").status_code
        == 422
    )
    result = client.put(
        "/v1/account/profile",
        headers={**bearer(), "Content-Type": "application/json"},
        content='{"expected_revision":0,"display_name":"secret-one","display_name":"secret-two"}',
    )
    assert result.status_code == 422 and "secret-" not in result.text
    bad = client.put(
        "/v1/account/profile",
        headers=bearer(),
        json={
            "expected_revision": 0,
            "avatar_png_base64": "private-invalid-avatar",
        },
    )
    assert bad.status_code == 422 and "private-invalid-avatar" not in bad.text
    assert (
        client.put(
            "/v1/account/profile", headers=bearer(), content=b"x" * (144 * 1024 + 1)
        ).status_code
        == 413
    )


def test_profile_cas_serializes_competing_writers(pool):
    store = PostgresProfileStore(pool)
    owner = owner_hash(str(IDENTITIES["alice"]), ACTOR_SECRET)

    def write(name):
        try:
            return store.replace(
                owner, ProfileUpdate(expected_revision=0, display_name=name)
            ).revision
        except SyncConflict:
            return "conflict"

    with ThreadPoolExecutor(max_workers=2) as executor:
        results = list(executor.map(write, ["first", "second"]))
    assert sorted(map(str, results)) == ["1", "conflict"]


def test_account_deletion_blocks_profile_and_library_recreation(pool):
    owner = owner_hash(str(IDENTITIES["alice"]), ACTOR_SECRET)
    profile = PostgresProfileStore(pool)
    personal = PostgresPersonalStore(pool, lambda _: None)
    profile.replace(owner, ProfileUpdate(expected_revision=0, display_name="delete-me"))
    personal.delete(owner, str(IDENTITIES["alice"]))
    with pytest.raises(SyncDeleted):
        profile.read(owner)
    with pytest.raises(SyncDeleted):
        profile.replace(owner, ProfileUpdate(expected_revision=0))
    with pytest.raises(SyncDeleted):
        personal.replace(
            owner, SyncRequest(expected_revision=0, mutation_id=uuid4(), data=PersonalData())
        )
    assert profile.read(owner_hash(str(IDENTITIES["bob"]), ACTOR_SECRET)).revision == 0


def test_signed_account_is_checked_upstream_and_cannot_reappear_during_delete(pool):
    issued_at = int(time.time())
    uid = str(uuid4())
    issuer = "https://api.example/auth/v1"
    signing_key = "synthetic-account-signing-secret-for-tests"
    claims = {
        "sub": uid,
        "session_id": str(uuid4()),
        "aud": "authenticated",
        "iss": issuer,
        "iat": issued_at,
        "exp": issued_at + 900,
        "role": "authenticated",
        "is_anonymous": False,
        "amr": [{"method": "password", "timestamp": issued_at}],
    }
    token = jwt.encode(claims, signing_key, algorithm="HS256")
    calls = []
    tombstone_on_check = False

    def identity(request):
        calls.append(request.url.path)
        if tombstone_on_check:
            # Model deletion winning after the first membership check and before
            # account admission. The identity response can still be in flight.
            with pool.connection() as connection:
                connection.execute("DELETE FROM accounts.users WHERE id=%s", (uid,))
                connection.execute(
                    "INSERT INTO accounts.deletion_markers(owner_hash) VALUES(%s)",
                    (owner_hash(uid, ACTOR_SECRET),),
                )
        return httpx.Response(200, json={"id": uid, "is_anonymous": False})

    settings = SimpleNamespace(
        public_url="https://api.example",
        identity_jwt_secret=SecretStr(signing_key),
        actor_secret=SecretStr(ACTOR_SECRET),
    )
    with httpx.Client(
        base_url="http://identity.internal", transport=httpx.MockTransport(identity)
    ) as client:
        runtime = IdentityRuntime(SimpleNamespace(pool=pool, settings=settings, identity=client))
        assert runtime.verify_recent_account_token(token) == uid
        anonymous = jwt.encode(claims | {"is_anonymous": True}, signing_key, algorithm="HS256")
        with pytest.raises(AuthenticationInvalid):
            runtime.verify_account_token(anonymous)
        assert calls == ["/user"]
        tombstone_on_check = True
        with pytest.raises(AuthenticationInvalid):
            runtime.verify_account_token(token)
        assert calls == ["/user", "/user"]
        assert runtime.verify_recent_account_token(token) == uid  # Permit deletion retry only.
        assert calls == ["/user", "/user"]
    with pool.connection() as connection:
        assert (
            connection.execute("SELECT id FROM accounts.users WHERE id=%s", (uid,)).fetchone()
            is None
        )


def test_gateway_reuses_one_lifespan_client_and_limits_paths_queries_redirects(app):
    client, application, requests = app
    pooled = application.state.identity_client
    assert client.get("/auth/v1/health").status_code == 200
    assert client.get("/auth/v1/settings").status_code == 200
    assert application.state.identity_client is pooled and not pooled.is_closed
    before = len(requests)
    for route in [
        "/auth/v1/admin/users",
        "/auth/v1/verify?redirect_to=https://malicious.invalid/",
        "/auth/v1/token?grant_type=password&grant_type=refresh_token",
    ]:
        assert client.get(route).status_code in {404, 405, 422}
    assert client.delete("/auth/v1/signup").status_code == 405
    assert len(requests) == before
    assert (
        client.get("/auth/v1/verify?token_hash=bad-redirect", follow_redirects=False).status_code
        == 502
    )
    good = client.get("/auth/v1/verify?token_hash=good-redirect", follow_redirects=False)
    assert good.status_code == 302 and good.headers["location"].startswith(
        "https://frontend.example/"
    )
    assert client.get("/auth/v1/verify?token_hash=oversize").status_code == 502
    duplicate = client.post(
        "/auth/v1/signup",
        headers={"Content-Type": "application/json"},
        content='{"email":"private-one","email":"private-two"}',
    )
    assert duplicate.status_code == 422 and "private-" not in duplicate.text


def test_gateway_json_body_and_cap_are_checked_before_upstream(app):
    client, _, requests = app
    before = len(requests)
    assert client.post("/auth/v1/signup", content=b"x" * (128 * 1024 + 1)).status_code == 413
    assert (
        client.post(
            "/auth/v1/signup", json={"redirect_to": "https://malicious.invalid/"}
        ).status_code
        == 422
    )
    assert (
        client.post(
            "/auth/v1/signup", content=b"plaintext", headers={"Content-Type": "text/plain"}
        ).status_code
        == 415
    )
    assert len(requests) == before
