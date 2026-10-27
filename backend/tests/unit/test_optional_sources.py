import httpx
import pytest
from fastapi.testclient import TestClient

from app.ai.configuration import credentials
from app.ai.gateway import AiGateway
from app.core.config import Settings
from app.main import create_app
from app.providers.products.open_food_facts import OpenFoodFactsProvider
from tests.integration.test_ai_api import CONTROL_HEADERS, AiRuntime, client_for


def settings(**values):
    return Settings(
        _env_file=None,
        gemini_api_key=None,
        openai_api_key=None,
        nutrigraph_api_key=None,
        ai_fallback_credentials_json=None,
        **values,
    )


def test_no_credentials_disable_keyed_sources_while_service_still_starts():
    config = settings()
    assert config.ai_enabled is False
    assert config.nutrigraph_enabled is False
    with TestClient(create_app(config)) as client:
        assert client.get("/v1/health").status_code == 200
        meta = client.get("/v1/meta").json()
        assert meta["capabilities"]["ai_extraction"] is False
        assert meta["capabilities"]["live_nutrigraph"] is False
    assert Settings(_env_file=None, ai_fallback_credentials_json='[]').ai_enabled is False


def test_keys_auto_enable_and_explicit_off_wins():
    config = Settings(
        _env_file=None,
        openai_api_key="synthetic-openai-private-key",
        nutrigraph_api_key="synthetic-nutrigraph-key",
    )
    assert config.ai_enabled is True
    assert config.nutrigraph_enabled is True
    disabled = config.model_copy(update={"ai_enabled": False, "nutrigraph_enabled": False})
    assert disabled.ai_enabled is False and disabled.nutrigraph_enabled is False
    assert Settings(_env_file=None, ai_enabled=True).ai_enabled is False
    assert Settings(_env_file=None, nutrigraph_enabled=True).nutrigraph_enabled is False


@pytest.mark.asyncio
async def test_openai_only_clone_selects_available_slot_and_provider_can_be_disabled():
    config = Settings(_env_file=None, openai_api_key="synthetic-openai-private-key")
    async with httpx.AsyncClient() as client:
        gateway = AiGateway(config, object(), client)
        assert gateway.initial_credential_id == "openai-primary"
    disabled = Settings(
        _env_file=None, openai_api_key="synthetic-openai-private-key", openai_enabled=False
    )
    assert credentials(disabled) == ()
    assert disabled.ai_enabled is False


def test_auto_activation_passes_a_configured_initial_slot_to_shared_store(monkeypatch):
    runtime = AiRuntime()
    activate = runtime.ai_store.activate
    observed = []

    def checked_activate(credential_id, revision, initial, configuration):
        observed.append(initial)
        return activate(credential_id, revision, initial, configuration)

    monkeypatch.setattr(runtime.ai_store, "activate", checked_activate)
    with client_for(runtime, ai_initial_credential_id="auto") as client:
        response = client.post(
            "/v1/ai/control/activate",
            json={"credential_id": "openai-primary", "expected_revision": 1},
            headers=CONTROL_HEADERS,
        )
        assert response.status_code == 200
    assert observed == ["gemini-primary"]


@pytest.mark.asyncio
async def test_off_switch_makes_no_upstream_request():
    def forbidden(request):
        raise AssertionError("Disabled OFF source must not make network requests")

    async with httpx.AsyncClient(transport=httpx.MockTransport(forbidden)) as client:
        result, raw = await OpenFoodFactsProvider(client, settings(off_enabled=False)).read_product(
            "8901058000306"
        )
        assert result.status == "unavailable" and raw is None


def test_all_local_sources_can_be_disabled_without_deleting_their_data():
    config = settings(
        catalogue_enabled=False,
        research_catalogue_enabled=False,
        claims_enabled=False,
        glossary_enabled=False,
        off_enabled=False,
    )
    with TestClient(create_app(config)) as client:
        meta = client.get("/v1/meta").json()
        assert meta["capabilities"]["catalogue_lookup"] is False
        assert meta["capabilities"]["research_catalogue"] is False
        assert meta["capabilities"]["product_lookup"] is False
        assert meta["knowledge_version"] == "not_populated"
        assert meta["glossary"]["status"] == "unavailable"
        assert client.get("/v1/health").status_code == 200
