import copy
from types import SimpleNamespace

import pytest

from app.ai.admission import Baseline, automatic_contribution
from app.ai.models import ExtractedLabel, ExtractionRequest
from app.ai.observations import (
    MachineFacts,
    compatible_identity,
    lookup_observations,
    share_observation,
)
from app.ai.store import FirestoreAiSelectionStore
from app.community.store import FirestoreContributionStore, StoreUnavailable
from tests.unit.test_ai_models import extracted_dict, image_dict
from tests.unit.test_community_store import MemoryFirestore


def label(**changes):
    value = extracted_dict()
    value.update(changes)
    return ExtractedLabel.model_validate(value)


def share(store, facts=None, baseline=None):
    return share_observation(store, label=facts or label(), barcode='8901764051258',
        source_ids=['off:' + 'a' * 64 + ':8901764051258'],
        baseline_values=baseline or [], provider='gemini', model='synthetic', revision=1)


def test_immutable_machine_records_deduplicate_without_promoting_or_retaining_photos():
    database = MemoryFirestore()
    store = FirestoreContributionStore(database)
    first, repeated = share(store), share(store)
    assert first.status == 'shared_unverified' and not first.deduplicated
    assert repeated.deduplicated and repeated.observation_id == first.observation_id
    result = lookup_observations(store, first.barcode)
    assert len(result.observations) == 1
    assert result.observations[0].facts == MachineFacts.from_label(label())
    assert all(key.startswith('unlabel_machine_') for key in database.documents)
    text = repr(database.documents)
    assert 'confirmed=True' not in text and 'data_base64' not in text and 'regions' not in text


def test_conflicting_machine_readings_are_retained_and_flagged_not_selected():
    database = MemoryFirestore()
    store = FirestoreContributionStore(database)
    share(store)
    before = copy.deepcopy(database.documents)
    changed = share(store, label(ingredients='Oats, milk, peanuts'))
    assert changed.conflict_fields == ['ingredients']
    result = lookup_observations(store, changed.barcode)
    assert len(result.observations) == 2 and result.conflict_fields == ['ingredients']
    for key, value in before.items():
        if key.startswith('unlabel_machine_observations/'):
            assert database.documents[key] == value


def test_corrupt_observation_cannot_be_read_or_overwritten():
    database = MemoryFirestore()
    store = FirestoreContributionStore(database)
    first = share(store)
    database.documents['unlabel_machine_observations/' + first.observation_id]['payload_json'] = '{}'
    before = copy.deepcopy(database.documents)
    with pytest.raises(StoreUnavailable):
        share(store)
    assert database.documents == before


def test_identity_requires_name_brand_size_and_compatible_variant():
    identity = label().identity.model_dump()
    assert compatible_identity(identity, {**identity, 'quantity': '0.3 kg'})
    for changed in [{'name': 'Other oats'}, {'brand': None}, {'quantity': '600 g'},
                    {'variant': 'Chocolate'}, {'barcode': '012345678905'}]:
        assert not compatible_identity(identity, {**identity, **changed})


def test_terms_version_and_back_photo_gate_automatic_contributions(monkeypatch):
    facts = label()
    baseline = Baseline('8901764051258', [facts.identity.model_dump()], ['source'], [])
    monkeypatch.setattr('app.ai.admission.known_baseline', lambda *_: baseline)
    store = FirestoreAiSelectionStore(MemoryFirestore())
    state = SimpleNamespace()
    def submit(**body):
        return automatic_contribution(state, store, ExtractionRequest.model_validate(body), facts,
            provider='gemini', model='synthetic', revision=1)
    assert submit(images=[image_dict()], privacy_consent=True).reason == 'not_requested'
    assert submit(images=[image_dict('front')], privacy_consent=True,
        catalogue_contribution='machine-unverified-v1').reason == 'back_photo_required'
    result = submit(images=[image_dict()], privacy_consent=True,
        catalogue_contribution='machine-unverified-v1')
    assert result.status == 'shared_unverified'
    baseline.identities[0]['quantity'] = '600 g'
    assert submit(images=[image_dict()], privacy_consent=True,
        catalogue_contribution='machine-unverified-v1').reason == 'identity_conflict'


@pytest.mark.parametrize('malformed', [[{}], [[]], [1], ['a' * 64, 'a' * 64]])
def test_corrupt_pointer_cannot_escape_validation_or_trigger_writes(malformed):
    database = MemoryFirestore()
    store = FirestoreContributionStore(database)
    database.documents['unlabel_machine_products/8901764051258'] = {
        'schema_version': '1', 'barcode': '8901764051258', 'observations': malformed,
    }
    before = copy.deepcopy(database.documents)
    with pytest.raises(StoreUnavailable):
        lookup_observations(store, '8901764051258')
    with pytest.raises(StoreUnavailable):
        share(store)
    assert database.documents == before


