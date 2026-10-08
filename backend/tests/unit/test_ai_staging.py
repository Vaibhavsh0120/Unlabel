import hashlib
import json
from datetime import UTC, datetime, timedelta

import pytest

from app.ai.models import ExtractedLabel
from app.ai.staging import MAX_BUCKET_ITEMS, stage_machine_facts
from app.community.store import FirestoreContributionStore, StoreUnavailable
from tests.unit.test_ai_models import extracted_dict
from tests.unit.test_community_store import MemoryFirestore


def label():
    return ExtractedLabel.model_validate(extracted_dict())


def test_proposals_keep_qualifiers_but_no_images_geometry_or_public_writes():
    database = MemoryFirestore()
    transactions = FirestoreContributionStore(database)
    actor = hashlib.sha256(b'synthetic actor').hexdigest()
    now = datetime(2026, 10, 8, tzinfo=UTC)
    first = stage_machine_facts(transactions, actor, label(), now=now)
    repeated = stage_machine_facts(transactions, actor, label(), now=now)
    assert first.status == 'private_unverified' and not first.deduplicated
    assert repeated.deduplicated
    assert len(database.documents) == 1
    key, bucket = next(iter(database.documents.items()))
    assert key.startswith('unlabel_machine_staging/')
    facts = json.loads(bucket['items'][0]['facts_json'])
    assert 'regions' not in facts and 'data_base64' not in facts
    assert facts['evidence'] == 'machine_extracted_unverified'
    assert facts['nutrition_tables'] == label().model_dump(mode='json')['nutrition_tables']


def test_fixed_bucket_eviction_and_expiry_bound_private_proposal_storage():
    database = MemoryFirestore()
    transactions = FirestoreContributionStore(database)
    # Deliberately collide actors in one fixed bucket to exercise the storage cap.
    actors = []
    index = 0
    while len(actors) <= MAX_BUCKET_ITEMS:
        actor = hashlib.sha256(str(index).encode()).hexdigest()
        index += 1
        if hashlib.sha256(actor.encode()).hexdigest()[:2] == '00':
            actors.append(actor)
    now = datetime(2026, 10, 8, tzinfo=UTC)
    for index, actor in enumerate(actors):
        stage_machine_facts(transactions, actor, label(), now=now + timedelta(seconds=index))
    bucket = next(iter(database.documents.values()))
    assert len(bucket['items']) == MAX_BUCKET_ITEMS
    assert actors[0] not in [item['owner'] for item in bucket['items']]
    stage_machine_facts(transactions, actors[0], label(), now=now + timedelta(days=8))
    assert len(next(iter(database.documents.values()))['items']) == 1


def test_corrupt_staging_bucket_is_not_overwritten_and_actor_is_required():
    database = MemoryFirestore()
    transactions = FirestoreContributionStore(database)
    actor = hashlib.sha256(b'synthetic actor').hexdigest()
    stage_machine_facts(transactions, actor, label())
    key = next(iter(database.documents))
    database.documents[key]['items'][0]['facts_json'] = '{}'
    before = repr(database.documents)
    with pytest.raises(StoreUnavailable):
        stage_machine_facts(transactions, actor, label())
    assert repr(database.documents) == before
    with pytest.raises(StoreUnavailable):
        stage_machine_facts(transactions, 'raw-user-identity', label())


def test_oversized_structured_facts_still_have_explicit_no_storage_status():
    value = extracted_dict()
    value['ingredients'] = 'a' * 16000
    value['contains'] = 'b' * 16000
    value['may_contain'] = 'c' * 16000
    database = MemoryFirestore()
    result = stage_machine_facts(FirestoreContributionStore(database), 'a' * 64,
                                 ExtractedLabel.model_validate(value))
    assert result.status == 'not_stored' and result.reason == 'too_large'
    assert not database.documents
