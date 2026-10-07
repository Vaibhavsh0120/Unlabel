"""Real store and SDK transactions against the external Firestore boundary."""

import copy
import threading
from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime
from types import SimpleNamespace
from typing import Any
from uuid import UUID, uuid4

import pytest

NOW = datetime(2026, 10, 7, 9, tzinfo=UTC)
ACTOR = "a" * 64
OTHER = "b" * 64


class MemoryReference:
    def __init__(self, database, path):
        self.database = database
        self.path = path
        self.id = path.rsplit("/", 1)[-1]
        self._document_path = database._database_string + "/documents/" + path

    def get(self, *, retry, timeout):
        return next(self.database.get_all([self], retry=retry, timeout=timeout))


class MemoryCollection:
    def __init__(self, database, name):
        self.database = database
        self.name = name
        self.filter = None
        self.cap = 20

    def document(self, key):
        return MemoryReference(self.database, self.name + "/" + key)

    def where(self, *, filter):
        self.filter = filter
        return self

    def limit(self, number):
        self.cap = number
        return self

    def stream(self, *, retry, timeout):
        assert retry is None and 0 < timeout <= 5
        found = []
        for path, data in self.database.documents.items():
            if not path.startswith(self.name + "/"):
                continue
            if self.filter is not None:
                actual = data.get(self.filter.field_path)
                value = self.filter.value
                if self.filter.op_string == "==" and actual != value:
                    continue
                if self.filter.op_string == "<=" and (actual is None or actual > value):
                    continue
            found.append(self.database.snapshot(MemoryReference(self.database, path)))
        return iter(found[: self.cap])


class MemoryFirestore:
    def __init__(self):
        self.documents = {}
        self.lock = threading.RLock()
        self._database_string = "projects/demo-unlabel/databases/unlabel"
        self._rpc_metadata = ()
        self._firestore_api = self
        self.commits = 0
        self.abort_commits = 0
        self.abort_reads = 0

    def collection(self, name):
        return MemoryCollection(self, name)

    def snapshot(self, reference):
        from google.cloud.firestore_v1.base_document import DocumentSnapshot

        data = copy.deepcopy(self.documents.get(reference.path))
        return DocumentSnapshot(reference, data, data is not None, NOW, NOW, NOW)

    def get_all(self, references, *, transaction=None, retry, timeout):
        from google.api_core.exceptions import Aborted

        assert retry is None and 0 < timeout <= 5
        if transaction is not None:
            assert transaction.in_progress
            assert not transaction._write_pbs, "Transaction performed reads after writes"
            if self.abort_reads:
                self.abort_reads -= 1
                self.lock.release()
                raise Aborted("synthetic read contention")
        return iter(self.snapshot(ref) for ref in references)

    def begin_transaction(self, *, request, metadata, retry, timeout):
        assert retry is None and 0 < timeout <= 5
        self.lock.acquire()
        return SimpleNamespace(transaction=b"memory-transaction")

    def commit(self, *, request, metadata, retry, timeout):
        from google.api_core.exceptions import Aborted
        from google.cloud.firestore_v1 import _helpers

        assert retry is None and 0 < timeout <= 5
        try:
            if self.abort_commits:
                self.abort_commits -= 1
                raise Aborted("provider-secret")
            staged = copy.deepcopy(self.documents)
            for write in request["writes"]:
                if write._pb.HasField("delete"):
                    path = write.delete.split("/documents/", 1)[1]
                    staged.pop(path, None)
                    continue
                path = write.update.name.split("/documents/", 1)[1]
                data = _helpers.decode_dict(write.update.fields, self)
                if write._pb.HasField("current_document"):
                    if write.current_document.exists is False and path in staged:
                        raise AssertionError("create must be atomic")
                if write.update_mask.field_paths:
                    staged[path].update(data)
                else:
                    staged[path] = data
            self.documents = staged
            self.commits += 1
            return SimpleNamespace(write_results=[], commit_time=NOW)
        finally:
            self.lock.release()

    def rollback(self, *, request, metadata, retry, timeout):
        assert retry is None and 0 < timeout <= 5
        # Failed commit already released; callback failures hold the transaction.
        if getattr(self.lock, "_is_owned", lambda: False)():
            self.lock.release()


