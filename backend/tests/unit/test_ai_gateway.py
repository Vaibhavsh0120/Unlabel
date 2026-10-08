"""Shared SDK transactions prove one sticky AI selection across worker instances."""

import asyncio
import json
from datetime import UTC, datetime, timedelta

import httpx
import pytest
from pydantic import SecretStr

import app.ai.gateway as gateway_module
from app.ai.gateway import AiGateway
from app.ai.providers import ProviderFailure
from app.ai.store import AiSelectionConflict, FirestoreAiSelectionStore
from app.community.store import StoreQuotaExceeded, StoreUnavailable
from app.core.config import Settings
from tests.unit.test_ai_providers import envelope, request
from tests.unit.test_community_store import MemoryFirestore

GEMINI_KEY = "synthetic-gemini-private-api-key"
OPENAI_KEY = "synthetic-openai-private-api-key"
ACTOR = "a" * 64
OTHER_ACTOR = "b" * 64


def ai_config(**changes):
    return Settings(
        **{
            "_env_file": None,
            "ai_enabled": True,
            "gemini_api_key": SecretStr(GEMINI_KEY),
            "openai_api_key": SecretStr(OPENAI_KEY),
            "ai_fallback_credentials_json": None,
            **changes,
        }
    )


def provider_of(incoming):
    return "gemini" if incoming.url.host == "generativelanguage.googleapis.com" else "openai"


@pytest.mark.asyncio
async def test_new_workers_share_one_active_key_until_explicit_manual_switch():
    database = MemoryFirestore()
    calls = []

    def respond(incoming):
        provider = provider_of(incoming)
        calls.append(
            (provider, incoming.headers.get("x-goog-api-key") or incoming.headers["Authorization"])
        )
        return httpx.Response(200, json=envelope(provider))

    async with httpx.AsyncClient(transport=httpx.MockTransport(respond)) as client:
        first = AiGateway(ai_config(), FirestoreAiSelectionStore(database), client)
        second = AiGateway(ai_config(), FirestoreAiSelectionStore(database), client)
        for worker, actor in ((first, ACTOR), (second, OTHER_ACTOR)):
            _, selection = await worker.extract(actor, request())
            assert selection.credential_id == "gemini-primary"
        current = await first.selection()
        changed = first.store.activate(
            "openai-primary", current.revision, "gemini-primary", first.configuration
        )
        assert changed.revision == current.revision + 1
        with pytest.raises(AiSelectionConflict):
            second.store.activate(
                "gemini-primary", current.revision, "gemini-primary", second.configuration
            )
        third = AiGateway(ai_config(), FirestoreAiSelectionStore(database), client)
        for worker in (first, second, third):
            _, selection = await worker.extract(ACTOR, request())
            assert selection.credential_id == "openai-primary"
    assert [provider for provider, _ in calls] == ["gemini", "gemini", "openai", "openai", "openai"]
    assert all(key == GEMINI_KEY for provider, key in calls if provider == "gemini")
    assert all(key == "Bearer " + OPENAI_KEY for provider, key in calls if provider == "openai")
    serialized = repr(database.documents)
    assert GEMINI_KEY not in serialized and OPENAI_KEY not in serialized
    assert "Oats, milk" not in serialized and "data_base64" not in serialized


@pytest.mark.asyncio
@pytest.mark.parametrize("initial,status", [("gemini-primary", 502), ("openai-primary", 401)])
async def test_provider_failure_switches_shared_selection_and_future_workers_stay_on_replacement(
    initial, status
):
    database = MemoryFirestore()
    calls = []
    old = "gemini" if initial == "gemini-primary" else "openai"
    new = "openai" if old == "gemini" else "gemini"

    def respond(incoming):
        provider = provider_of(incoming)
        calls.append(provider)
        return (
            httpx.Response(status, text="private diagnostic")
            if provider == old
            else httpx.Response(200, json=envelope(provider))
        )

    config = ai_config(ai_initial_credential_id=initial)
    async with httpx.AsyncClient(transport=httpx.MockTransport(respond)) as client:
        first = AiGateway(config, FirestoreAiSelectionStore(database), client)
        _, selected = await first.extract(ACTOR, request())
        assert selected.credential_id == new + "-primary"
        second = AiGateway(config, FirestoreAiSelectionStore(database), client)
        await second.extract(OTHER_ACTOR, request())
    assert calls == [old, new, new]
    assert database.documents["unlabel_ai_limits/global"]["count"] == 2