def test_provider_metadata_changes_break_full_record_integrity():
    import json
    database = MemoryFirestore()
    store = FirestoreContributionStore(database)
    first = share(store)
    record = database.documents['unlabel_machine_observations/' + first.observation_id]
    payload = json.loads(record['payload_json'])
    payload['provider_revision'] = 800
    record['payload_json'] = json.dumps(payload)
    with pytest.raises(StoreUnavailable):
        lookup_observations(store, first.barcode)


def test_semantic_retries_ignore_opaque_table_ids_row_order_and_printed_format():
    database = MemoryFirestore()
    store = FirestoreContributionStore(database)
    first = share(store)
    value = extracted_dict()
    value['identity']['quantity'] = '0.3 kg'
    value['ingredients'] = 'OATS,  MILK'
    value['nutrition_tables'][0]['table_id'] = 'different-session-id'
    value['nutrition_tables'][0]['basis']['printed_text'] = '100 grams'
    value['nutrition_tables'][0]['rows'].reverse()
    value['nutrition_tables'][0]['rows'][0]['printed_text'] = 'Other spelling'
    retried = share(store, ExtractedLabel.model_validate(value))
    assert retried.deduplicated and retried.observation_id == first.observation_id
    assert lookup_observations(store, first.barcode).observations[0].facts == MachineFacts.from_label(label())


def test_lifetime_and_product_caps_do_not_evict_immutable_evidence():
    from app.ai.observations import MAX_LIFETIME, MAX_OBSERVATIONS
    database = MemoryFirestore()
    store = FirestoreContributionStore(database)
    for number in range(MAX_OBSERVATIONS):
        assert share(store, label(ingredients=f'Synthetic ingredients {number}')).status == 'shared_unverified'
    before = copy.deepcopy(database.documents)
    assert share(store).reason == 'capacity'
    assert database.documents == before
    database = MemoryFirestore()
    database.documents['unlabel_machine_limits/lifetime'] = {'count': MAX_LIFETIME}
    assert share(FirestoreContributionStore(database)).reason == 'capacity'
    assert len(database.documents) == 1


def test_real_catalogue_name_and_size_match_resolves_without_inventing_a_barcode(tmp_path):
    from app.ai.admission import known_baseline
    from tests.unit.test_catalogue_facts import build, raw_product
    catalogue, _, _, _ = build(tmp_path, [raw_product(code='8901764051258',
        brands='Synthetic brand', quantity='300 g')])
    state = SimpleNamespace(catalogue=catalogue)
    baseline = known_baseline(state, '8901764051258')
    assert baseline.values[0]['nutrition.as_sold.100g.sugars.g'] == {'0'}
    facts = extracted_dict()
    facts['identity']['barcode'] = None
    request = ExtractionRequest.model_validate({'images': [image_dict()], 'privacy_consent': True,
        'catalogue_contribution': 'machine-unverified-v1'})
    store = FirestoreAiSelectionStore(MemoryFirestore())
    result = automatic_contribution(state, store, request, ExtractedLabel.model_validate(facts),
        provider='gemini', model='synthetic', revision=1)
    assert result.status == 'shared_unverified' and result.barcode == '8901764051258'
    saved = store.machine_observations(result.barcode).observations[0]
    assert saved.facts.identity.barcode is None  # The AI did not read a barcode.
    assert saved.identity_source_ids == baseline.source_ids


def test_real_research_basis_without_kind_and_exact_variant_are_compared(tmp_path):
    from app.ai.admission import known_baseline
    from tests.unit.test_research_catalogue import built, candidate
    row = candidate(name='Synthetic oats', code='8901764051258', quantity='300 g')
    row['identity']['brand'] = 'Synthetic brand'
    row['identity']['variant'] = None
    row['nutrition']['direct_tables'][0]['basis']['unit'] = 'g'
    research = built(tmp_path, [row])[-1]
    baseline = known_baseline(SimpleNamespace(research_catalogue=research), '8901764051258')
    assert baseline.values[0]['nutrition.as_sold.100g.sugars.g'] == {'1E+1'}
    assert compatible_identity(label().identity.model_dump(), baseline.identities[0])
    result = share(FirestoreContributionStore(MemoryFirestore()), baseline=baseline.values)
    assert 'nutrition.as_sold.100g.sugars.g' in result.conflict_fields
