"""Synthetic provider readings through actual admission and catalogue lookup."""

import copy

from tests.integration.test_ai_api import SCANNER_HEADERS, AiRuntime, body, client_for
from tests.unit.test_catalogue_facts import build, raw_product

CODE = '8901764051258'


def catalogue(tmp_path):
    return build(tmp_path, [raw_product(code=CODE, brands='Synthetic brand', quantity='300 g')])[0]


def test_extraction_automatically_shares_with_terms_then_public_read_has_no_private_data(tmp_path):
    runtime = AiRuntime()
    with client_for(runtime) as client:
        client.app.state.catalogue = catalogue(tmp_path)
        client.app.state.research_catalogue = None
        request = {**body(), 'catalogue_contribution': 'machine-unverified-v1'}
        first = client.post('/v1/ai/extract', json=request, headers=SCANNER_HEADERS)
        assert first.status_code == 200
        receipt = first.json()['contribution']
        assert receipt['status'] == 'shared_unverified'
        repeated = client.post('/v1/ai/extract', json=request, headers=SCANNER_HEADERS)
        assert repeated.json()['contribution']['deduplicated']
        result = client.get(f'/v1/ai/observations/{CODE}')
        assert result.status_code == 200 and result.headers['cache-control'] == 'no-store'
        observation = result.json()['observations'][0]
        assert observation['observation_id'] == receipt['observation_id']
        assert observation['evidence'] == 'machine_extracted_unverified'
        assert observation['facts']['ingredients'] == 'Oats, milk'
        assert result.json()['conflict_fields'] == []
        for value in ('private-subject', 'alice', 'owner', 'data_base64', 'regions', 'confirmed":true'):
            assert value not in result.text
        assert not runtime.store.calls and not runtime.store.receipts


def test_source_changes_are_rechecked_and_old_machine_records_never_rewritten(tmp_path):
    runtime = AiRuntime()
    with client_for(runtime) as client:
        client.app.state.catalogue = catalogue(tmp_path)
        client.app.state.research_catalogue = None
        request = {**body(), 'catalogue_contribution': 'machine-unverified-v1'}
        assert client.post('/v1/ai/extract', json=request, headers=SCANNER_HEADERS).json()['contribution']['status'] == 'shared_unverified'
        before = copy.deepcopy(runtime.database.documents)
        replacement = tmp_path / 'replacement'
        replacement.mkdir()
        client.app.state.catalogue = build(replacement, [raw_product(code=CODE,
            brands='Synthetic brand', quantity='600 g', ingredients_text='Oats, peanuts')])[0]
        result = client.get(f'/v1/ai/observations/{CODE}')
        assert result.status_code == 200
        assert set(result.json()['conflict_fields']) == {'identity', 'ingredients'}
        assert before == runtime.database.documents
        second = client.post('/v1/ai/extract', json=request, headers=SCANNER_HEADERS)
        assert second.json()['contribution']['reason'] == 'identity_conflict'


def test_unknown_identity_and_corrupt_storage_do_not_break_useful_reading(tmp_path):
    runtime = AiRuntime()
    with client_for(runtime) as client:
        client.app.state.catalogue = None
        client.app.state.research_catalogue = None
        request = {**body(), 'catalogue_contribution': 'machine-unverified-v1'}
        result = client.post('/v1/ai/extract', json=request, headers=SCANNER_HEADERS)
        assert result.status_code == 200
        assert result.json()['contribution']['reason'] == 'identity_unmatched'
        assert client.get(f'/v1/ai/observations/{CODE}').json()['status'] == 'not_found'
        client.app.state.catalogue = catalogue(tmp_path)
        runtime.database.documents[f'unlabel_machine_products/{CODE}'] = {
            'schema_version': '1', 'barcode': CODE, 'observations': [{}],
        }
        result = client.post('/v1/ai/extract', json=request, headers=SCANNER_HEADERS)
        assert result.status_code == 200 and result.json()['extraction']['ingredients'] == 'Oats, milk'
        assert result.json()['contribution']['reason'] == 'unavailable'
        assert client.get(f'/v1/ai/observations/{CODE}').status_code == 503


def test_client_cannot_supply_claimed_machine_facts_or_human_confirmation():
    with client_for() as client:
        for extra in ({'extraction': {'ingredients': 'Injected facts'}}, {'confirmed': True},
                      {'catalogue_contribution': 'human-confirmed'}):
            assert client.post('/v1/ai/extract', json={**body(), **extra}, headers=SCANNER_HEADERS).status_code == 422
        assert client.post(f'/v1/ai/observations/{CODE}', json={}).status_code == 405
