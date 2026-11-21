from types import SimpleNamespace

import httpx
import pytest
from app.selfhost import entrypoint
from app.selfhost.resources import PlatformSettings
from fastapi import FastAPI
from fastapi.testclient import TestClient
from pydantic import SecretStr


def platform_app(monkeypatch, cutover_ready=False, transport=None):
    class Resources:
        def __init__(self, _settings):
            self.pool = object()

        def start(self):
            pass

        def close(self):
            pass

    monkeypatch.setattr(entrypoint, "Resources", Resources)
    monkeypatch.setattr(entrypoint, "IdentityRuntime", lambda _resources: object())
    monkeypatch.setattr(
        entrypoint, "PostgresProfileStore", lambda _pool: object()
    )
    monkeypatch.setattr(
        entrypoint,
        "create_app",
        lambda *_args, **_kwargs: FastAPI(),
    )
    settings = SimpleNamespace(
        identity_url="https://identity.example.test",
        frontend_url="https://frontend.example.test",
        actor_secret=SecretStr("s" * 32),
        web_push_private_key=None,
        web_push_public_key="",
        community_enabled=False,
        cutover_ready=cutover_ready,
    )
    return entrypoint.create_platform_app(settings, identity_transport=transport)


def test_platform_metadata_defaults_to_staging(monkeypatch):
    assert PlatformSettings.model_fields["cutover_ready"].default is False
    with TestClient(platform_app(monkeypatch, False)) as client:
        response = client.get("/v1/platform")

    assert response.status_code == 200
    assert response.json()["cutover_ready"] is False
    assert response.json()["release_channel"] == "next_major_staging"


def test_platform_metadata_reports_production_only_after_explicit_enable(monkeypatch):
    with TestClient(platform_app(monkeypatch, True)) as client:
        response = client.get("/v1/platform")

    assert response.status_code == 200
    assert response.json()["cutover_ready"] is True
    assert response.json()["release_channel"] == "production"


def oauth_query(**overrides):
    return {
        "provider": "google", "redirect_to": "https://frontend.example.test/auth-callback.html",
        "code_challenge": "a" * 43, "code_challenge_method": "s256", **overrides,
    }


def test_new_email_signup_sends_welcome_without_delaying_account_activation(monkeypatch):
    sent = []
    monkeypatch.setattr(entrypoint, "send_welcome", lambda settings, email: sent.append(email), raising=False)
    transport = httpx.MockTransport(lambda _: httpx.Response(200, json={
        "access_token": "synthetic", "user": {"email": "scanner@example.test", "is_anonymous": False}
    }))
    with TestClient(platform_app(monkeypatch, transport=transport)) as client:
        result = client.post("/auth/v1/signup", json={"email": "scanner@example.test", "password": "synthetic"})
    assert result.status_code == 200
    assert result.json()["access_token"] == "synthetic"
    assert sent == ["scanner@example.test"]


def test_guest_and_failed_signups_do_not_send_welcome(monkeypatch):
    sent = []
    monkeypatch.setattr(entrypoint, "send_welcome", lambda settings, email: sent.append(email), raising=False)
    for status, payload in [(200, {"access_token": "guest", "user": {"is_anonymous": True}}),
                            (422, {"error": "user_already_exists"})]:
        transport = httpx.MockTransport(lambda _, s=status, p=payload: httpx.Response(s, json=p))
        with TestClient(platform_app(monkeypatch, transport=transport)) as client:
            client.post("/auth/v1/signup", json={})
    assert sent == []


def test_google_authorization_and_callback_reach_identity_without_exposing_admin(monkeypatch):
    requests = []

    def upstream(request):
        requests.append(request)
        location = ("https://accounts.google.com/o/oauth2/v2/auth?state=signed"
                    if request.url.path == "/authorize"
                    else "https://frontend.example.test/auth-callback.html?code=one-time")
        return httpx.Response(302, headers={"Location": location})

    with TestClient(platform_app(monkeypatch, transport=httpx.MockTransport(upstream))) as client:
        result = client.get("/auth/v1/authorize", params=oauth_query(), follow_redirects=False)
        assert result.status_code == 302
        assert result.headers["location"].startswith("https://accounts.google.com/")
        result = client.get("/auth/v1/callback?code=google-code&state=signed&scope=email&authuser=0&prompt=none",
                            follow_redirects=False)
        assert result.status_code == 302
        assert result.headers["location"].startswith("https://frontend.example.test/")
        assert result.headers["cache-control"] == "no-store"
        assert client.get("/auth/v1/admin/users").status_code == 404
    assert [request.url.path for request in requests] == ["/authorize", "/callback"]


@pytest.mark.parametrize("overrides", [
    {"provider": "github"}, {"code_challenge_method": "plain"},
    {"code_challenge": "short"}, {"redirect_to": "https://malicious.invalid/"},
])
def test_google_authorization_requires_pkce_and_approved_return(monkeypatch, overrides):
    def upstream(_):
        pytest.fail("Rejected authorization must not reach the identity service")

    with TestClient(platform_app(monkeypatch, transport=httpx.MockTransport(upstream))) as client:
        assert client.get("/auth/v1/authorize", params=oauth_query(**overrides)).status_code == 422


@pytest.mark.parametrize("path,location", [
    ("authorize", "https://accounts.google.com.evil.invalid/o/oauth2/v2/auth"),
    ("authorize", "https://accounts.google.com/unknown"),
    ("callback", "https://accounts.google.com/o/oauth2/v2/auth"),
    ("callback", "https://malicious.invalid/"),
])
def test_identity_redirects_cannot_escape_the_expected_flow(monkeypatch, path, location):
    transport = httpx.MockTransport(lambda _: httpx.Response(302, headers={"Location": location}))
    with TestClient(platform_app(monkeypatch, transport=transport)) as client:
        params = oauth_query() if path == "authorize" else {"code": "code", "state": "state"}
        result = client.get("/auth/v1/" + path, params=params, follow_redirects=False)
        assert result.status_code == 502


def test_explicit_google_link_forwards_only_owner_bearer_and_pkce(monkeypatch):
    calls = []

    def upstream(request):
        calls.append(request)
        return httpx.Response(200, json={"url": "https://accounts.google.com/o/oauth2/v2/auth"})

    with TestClient(platform_app(monkeypatch, transport=httpx.MockTransport(upstream))) as client:
        result = client.get("/auth/v1/user/identities/authorize",
                            params=oauth_query(skip_http_redirect="true"),
                            headers={"Authorization": "Bearer synthetic-owner", "Cookie": "never-forward"})
        assert result.status_code == 200
    assert calls[0].headers["authorization"] == "Bearer synthetic-owner"
    assert "cookie" not in calls[0].headers
