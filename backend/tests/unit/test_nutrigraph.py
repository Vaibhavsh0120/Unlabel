import asyncio
from datetime import UTC, datetime, timedelta

import httpx
import pytest

from app.live_products.nutrigraph import NutriGraphLookup, normalize

CODE = '039978009579'
NOW = datetime(2026, 10, 15, tzinfo=UTC)


def payload():
    return {'analysed_data': {'generalData': {'upc12': CODE, 'brandName': 'Synthetic'},
        'ingredients': [{'name': 'Oats', 'source': 'synthetic package'}],
        'nutritionalInformation': {'stated': {'macronutrients': [
            {'name': 'sugars', 'unit': 'g', 'value': 2, 'source': 'synthetic package'}]},
            'qualified': {'macronutrients': [{'name': 'protein', 'value': 99, 'unit': 'g'}]}}}}


def test_only_exact_identity_and_stated_fields_are_exposed():
    product = normalize(payload(), CODE, NOW)
    assert product.evidence == 'external_provider_unverified'
    assert [field.section for field in product.fields] == ['ingredients', 'nutrition']
    assert product.expires_at - product.retrieved_at == timedelta(hours=24)
    assert all(field.value != '99 g' for field in product.fields)
    with pytest.raises(ValueError):
        normalize(payload(), '012345678905', NOW)


@pytest.mark.asyncio
async def test_live_cache_coalesces_expires_and_never_follows_redirects():
    calls = []
    clock = [NOW]
    async def respond(request):
        calls.append(request)
        assert request.headers['X-API-Key'] == 'synthetic-key'
        await asyncio.sleep(.01)
        return httpx.Response(200, json=payload())
    provider = NutriGraphLookup(httpx.AsyncClient(transport=httpx.MockTransport(respond)),
        'synthetic-key', clock=lambda: clock[0])
    try:
        results = await asyncio.gather(*(provider.lookup(CODE, 'actor') for _ in range(3)))
        assert all(result.status == 'found' for result in results)
        assert len(calls) == 1
        clock[0] += timedelta(hours=24, seconds=1)
        assert (await provider.lookup(CODE, 'actor')).status == 'found'
        assert len(calls) == 2
        assert (await provider.lookup('8901764051258', 'actor')).status == 'unsupported_barcode'
        assert len(calls) == 2
    finally:
        await provider.close()
    assert not provider._cache and not provider._pending


@pytest.mark.asyncio
@pytest.mark.parametrize('status', [302, 401, 404, 429, 500])
async def test_vendor_failures_are_bounded_and_do_not_expose_secrets(status):
    calls = []
    def respond(request):
        calls.append(request)
        return httpx.Response(status, text='secret internal body',
            headers={'location': 'https://untrusted.invalid'})
    provider = NutriGraphLookup(httpx.AsyncClient(transport=httpx.MockTransport(respond)), 'synthetic-key')
    try:
        first = await provider.lookup(CODE, 'actor')
        second = await provider.lookup(CODE, 'actor')
        assert first.status == second.status
        assert len(calls) == 1 and 'secret' not in first.model_dump_json()
    finally:
        await provider.close()
