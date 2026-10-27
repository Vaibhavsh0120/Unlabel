import asyncio
import json
from datetime import timedelta
from typing import cast

import httpx
import pytest
from fastapi.testclient import TestClient
from pydantic import SecretStr, ValidationError

from app.api.v1.community import CommunityRuntimeProtocol
from app.core.config import Settings
from app.live_products.nutrigraph import (
    MAX_RESPONSE_BYTES,
    NutriGraphLookup,
    normalize,
    supported_upc,
)
from app.main import create_app
from tests.integration.test_community_api import FakeRuntime, forbidden
from tests.unit.test_nutrigraph import CODE, NOW, payload

SECOND_CODE = "012345678905"


def client_for(runtime, respond, **options):
    config = Settings(_env_file=None, **{
        "community_enabled": True,
        "community_actor_secret": SecretStr("synthetic-actor-secret-32characters"),
        "nutrigraph_enabled": True,
        "nutrigraph_api_key": SecretStr("synthetic-vendor-key"),
        **options,
    })
    return TestClient(create_app(
        config, httpx.MockTransport(forbidden),
        community_runtime=cast(CommunityRuntimeProtocol, runtime),
        nutrigraph_transport=httpx.MockTransport(respond),
    ))


def test_disabled_capability_makes_no_provider_or_auth_request():
    runtime = FakeRuntime()
    with client_for(runtime, forbidden, nutrigraph_enabled=False) as client:
        response = client.get(f"/v1/live-products/nutrigraph/{CODE}")
        assert response.status_code == 200
        assert response.json()["status"] == "disabled"
        assert response.headers["cache-control"] == "no-store"
        assert client.get("/v1/meta").json()["capabilities"]["live_nutrigraph"] is False
    assert runtime.tokens == []


@pytest.mark.parametrize("token,status", [(None, 401), ("invalid", 401), ("unavailable", 503)])
def test_endpoint_rejects_failed_auth_before_spending_vendor_quota(token, status):
    with client_for(FakeRuntime(), forbidden) as client:
        response = client.get(f"/v1/live-products/nutrigraph/{CODE}",
                              headers={} if token is None else {"Authorization": f"Bearer {token}"})
        assert response.status_code == status
        assert response.headers["cache-control"] == "no-store"


def test_authenticated_live_response_has_attribution_and_cannot_write_any_store():
    runtime = FakeRuntime()
    requests = []

    def respond(request):
        requests.append(request)
        assert request.url.scheme == "https"
        assert request.url.host == "barcode-api-140543331861.asia-south1.run.app"
        assert request.url.path == "/api/lookup"
        assert dict(request.url.params) == {"barcode": CODE}
        assert request.headers["x-api-key"] == "synthetic-vendor-key"
        assert "authorization" not in request.headers
        assert not request.content
        return httpx.Response(200, json=payload())

    with client_for(runtime, respond) as client:
        for user in ("anonymous-scanner", "password-scanner"):
            response = client.get(f"/v1/live-products/nutrigraph/{CODE}",
                                  headers={"Authorization": f"Bearer {user}"})
            assert response.status_code == 200
            body = response.json()
            assert body["status"] == "found"
            assert body["product"]["attribution"] == "Data by NutriGraphAPI"
            assert body["product"]["attribution_url"] == "https://nutrigraphapi.com"
            assert "synthetic-vendor-key" not in response.text
            assert "private-subject" not in response.text
            assert response.headers["cache-control"] == "no-store"
        assert client.get("/v1/meta").json()["capabilities"]["live_nutrigraph"] is True
    assert len(requests) == 1
    assert runtime.store.calls == [] and runtime.store.receipts == {} and runtime.closed


def test_missing_key_cannot_enable_live_lookup():
    with client_for(FakeRuntime(), forbidden, nutrigraph_api_key=None) as client:
        assert client.get(f"/v1/live-products/nutrigraph/{CODE}").json()["status"] == "disabled"


