"""Private snapshots use the actual SDK transactions behind a synthetic RPC boundary."""

import copy
import json
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from uuid import uuid4

import pytest
from pydantic import ValidationError

from app.accounts.models import MAX_SNAPSHOT_BYTES, PersonalData, SyncRequest
from app.accounts.store import FirestorePersonalStore, SyncConflict, owner_hash
from app.community.store import StoreQuotaExceeded, StoreUnavailable
from tests.unit.test_community_store import ACTOR, NOW, OTHER, MemoryFirestore


def report():
    path = (
        Path(__file__).resolve().parents[3]
        / "contracts/examples/label-report-v1.current.synthetic.json"
    )
    return json.loads(path.read_text(encoding="utf-8"))


def data(name="Synthetic scanner", count=1):
    return {
        "profile": {"display_name": name},
        "saved": [
            {"entry_id": str(uuid4()), "recorded_at": NOW.isoformat(), "report": report()}
            for _ in range(count)
        ],
        "history": [],
    }


def request(revision=0, value=None, mutation=None):
    return SyncRequest.model_validate(
        {
            "expected_revision": revision,
            "mutation_id": str(mutation or uuid4()),
            "data": value if value is not None else data(),
        }
    )


@pytest.fixture
def store():
    return FirestorePersonalStore(MemoryFirestore(), clock=lambda: NOW)


def test_private_schema_roundtrips_iso_dates_and_report_contract_without_weakening_it():
    body = request()
    assert SyncRequest.model_validate_json(body.model_dump_json()) == body
    assert body.data.saved[0].recorded_at == NOW
    assert body.data.saved[0].report.report_version == "label-report-v1"


@pytest.mark.parametrize(
    "change",
    [
        {"password": "SECRET"},
        {"email": "private@example.test"},
        {"uid": "other-owner"},
        {"photos": ["data:image/png,SECRET"]},
        {"raw_ocr": "SECRET"},
    ],
)
def test_private_snapshot_cannot_accept_unmodeled_personal_fields(change):
    with pytest.raises(ValidationError):
        PersonalData.model_validate(data() | change)


def test_nested_extra_report_fields_are_refused_not_silently_stored():
    value = data()
    value["saved"][0]["report"]["password"] = "SECRET"
    with pytest.raises(ValidationError):
        PersonalData.model_validate(value)
    value = data()
    value["saved"][0]["report"]["identity"]["raw_ocr"] = "SECRET"
    with pytest.raises(ValidationError):
        PersonalData.model_validate(value)


@pytest.mark.parametrize("name", ["", " ", "a" * 81, "bad\nname", "bad\x00name"])
def test_profile_display_name_is_bounded_visible_text(name):
    with pytest.raises(ValidationError):
        PersonalData.model_validate(data(name))


def test_duplicate_entry_ids_and_naive_timestamps_are_rejected():
    value = data()
    value["saved"] *= 2
    with pytest.raises(ValidationError):
        PersonalData.model_validate(value)
    value = data()
    value["saved"][0]["recorded_at"] = "2026-10-07T09:00:00"
    with pytest.raises(ValidationError):
        PersonalData.model_validate(value)


@pytest.mark.parametrize("revision", [True, False, 1.5, -1, 2_147_483_648, "1"])
def test_cas_revision_rejects_boolean_lossy_and_unbounded_values(revision):
    with pytest.raises(ValidationError):
        request(revision)


def test_count_and_actual_utf8_byte_budgets_are_enforced():
    value = data(count=51)
    with pytest.raises(ValidationError):
        PersonalData.model_validate(value)
    value = data(count=50)
    for entry in value["saved"]:
        entry["report"]["ingredients"]["text"] = "अ" * 8000
    assert len(json.dumps(value, ensure_ascii=False).encode()) > MAX_SNAPSHOT_BYTES
    with pytest.raises(ValidationError):
        PersonalData.model_validate(value)


def test_owner_ids_are_domain_separated_hmac_not_raw_uid_or_public_actor_hash():
    from app.community.service import actor_hash

    uid, secret = "private-auth-uid", "x" * 32
    assert owner_hash(uid, secret) != actor_hash(uid, secret)
    assert uid not in owner_hash(uid, secret)
    assert owner_hash(uid, secret) != owner_hash("another", secret)


def test_create_read_exact_retry_unchanged_and_private_owner_isolation(store):
    empty = store.read(ACTOR)
    assert empty.revision == 0 and empty.updated_at is None and empty.data.saved == []
    first = request()
    saved = store.replace(ACTOR, first)
    assert saved.revision == 1 and saved.updated_at == NOW
    documents = copy.deepcopy(store._transactions._db.documents)
    assert store.replace(ACTOR, first) == saved
    unchanged = request(1, first.data.model_dump(mode="json"))
    assert store.replace(ACTOR, unchanged) == saved
    assert store._transactions._db.documents == documents
    assert store.read(ACTOR) == saved
    assert store.read(OTHER).revision == 0
    assert not any("private-auth-uid" in str(value) for value in documents.values())


