from types import SimpleNamespace

from app.selfhost import entrypoint
from app.selfhost.resources import PlatformSettings
from fastapi import FastAPI
from fastapi.testclient import TestClient
from pydantic import SecretStr


def platform_app(monkeypatch, cutover_ready):
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
    return entrypoint.create_platform_app(settings)


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