def contribution(
    submission_id=None, name="Synthetic Test Oats", barcode="1234567890123", **changes
):
    from app.community.service import prepare_submission
    from tests.community_fixtures import contribution_request

    return prepare_submission(
        contribution_request(
            submission_id=str(submission_id or uuid4()),
            barcode=barcode,
            identity={
                "name": name,
                "brand": "Synthetic test",
                "variant": "Plain",
                "language": "en",
            },
            **changes,
        )
    )


@pytest.fixture
def store():
    from app.community.store import FirestoreContributionStore

    return FirestoreContributionStore(MemoryFirestore(), clock=lambda: NOW)


def test_confirmed_submission_automatically_becomes_qualified_candidate(store):
    prepared = contribution(UUID("10000000-0000-4000-8000-000000000001"))
    receipt = store.submit(ACTOR, prepared)
    assert receipt.status == "candidate"
    assert store.submit(ACTOR, prepared) == receipt
    assert store.receipt(ACTOR, prepared.request.submission_id) == receipt
    assert store.receipt(OTHER, prepared.request.submission_id) is None
    public = store.lookup(prepared.request.barcode)
    assert public.revisions[0].review_state == "submitter_confirmed_not_moderator_reviewed"
    counts = [data["count"] for data in store._db.documents.values() if "count" in data]
    assert sorted(counts) == [1, 1, 1]


def test_changed_idempotency_payload_conflicts_without_overwrite(store):
    from app.community.store import StoreConflict

    key = uuid4()
    original = store.submit(ACTOR, contribution(key))
    with pytest.raises(StoreConflict):
        store.submit(ACTOR, contribution(key, name="Synthetic Different Food"))
    assert store.receipt(ACTOR, key) == original


def test_concurrent_identical_submit_is_one_revision(store):
    prepared = contribution()
    with ThreadPoolExecutor(max_workers=8) as executor:
        receipts = list(executor.map(lambda _: store.submit(ACTOR, prepared), range(8)))
    assert all(receipt == receipts[0] for receipt in receipts)
    assert len(store.lookup(prepared.request.barcode).revisions) == 1


def test_retry_does_not_double_count_and_failure_is_redacted(store):

    store._db.abort_commits = 2
    store.submit(ACTOR, contribution())
    assert len(store.lookup("1234567890123").revisions) == 1


def test_read_contention_is_retried_with_same_three_attempt_budget(store):
    from app.community.store import StoreUnavailable

    store._db.abort_reads = 2
    receipt = store.submit(ACTOR, contribution())
    assert receipt.status == "candidate"
    store._db.abort_reads = 3
    with pytest.raises(StoreUnavailable):
        store.submit(OTHER, contribution())
    store._db.abort_commits = 3
    with pytest.raises(StoreUnavailable) as caught:
        store.submit(OTHER, contribution())
    assert "provider-secret" not in str(caught.value)
    assert len(store.lookup("1234567890123").revisions) == 1


def test_actor_daily_quota_is_atomic_and_replay_remains_available(store):
    from app.community.store import StoreQuotaExceeded

    requests = [contribution() for _ in range(11)]
    receipts = [store.submit(ACTOR, request) for request in requests[:10]]
    with pytest.raises(StoreQuotaExceeded):
        store.submit(ACTOR, requests[10])
    assert store.submit(ACTOR, requests[0]) == receipts[0]
    assert len(store.lookup("1234567890123").revisions) == 1


def test_review_hash_and_terminal_decisions_are_immutable(store):
    from app.community.store import StoreConflict

    receipt = store.submit(ACTOR, contribution())
    with pytest.raises(StoreConflict):
        store.review(receipt.revision_id, "approve", "0" * 64)
    accepted = store.review(receipt.revision_id, "approve", receipt.content_sha256)
    assert accepted.status == "approved"
    assert store.review(receipt.revision_id, "approve", receipt.content_sha256) == accepted
    with pytest.raises(StoreConflict):
        store.review(receipt.revision_id, "reject", receipt.content_sha256)
    public = store.lookup(receipt.barcode)
    assert public.status == "found"
    assert public.revisions[0].facts.identity.name == "Synthetic Test Oats"
    assert ACTOR not in public.model_dump_json()
    assert public.revisions[0].origin == "unlabel_community"


def test_rejected_revision_never_becomes_public(store):
    receipt = store.submit(ACTOR, contribution())
    store.review(receipt.revision_id, "reject", receipt.content_sha256)
    assert store.lookup(receipt.barcode).status == "not_found"
    assert store.pending() == []


