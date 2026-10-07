"""Optional real transactions against a dedicated loopback Firestore emulator."""

import hashlib
import os
from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime
from uuid import uuid4

import pytest

from app.community.service import prepare_submission
from app.community.store import StoreConflict, StoreUnavailable, create_emulator_store
from tests.community_fixtures import contribution_request

pytestmark = pytest.mark.skipif(
    not os.environ.get("FIRESTORE_EMULATOR_HOST"),
    reason="Real Firestore emulator requires explicit FIRESTORE_EMULATOR_HOST",
)
NOW = datetime(2026, 10, 7, 12, tzinfo=UTC)


@pytest.fixture
def emulator_store():
    project = "demo-unlabel-" + uuid4().hex[:12]
    store = create_emulator_store(project)
    store._clock = lambda: NOW
    try:
        yield store, project
    finally:
        for collection in (
            "community_revisions",
            "community_public",
            "community_counters",
            "community_review_audit",
            "community_receipts",
            "community_staging",
        ):
            for snapshot in (
                store._db.collection(collection).limit(100).stream(retry=None, timeout=3)
            ):
                snapshot.reference.delete(retry=None, timeout=3)
        store._db.close()


def test_real_concurrent_idempotency_persists_across_clients_and_review(emulator_store):
    store, project = emulator_store
    actor = hashlib.sha256(b"synthetic-emulator-subject").hexdigest()
    prepared = prepare_submission(contribution_request(submission_id=str(uuid4())))

    def submit(_):
        try:
            return store.submit(actor, prepared)
        except StoreUnavailable:
            # A bounded retry budget may reject contention. The client outbox
            # replays the same immutable request after concurrent writers settle.
            return None

    with ThreadPoolExecutor(max_workers=4) as executor:
        attempts = list(executor.map(submit, range(4)))
    receipts = [
        receipt if receipt is not None else store.submit(actor, prepared) for receipt in attempts
    ]
    assert all(receipt == receipts[0] for receipt in receipts)
    assert store.pending() == []
    assert store.lookup(prepared.request.barcode).status == "found"
    restored = create_emulator_store(project)
    restored._clock = lambda: NOW
    try:
        assert restored.receipt(actor, prepared.request.submission_id) == receipts[0]
        accepted = restored.review(receipts[0].revision_id, "approve", receipts[0].content_sha256)
        assert accepted.status == "approved"
        found = store.lookup(prepared.request.barcode)
        assert found.status == "found"
        assert found.revisions[0].snapshot.original_rows[0].value == 0
        assert actor not in found.model_dump_json()
        assert len(store.pending()) == 0
        counters = list(store._db.collection("community_counters").stream(retry=None, timeout=3))
        submissions = [
            snapshot.to_dict()["count"]
            for snapshot in counters
            if snapshot.id.startswith("submissions_") or snapshot.id.startswith("actor_")
        ]
        assert submissions == [1, 1, 1]
    finally:
        restored._db.close()


def test_real_idempotency_conflict_and_explicit_supersession(emulator_store):
    store, _ = emulator_store
    actor = "a" * 64
    first = prepare_submission(contribution_request(submission_id=str(uuid4())))
    receipt = store.submit(actor, first)
    changed = prepare_submission(
        contribution_request(
            submission_id=str(first.request.submission_id),
            front_claims=["Synthetic different claim"],
        )
    )
    with pytest.raises(StoreConflict):
        store.submit(actor, changed)
    store.review(receipt.revision_id, "approve", receipt.content_sha256)
    second = store.submit(
        actor,
        prepare_submission(
            contribution_request(
                submission_id=str(uuid4()), front_claims=["Synthetic changed packet"]
            )
        ),
    )
    store.review(second.revision_id, "approve", second.content_sha256, [receipt.revision_id])
    assert store.inspect(receipt.revision_id).status == "superseded"
    assert [revision.revision_id for revision in store.lookup(receipt.barcode).revisions] == [
        second.revision_id
    ]


def test_real_global_semantic_dedup_and_private_receipts(emulator_store):
    store, _ = emulator_store
    first = store.submit(
        "a" * 64, prepare_submission(contribution_request(submission_id=str(uuid4())))
    )
    second = store.submit(
        "b" * 64,
        prepare_submission(
            contribution_request(
                submission_id=str(uuid4()), observed_on="2026-10-06", capture_method="ocr_corrected"
            )
        ),
    )
    assert second.revision_id == first.revision_id
    assert second.deduplicated is True
    assert second.content_sha256 != first.content_sha256
    assert store.receipt("b" * 64, second.submission_id) == second
    assert store.receipt("a" * 64, second.submission_id) is None
    assert len(store.lookup(first.barcode).revisions) == 1


def test_real_conflicting_candidates_are_withdrawn_for_review(emulator_store):
    store, _ = emulator_store
    first = store.submit(
        "a" * 64, prepare_submission(contribution_request(submission_id=str(uuid4())))
    )
    second = store.submit(
        "b" * 64,
        prepare_submission(
            contribution_request(
                submission_id=str(uuid4()),
                ingredients={
                    "status": "present",
                    "text": "Synthetic incompatible label",
                    "completeness": "complete",
                    "origin": "independently_transcribed_package",
                },
            )
        ),
    )
    assert second.status == "pending"
    assert store.lookup(first.barcode).status == "not_found"
    assert {item.revision_id for item in store.pending()} == {first.revision_id, second.revision_id}


def test_real_provisional_expiry_and_operator_cleanup(emulator_store):
    from datetime import timedelta

    store, _ = emulator_store
    provisional = prepare_submission(
        contribution_request(
            submission_id=str(uuid4()),
            barcode=None,
            observation_state="provisional",
            confirmed=False,
            front_confirmed=False,
            back_confirmed=False,
            same_product_confirmed=False,
        )
    )
    receipt = store.submit("a" * 64, provisional)
    assert receipt.status == "provisional"
    assert store.lookup("0123456789012").status == "not_found"
    assert store.cleanup_expired() == 0
    store._clock = lambda: NOW + timedelta(days=7)
    assert store.cleanup_expired() == 1
    assert store.receipt("a" * 64, receipt.submission_id) is None