@pytest.mark.asyncio
@pytest.mark.parametrize("mode,expected", [("malformed", "invalid_response"), ("pool", "busy")])
async def test_individual_invalid_output_or_local_queue_saturation_cannot_change_global_key(
    mode, expected
):
    database = MemoryFirestore()
    calls = []

    def respond(incoming):
        calls.append(provider_of(incoming))
        if mode == "pool":
            raise httpx.PoolTimeout("synthetic local overload")
        return httpx.Response(200, json={"not": "the provider contract"})

    async with httpx.AsyncClient(transport=httpx.MockTransport(respond)) as client:
        worker = AiGateway(ai_config(), FirestoreAiSelectionStore(database), client)
        before = await worker.selection()
        with pytest.raises(ProviderFailure) as caught:
            await worker.extract(ACTOR, request())
        assert caught.value.kind == expected
        assert await worker.selection() == before
    assert calls == ["gemini"]


@pytest.mark.asyncio
async def test_stale_inflight_failure_cannot_undo_a_manual_switch():
    database = MemoryFirestore()
    started = asyncio.Event()
    release = asyncio.Event()
    calls = []

    async def respond(incoming):
        provider = provider_of(incoming)
        calls.append(provider)
        if provider == "gemini":
            started.set()
            await release.wait()
            return httpx.Response(502)
        return httpx.Response(200, json=envelope(provider))

    async with httpx.AsyncClient(transport=httpx.MockTransport(respond)) as client:
        worker = AiGateway(ai_config(), FirestoreAiSelectionStore(database), client)
        pending = asyncio.create_task(worker.extract(ACTOR, request()))
        await asyncio.wait_for(started.wait(), timeout=2)
        before = await worker.selection()
        manual = worker.store.activate(
            "openai-primary", before.revision, "gemini-primary", worker.configuration
        )
        release.set()
        _, result = await asyncio.wait_for(pending, timeout=2)
        assert result == manual
        assert await worker.selection() == manual
    assert calls == ["gemini", "openai"]
    assert manual.blocked_until == {}


@pytest.mark.asyncio
async def test_concurrent_failures_have_one_compare_revision_switch_without_key_round_robin():
    database = MemoryFirestore()
    both_started = asyncio.Event()
    release = asyncio.Event()
    calls = []

    async def respond(incoming):
        provider = provider_of(incoming)
        calls.append(provider)
        if provider == "gemini":
            if calls.count("gemini") == 2:
                both_started.set()
            await release.wait()
            return httpx.Response(503)
        return httpx.Response(200, json=envelope(provider))

    async with httpx.AsyncClient(transport=httpx.MockTransport(respond)) as client:
        workers = [
            AiGateway(ai_config(), FirestoreAiSelectionStore(database), client) for _ in range(2)
        ]
        pending = [
            asyncio.create_task(worker.extract(actor, request()))
            for worker, actor in zip(workers, (ACTOR, OTHER_ACTOR), strict=True)
        ]
        await asyncio.wait_for(both_started.wait(), timeout=2)
        release.set()
        results = await asyncio.wait_for(asyncio.gather(*pending), timeout=2)
        assert all(
            selection.credential_id == "openai-primary" and selection.revision == 2
            for _, selection in results
        )
        assert (await workers[0].selection()).revision == 2
    assert calls.count("gemini") == 2 and calls.count("openai") == 2


@pytest.mark.asyncio
async def test_exhausted_cooldowns_fail_closed_then_recover_one_eligible_key_globally(monkeypatch):
    clock = [datetime.now(UTC)]

    class ClockDateTime(datetime):
        @classmethod
        def now(cls, tz=None):
            return clock[0] if tz else clock[0].replace(tzinfo=None)

    monkeypatch.setattr(gateway_module, "datetime", ClockDateTime)
    database = MemoryFirestore()
    store = FirestoreAiSelectionStore(database, clock=lambda: clock[0])
    calls = []

    def respond(incoming):
        provider = provider_of(incoming)
        calls.append(provider)
        if len(calls) == 1:
            return httpx.Response(502)
        if provider == "openai":
            return httpx.Response(401)
        return httpx.Response(200, json=envelope(provider))

    async with httpx.AsyncClient(transport=httpx.MockTransport(respond)) as client:
        worker = AiGateway(ai_config(), store, client)
        with pytest.raises(ProviderFailure) as caught:
            await worker.extract(ACTOR, request())
        assert caught.value.kind == "credential"
        blocked = await worker.selection()
        assert blocked.credential_id == "openai-primary"
        assert set(blocked.blocked_until) == {"gemini-primary", "openai-primary"}
        with pytest.raises(ProviderFailure):
            await worker.extract(ACTOR, request())
        assert calls == ["gemini", "openai"]
        clock[0] += timedelta(seconds=31)
        second = AiGateway(
            ai_config(), FirestoreAiSelectionStore(database, clock=lambda: clock[0]), client
        )
        _, recovered = await second.extract(OTHER_ACTOR, request())
        assert recovered.credential_id == "gemini-primary"
        assert (await worker.selection()).credential_id == "gemini-primary"
        assert recovered.blocked_until["openai-primary"] > clock[0]
    assert calls == ["gemini", "openai", "gemini"]
    assert database.documents["unlabel_ai_limits/global"]["count"] == 2