def test_explicit_supersession_retains_old_private_record(store):
    first = store.submit(ACTOR, contribution())
    store.review(first.revision_id, "approve", first.content_sha256)
    second = store.submit(ACTOR, contribution(name="Synthetic New Packet"))
    store.review(second.revision_id, "approve", second.content_sha256, [first.revision_id])
    assert store.inspect(first.revision_id).status == "superseded"
    assert [item.revision_id for item in store.lookup(first.barcode).revisions] == [
        second.revision_id
    ]


def test_supersession_cannot_cross_barcodes_or_target_pending(store):
    from app.community.store import StoreConflict

    first = store.submit(ACTOR, contribution(barcode="1234567890128"))
    store.review(first.revision_id, "approve", first.content_sha256)
    second = store.submit(ACTOR, contribution())
    with pytest.raises(StoreConflict):
        store.review(second.revision_id, "approve", second.content_sha256, [first.revision_id])
    pending = store.submit(ACTOR, contribution(name="Synthetic conflicting identity"))
    with pytest.raises(StoreConflict):
        store.review(second.revision_id, "approve", second.content_sha256, [pending.revision_id])


def test_eight_active_revisions_bound_and_explicit_replacement(store):
    from app.community.store import StoreConflict

    accepted = []
    for i in range(8):
        receipt = store.submit(ACTOR, contribution(name=f"Synthetic Packet {i}"))
        accepted.append(store.review(receipt.revision_id, "approve", receipt.content_sha256))
    ninth = store.submit(ACTOR, contribution(name="Synthetic Ninth Packet"))
    with pytest.raises(StoreConflict):
        store.review(ninth.revision_id, "approve", ninth.content_sha256)
    store.review(ninth.revision_id, "approve", ninth.content_sha256, [accepted[0].revision_id])
    assert len(store.lookup(ninth.barcode).revisions) == 8


@pytest.mark.parametrize(
    "field,value", [("payload_json", "{}"), ("snapshot_json", "{}"), ("content_sha256", "f" * 64)]
)
def test_tampered_stored_immutable_content_is_unavailable(store, field, value):
    from app.community.store import StoreUnavailable

    receipt = store.submit(ACTOR, contribution())
    store.review(receipt.revision_id, "approve", receipt.content_sha256)
    store._db.documents["community_revisions/" + receipt.revision_id][field] = value
    with pytest.raises(StoreUnavailable):
        store.lookup(receipt.barcode)


def test_provider_failures_do_not_expose_private_errors(store, monkeypatch):
    from app.community.store import StoreUnavailable

    def fail(*args, **kwargs):
        raise RuntimeError("private credential and token")

    monkeypatch.setattr(store._db, "get_all", fail)
    with pytest.raises(StoreUnavailable) as caught:
        store.lookup("1234567890123")
    assert "private" not in str(caught.value)


@pytest.mark.parametrize(
    "key,count", [("submissions_2026-10-07", 200), ("submissions_lifetime", 10000)]
)
def test_global_and_lifetime_limits_reject_without_new_revision(store, key, count):
    from app.community.store import StoreQuotaExceeded

    store._db.documents["community_counters/" + key] = {"count": count}
    with pytest.raises(StoreQuotaExceeded):
        store.submit(ACTOR, contribution())
    assert store.pending() == []
    assert store._db.documents["community_counters/" + key]["count"] == count


def test_lookup_does_not_write_global_counter_or_transaction(store):
    receipt = store.submit(ACTOR, contribution())
    before = copy.deepcopy(store._db.documents)
    commits = store._db.commits
    for _ in range(5):
        assert store.lookup(receipt.barcode).status == "found"
    assert store._db.documents == before
    assert store._db.commits == commits


def test_untrusted_counter_boolean_is_not_treated_as_number(store):
    from app.community.store import StoreUnavailable

    store._db.documents["community_counters/submissions_lifetime"] = {"count": True}
    with pytest.raises(StoreUnavailable):
        store.submit(ACTOR, contribution())
    assert store.pending() == []