def test_revision_and_mutation_integrity_prevent_overwrite_and_deleted_data_resurrection(store):
    first = request()
    store.replace(ACTOR, first)
    with pytest.raises(SyncConflict) as error:
        store.replace(ACTOR, request(0))
    assert error.value.revision == 1
    with pytest.raises(SyncConflict):
        store.replace(ACTOR, request(0, data("Changed"), first.mutation_id))
    deleted = store.replace(ACTOR, request(1, {"profile": {}, "saved": [], "history": []}))
    assert deleted.revision == 2 and deleted.data.saved == []
    with pytest.raises(SyncConflict) as error:
        store.replace(ACTOR, first)
    assert error.value.revision == 2
    assert store.read(ACTOR) == deleted


def test_two_simultaneous_devices_cannot_both_replace_same_revision(store):
    def write(_):
        try:
            return store.replace(ACTOR, request())
        except SyncConflict as error:
            return error

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(write, range(2)))
    assert sum(isinstance(result, SyncConflict) for result in results) == 1
    assert store.read(ACTOR).revision == 1


@pytest.mark.parametrize(
    "field,value",
    [
        ("owner_id", OTHER),
        ("data_sha256", "0" * 64),
        ("revision", True),
        ("expected_revision", 9),
        ("mutation_id", "wrong"),
        ("data_json", "{}"),
        ("updated_at", None),
        ("arbitrary", "SECRET"),
    ],
)
def test_corrupt_external_storage_fails_closed_without_exposing_data(store, field, value):
    store.replace(ACTOR, request())
    store._transactions._db.documents["unlabel_private_accounts/" + ACTOR][field] = value
    with pytest.raises(StoreUnavailable) as error:
        store.read(ACTOR)
    assert "SECRET" not in str(error.value)


def test_corrupt_storage_cannot_use_noncanonical_valid_json_or_invalid_counter_dates(store):
    import hashlib

    store.replace(ACTOR, request())
    db = store._transactions._db
    record = db.documents["unlabel_private_accounts/" + ACTOR]
    record["data_json"] += " "
    record["data_sha256"] = hashlib.sha256(record["data_json"].encode()).hexdigest()
    with pytest.raises(StoreUnavailable):
        store.read(ACTOR)
    record["data_json"] = record["data_json"].rstrip()
    record["data_sha256"] = hashlib.sha256(record["data_json"].encode()).hexdigest()
    db.documents["unlabel_private_limits/owner-" + ACTOR]["day"] = "2026-99-99"
    with pytest.raises(StoreUnavailable):
        store.replace(ACTOR, request(1))


@pytest.mark.parametrize("kind", ["accounts", "global", "owner"])
def test_admission_limits_are_transactional_and_do_not_partially_write(store, kind):
    from app.accounts.store import ACCOUNT_WRITES_PER_DAY, GLOBAL_WRITES_PER_DAY, MAX_ACCOUNTS

    db = store._transactions._db
    key, value = {
        "accounts": ("accounts", {"count": MAX_ACCOUNTS}),
        "global": ("writes-2026-10-07", {"count": GLOBAL_WRITES_PER_DAY}),
        "owner": ("owner-" + ACTOR, {"day": "2026-10-07", "count": ACCOUNT_WRITES_PER_DAY}),
    }[kind]
    db.documents["unlabel_private_limits/" + key] = value
    before = copy.deepcopy(db.documents)
    with pytest.raises(StoreQuotaExceeded):
        store.replace(ACTOR, request())
    assert db.documents == before


def test_daily_owner_reset_stays_one_document_and_existing_owner_can_sync_at_lifetime_limit(store):
    from app.accounts.store import ACCOUNT_WRITES_PER_DAY, MAX_ACCOUNTS

    store.replace(ACTOR, request())
    db = store._transactions._db
    db.documents["unlabel_private_limits/accounts"] = {"count": MAX_ACCOUNTS}
    db.documents["unlabel_private_limits/owner-" + ACTOR] = {
        "day": "2026-10-06",
        "count": ACCOUNT_WRITES_PER_DAY,
    }
    assert store.replace(ACTOR, request(1, data("Updated"))).revision == 2
    assert db.documents["unlabel_private_limits/owner-" + ACTOR]["count"] == 1


def test_store_retries_only_bounded_contention_and_redacts_provider_failures(store):
    db = store._transactions._db
    db.abort_commits = 2
    assert store.replace(ACTOR, request()).revision == 1
    db.abort_reads = 3
    with pytest.raises(StoreUnavailable) as error:
        store.replace(ACTOR, request(1))
    assert "provider-secret" not in str(error.value)


@pytest.mark.parametrize("owner", ["../other", "", "a" * 65, "PRIVATE"])
def test_untrusted_owner_cannot_select_firestore_paths(store, owner):
    with pytest.raises(StoreUnavailable):
        store.read(owner)