@pytest.mark.parametrize("value", ["bad key with spaces", "a" * 513, "secret\nheader"])
def test_secrets_are_bounded_and_redacted(value):
    with pytest.raises(ValidationError) as failure:
        Settings(_env_file=None, nutrigraph_api_key=SecretStr(value))
    assert value not in str(failure.value)
    assert "synthetic-vendor-key" not in repr(Settings(
        _env_file=None, nutrigraph_api_key=SecretStr("synthetic-vendor-key")))


@pytest.mark.parametrize("code", ["039978009578", "8901764051258", "039978009579 ", "０39978009579"])
def test_checksum_and_documented_upc_format(code):
    assert not supported_upc(code)
    assert supported_upc(CODE) and supported_upc(SECOND_CODE)


@pytest.mark.asyncio
async def test_monthly_budget_resets_but_cached_results_remain_usable_at_limit():
    clock = [NOW]
    calls = []

    def respond(request):
        calls.append(request)
        body = payload()
        body["analysed_data"]["generalData"]["upc12"] = request.url.params["barcode"]
        return httpx.Response(200, json=body)

    provider = NutriGraphLookup(httpx.AsyncClient(transport=httpx.MockTransport(respond)),
                               "synthetic-key", monthly_limit=1, clock=lambda: clock[0])
    try:
        assert (await provider.lookup(CODE, "actor")).status == "found"
        assert (await provider.lookup(CODE, "actor")).status == "found"
        assert (await provider.lookup(SECOND_CODE, "actor")).status == "rate_limited"
        clock[0] = NOW.replace(month=11, day=1)
        assert (await provider.lookup(SECOND_CODE, "actor")).status == "found"
        assert len(calls) == 2
    finally:
        await provider.close()


@pytest.mark.asyncio
async def test_sandbox_budget_never_renews_at_calendar_month_change():
    clock = [NOW]
    calls = []

    def respond(request):
        calls.append(request)
        return httpx.Response(200, json=payload())

    provider = NutriGraphLookup(
        httpx.AsyncClient(transport=httpx.MockTransport(respond)),
        "synthetic-key", sandbox_limit=1, clock=lambda: clock[0],
    )
    try:
        assert (await provider.lookup(CODE, "actor")).status == "found"
        assert (await provider.lookup(CODE, "actor")).status == "found"
        clock[0] = NOW.replace(month=11, day=1)
        exhausted = await provider.lookup(SECOND_CODE, "actor")
        assert exhausted.status == "rate_limited" and exhausted.retry_after is None
        assert len(calls) == 1
    finally:
        await provider.close()


@pytest.mark.asyncio
async def test_vendor_429_does_not_assume_sandbox_renews_next_month():
    clock = [NOW]
    calls = []

    def respond(request):
        calls.append(request)
        return httpx.Response(429, text="private upstream quota diagnostics")

    provider = NutriGraphLookup(
        httpx.AsyncClient(transport=httpx.MockTransport(respond)),
        "synthetic-key", clock=lambda: clock[0],
    )
    try:
        assert (await provider.lookup(CODE, "actor")).status == "rate_limited"
        clock[0] = NOW.replace(month=11, day=1)
        assert (await provider.lookup(SECOND_CODE, "actor")).status == "rate_limited"
        assert len(calls) == 1
    finally:
        await provider.close()


@pytest.mark.asyncio
@pytest.mark.parametrize("is_json,expected", [(False, "unavailable"), (True, "not_found")])
async def test_endpoint_html_404_is_not_misreported_as_missing_food(is_json, expected):
    def respond(request):
        return (httpx.Response(404, json={"error": "Product not found"}) if is_json
                else httpx.Response(404, text="Generic endpoint not found"))

    provider = NutriGraphLookup(
        httpx.AsyncClient(transport=httpx.MockTransport(respond)), "synthetic-key",
    )
    try:
        assert (await provider.lookup(CODE, "actor")).status == expected
    finally:
        await provider.close()