def test_public_pointer_cannot_publish_pending_or_invalid_revision(store):
    from app.community.store import StoreUnavailable

    receipt = store.submit(
        ACTOR,
        contribution(
            observation_state="provisional",
            confirmed=False,
            front_confirmed=False,
            back_confirmed=False,
            same_product_confirmed=False,
        ),
    )
    key = "community_public/" + receipt.barcode
    store._db.documents[key] = {
        "barcode": receipt.barcode,
        "revision_ids": [receipt.revision_id],
        "updated_at": NOW,
        "review_required": False,
    }
    with pytest.raises(StoreUnavailable):
        store.lookup(receipt.barcode)
    store._db.documents[key]["revision_ids"] = ["invalid"]
    with pytest.raises(StoreUnavailable):
        store.lookup(receipt.barcode)


def test_valid_changed_label_content_is_detected_by_hash_recomputation(store):
    import json

    from app.community.store import StoreUnavailable

    receipt = store.submit(ACTOR, contribution())
    record = store._db.documents["community_revisions/" + receipt.revision_id]
    body = json.loads(record["payload_json"])
    body["identity"]["name"] = "Synthetic tampered identity"
    record["payload_json"] = json.dumps(body)
    with pytest.raises(StoreUnavailable):
        store.inspect(receipt.revision_id)


def test_emulator_factory_is_explicit_demo_only_and_loopback(monkeypatch):
    from app.community.store import StoreUnavailable, create_emulator_store

    for host, project in [
        ("evil.example:8080", "demo-unlabel"),
        ("127.0.0.1:8080", "real-project"),
    ]:
        monkeypatch.setenv("FIRESTORE_EMULATOR_HOST", host)
        with pytest.raises(StoreUnavailable):
            create_emulator_store(project)


def test_global_semantic_dedup_retains_private_payload_receipts(store):
    first = store.submit(ACTOR, contribution())
    second_request = contribution(observed_on="2026-10-06", capture_method="ocr_corrected")
    second = store.submit(OTHER, second_request)
    assert second.revision_id == first.revision_id
    assert second.deduplicated is True
    assert second.submission_id != first.submission_id
    assert second.content_sha256 == second_request.content_sha256
    assert second.content_sha256 != first.content_sha256
    assert store.receipt(OTHER, second.submission_id) == second
    assert store.receipt(ACTOR, second.submission_id) is None
    assert len(store.lookup(first.barcode).revisions) == 1
    assert (
        len([path for path in store._db.documents if path.startswith("community_revisions/")]) == 1
    )


def test_confirmed_known_conflict_is_saved_pending_and_hidden(store):
    first = store.submit(ACTOR, contribution())
    conflicting = store.submit(OTHER, contribution(name="Synthetic Different Food"))
    assert conflicting.status == "pending"
    assert store.lookup(first.barcode).status == "not_found"
    assert {item.revision_id for item in store.pending()} == {
        first.revision_id,
        conflicting.revision_id,
    }


def test_provisional_without_barcode_is_private_bounded_and_expired(store):
    from datetime import timedelta

    from app.community.store import StoreQuotaExceeded

    provisional: dict[str, Any] = dict(
        barcode=None,
        observation_state="provisional",
        confirmed=False,
        front_confirmed=False,
        back_confirmed=False,
        same_product_confirmed=False,
    )
    for _ in range(10):
        receipt = store.submit(ACTOR, contribution(**provisional))
        assert receipt.status == "provisional"
        assert receipt.expires_at == NOW + timedelta(days=7)
    store._clock = lambda: NOW + timedelta(days=1)
    with pytest.raises(StoreQuotaExceeded):
        store.submit(ACTOR, contribution(**provisional))
    assert store.lookup("1234567890123").status == "not_found"
    store._clock = lambda: NOW + timedelta(days=7)
    assert store.cleanup_expired(limit=20) == 10
    assert store.receipt(ACTOR, receipt.submission_id) is None
    assert store.submit(ACTOR, contribution(**provisional)).status == "provisional"


def test_reformulation_a_b_a_does_not_inherit_old_review_or_supersession(store):
    first = store.submit(ACTOR, contribution())
    store.review(first.revision_id, "approve", first.content_sha256)
    changed = store.submit(ACTOR, contribution(name="Synthetic Reformulated"))
    store.review(changed.revision_id, "approve", changed.content_sha256, [first.revision_id])
    returned = store.submit(ACTOR, contribution())
    assert returned.revision_id != first.revision_id
    assert returned.factual_sha256 == first.factual_sha256
    assert returned.status == "pending"
    assert returned.reviewed_at is None
    store.review(returned.revision_id, "approve", returned.content_sha256, [changed.revision_id])
    assert [revision.revision_id for revision in store.lookup(first.barcode).revisions] == [
        returned.revision_id
    ]