@pytest.mark.asyncio
async def test_only_two_attempts_per_call_even_with_more_configured_replacements():
    database = MemoryFirestore()
    extra_key = "synthetic-extra-gemini-api-key"
    config = ai_config(
        ai_fallback_credentials_json=SecretStr(
            json.dumps(
                [
                    {
                        "id": "gemini-backup",
                        "provider": "gemini",
                        "api_key": extra_key,
                        "model": "gemini-3.5-flash-lite",
                    }
                ]
            )
        )
    )
    calls = []

    def respond(incoming):
        provider = provider_of(incoming)
        key = incoming.headers.get("x-goog-api-key") or incoming.headers["Authorization"]
        calls.append(key)
        return (
            httpx.Response(200, json=envelope(provider))
            if key == extra_key
            else httpx.Response(502)
        )

    async with httpx.AsyncClient(transport=httpx.MockTransport(respond)) as client:
        worker = AiGateway(config, FirestoreAiSelectionStore(database), client)
        with pytest.raises(ProviderFailure):
            await worker.extract(ACTOR, request())
        assert len(calls) == 2
        assert (await worker.selection()).credential_id == "gemini-backup"
        _, recovered = await worker.extract(OTHER_ACTOR, request())
        assert recovered.credential_id == "gemini-backup"
    assert calls == [GEMINI_KEY, "Bearer " + OPENAI_KEY, extra_key]


@pytest.mark.asyncio
async def test_disabled_failover_blocks_failed_active_key_without_private_replacement():
    database = MemoryFirestore()
    calls = []

    def respond(incoming):
        calls.append(provider_of(incoming))
        return httpx.Response(502)

    async with httpx.AsyncClient(transport=httpx.MockTransport(respond)) as client:
        worker = AiGateway(
            ai_config(ai_failover_enabled=False), FirestoreAiSelectionStore(database), client
        )
        with pytest.raises(ProviderFailure):
            await worker.extract(ACTOR, request())
        assert (await worker.selection()).credential_id == "gemini-primary"
        with pytest.raises(ProviderFailure):
            await worker.extract(OTHER_ACTOR, request())
    assert calls == ["gemini"]


@pytest.mark.asyncio
async def test_configuration_change_requires_manual_activation_and_old_workers_fail_closed():
    database = MemoryFirestore()
    calls = []

    def respond(incoming):
        calls.append(provider_of(incoming))
        return httpx.Response(200, json=envelope(provider_of(incoming)))

    async with httpx.AsyncClient(transport=httpx.MockTransport(respond)) as client:
        old = AiGateway(ai_config(), FirestoreAiSelectionStore(database), client)
        current = await old.selection()
        new = AiGateway(
            ai_config(gemini_api_key=SecretStr("synthetic-rotated-gemini-api-key")),
            FirestoreAiSelectionStore(database),
            client,
        )
        with pytest.raises(StoreUnavailable):
            await new.extract(ACTOR, request())
        assert calls == []
        new.store.activate("gemini-primary", current.revision, "gemini-primary", new.configuration)
        await new.extract(ACTOR, request())
        with pytest.raises(StoreUnavailable):
            await old.extract(OTHER_ACTOR, request())
    assert calls == ["gemini"]


@pytest.mark.asyncio
async def test_admission_is_shared_across_gateway_instances_and_denies_before_provider():
    database = MemoryFirestore()
    calls = []

    def respond(incoming):
        calls.append(provider_of(incoming))
        return httpx.Response(200, json=envelope())

    config = ai_config(ai_daily_request_limit=2, ai_actor_daily_limit=1)
    async with httpx.AsyncClient(transport=httpx.MockTransport(respond)) as client:
        first = AiGateway(config, FirestoreAiSelectionStore(database), client)
        second = AiGateway(config, FirestoreAiSelectionStore(database), client)
        await first.extract(ACTOR, request())
        with pytest.raises(StoreQuotaExceeded):
            await second.extract(ACTOR, request())
        await second.extract(OTHER_ACTOR, request())
        with pytest.raises(StoreQuotaExceeded):
            await first.extract("c" * 64, request())
    assert calls == ["gemini", "gemini"]
    assert database.documents["unlabel_ai_limits/global"]["count"] == 2