@pytest.mark.asyncio
async def test_cancelled_waiter_does_not_duplicate_or_cancel_counted_upstream_request():
    entered, release = asyncio.Event(), asyncio.Event()
    calls = []

    async def respond(request):
        calls.append(request)
        entered.set()
        await release.wait()
        return httpx.Response(200, json=payload())

    provider = NutriGraphLookup(httpx.AsyncClient(transport=httpx.MockTransport(respond)), "synthetic-key")
    try:
        first = asyncio.create_task(provider.lookup(CODE, "first"))
        await entered.wait()
        first.cancel()
        with pytest.raises(asyncio.CancelledError):
            await first
        second = asyncio.create_task(provider.lookup(CODE, "second"))
        release.set()
        assert (await second).status == "found" and len(calls) == 1
    finally:
        await provider.close()


@pytest.mark.asyncio
async def test_cache_expiry_uses_original_fetch_time_and_scheduled_memory_removal():
    provider = NutriGraphLookup(httpx.AsyncClient(transport=httpx.MockTransport(forbidden)), "synthetic-key")
    from app.live_products.models import LiveLookup
    product = normalize(payload(), CODE, NOW)
    result = LiveLookup(status="found", requested_barcode=CODE, product=product)
    try:
        provider._put(CODE, result, NOW + timedelta(seconds=5), 86400)
        assert provider._cache[CODE][0] == product.expires_at
        provider._put(CODE, result, NOW, .01)
        await asyncio.sleep(.03)
        assert CODE not in provider._cache
    finally:
        await provider.close()


@pytest.mark.asyncio
@pytest.mark.parametrize("kind", ["size", "json", "nonfinite", "identity", "type", "compression", "timeout"])
async def test_bad_provider_responses_fail_closed_without_echo_or_disk_writes(kind):
    def respond(request):
        if kind == "timeout":
            raise httpx.ReadTimeout("private-token-upstream", request=request)
        if kind == "size":
            return httpx.Response(200, content=b"x" * (MAX_RESPONSE_BYTES + 1),
                                  headers={"Content-Type": "application/json"})
        if kind == "json":
            return httpx.Response(200, content=b"private-invalid-json",
                                  headers={"Content-Type": "application/json"})
        if kind == "type":
            return httpx.Response(200, text=json.dumps(payload()))
        if kind == "compression":
            return httpx.Response(200, content=b"", headers={"Content-Encoding": "br"})
        body = payload()
        if kind == "identity":
            body["analysed_data"]["generalData"]["upc12"] = SECOND_CODE
        else:
            body["analysed_data"]["generalData"]["x"] = float("nan")
        return httpx.Response(200, content=json.dumps(body), headers={"Content-Type": "application/json"})

    provider = NutriGraphLookup(httpx.AsyncClient(transport=httpx.MockTransport(respond)), "synthetic-key")
    try:
        result = await provider.lookup(CODE, "actor")
        assert result.status == "unavailable" and result.product is None
        assert "private" not in result.model_dump_json()
    finally:
        await provider.close()


def test_huge_number_and_partial_ingredient_list_are_not_presented_as_complete():
    body = payload()
    body["analysed_data"]["ingredients"].append({"name": "\ud800"})
    body["analysed_data"]["nutritionalInformation"]["stated"]["macronutrients"][0]["value"] = 10**400
    product = normalize(body, CODE, NOW)
    assert product.fields == ()


def test_provider_provenance_survives_and_qualified_safety_flags_are_never_returned():
    body = payload()
    body["data_source"] = "synthetic root provenance"
    body["analysed_data"]["npiFoodPackagesAllergensIntolerances"] = {
        "eggStated": "Not declared", "eggQualified": "SAFE-FLAG-MUST-NOT-LEAK",
        "source": "synthetic allergy provenance"}
    product = normalize(body, CODE, NOW)
    serialized = product.model_dump_json()
    assert "SAFE-FLAG-MUST-NOT-LEAK" not in serialized
    assert "synthetic root provenance" in serialized
    assert "synthetic allergy provenance" in serialized