def test_duplicate_receipts_are_still_subject_to_admission_quota(store):
    from app.community.store import StoreQuotaExceeded

    receipts = [store.submit(ACTOR, contribution()) for _ in range(10)]
    assert len({receipt.revision_id for receipt in receipts}) == 1
    with pytest.raises(StoreQuotaExceeded):
        store.submit(ACTOR, contribution())
    assert store.submit(ACTOR, contribution(receipts[0].submission_id)) == receipts[0]


def test_rescan_cannot_bypass_held_conflict_with_empty_public_pointer(store):
    first = store.submit(ACTOR, contribution())
    store.submit(OTHER, contribution(name="Synthetic Conflicting Food"))
    repeated = store.submit(ACTOR, contribution())
    assert repeated.status == "pending"
    assert store.lookup(first.barcode).status == "not_found"
    store.review(first.revision_id, "approve", first.content_sha256)
    assert store.lookup(first.barcode).status == "found"
    duplicate = store.submit(OTHER, contribution())
    assert duplicate.revision_id == first.revision_id
    assert duplicate.deduplicated is True


def test_maximum_table_count_is_readable_after_successful_save(store):
    rows = [
        {
            "row_id": f"r{i}",
            "table_id": f"t{i}",
            "nutrient": "protein",
            "value": 1,
            "unit": "g",
            "basis": {"kind": "quantity", "amount": 100, "unit": "g"},
            "preparation": "as_sold",
        }
        for i in range(64)
    ]
    prepared = contribution(rows=rows)
    assert len(prepared.snapshot.model_dump_json().encode()) > 65536
    receipt = store.submit(ACTOR, prepared)
    assert store.receipt(ACTOR, receipt.submission_id) == receipt
    assert len(store.inspect(receipt.revision_id).snapshot.tables) == 64
    assert len(store.lookup(receipt.barcode).revisions[0].snapshot.tables) == 64


def snapshot_fixture():
    from pathlib import Path

    from app.catalogue.facts import FactsLookup

    path = (
        Path(__file__).resolve().parents[3] / "contracts/examples/catalogue-facts-v1.synthetic.json"
    )
    return FactsLookup.model_validate_json(path.read_text(encoding="utf-8"))


def test_immutable_retry_survives_unavailable_referenced_snapshot(store):
    snapshot = snapshot_fixture()
    assert snapshot.manifest is not None
    prepared = contribution(
        barcode=snapshot.requested_barcode,
        provider_references=[
            {
                "provider": "off_snapshot",
                "source_id": snapshot.manifest.snapshot_id,
                "barcode": snapshot.requested_barcode,
                "fields": ["identity.name"],
            }
        ],
    )
    receipt = store.submit(ACTOR, prepared, baseline=snapshot)
    assert store.submit(ACTOR, prepared, baseline=None) == receipt


def test_new_reference_requires_available_matching_snapshot(store):
    from app.community.store import StoreConflict

    prepared = contribution(
        provider_references=[
            {
                "provider": "off_snapshot",
                "source_id": "unavailable-source",
                "barcode": "1234567890123",
                "fields": ["identity.name"],
            }
        ]
    )
    with pytest.raises(StoreConflict):
        store.submit(ACTOR, prepared)
    assert store._db.documents == {}


@pytest.mark.parametrize("reviewed", [False, True])
def test_semantic_duplicate_cannot_bypass_new_known_snapshot_conflict(store, reviewed):
    snapshot = snapshot_fixture()
    prepared = contribution(barcode=snapshot.requested_barcode)
    first = store.submit(ACTOR, prepared)
    if reviewed:
        store.review(first.revision_id, "approve", first.content_sha256)
    second = store.submit(
        OTHER, contribution(barcode=snapshot.requested_barcode), baseline=snapshot
    )
    assert second.status == "pending"
    assert second.revision_id != first.revision_id
    active = store.lookup(first.barcode)
    assert active.warnings == ["product_conflict_requires_review"]
    if reviewed:
        assert [item.revision_id for item in active.revisions] == [first.revision_id]
    else:
        assert active.status == "not_found"
        assert store.inspect(first.revision_id).status == "pending"
