"""Global provider selection across workers and concurrent control/failure races."""

import copy
from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime, timedelta

import pytest

from app.ai.store import AiSelectionConflict, FirestoreAiSelectionStore
from app.community.store import StoreQuotaExceeded, StoreUnavailable
from tests.unit.test_community_store import ACTOR, OTHER, MemoryFirestore

CONFIGURATION = "c" * 64
NOW = datetime.now(UTC)
SLOTS = ("gemini-primary", "openai-primary", "gemini-spare")


def stores():
    database = MemoryFirestore()
    return database, [FirestoreAiSelectionStore(database, clock=lambda: NOW) for _ in range(3)]


def test_selection_initializes_once_and_is_shared_by_independent_workers():
    database, workers = stores()
    with ThreadPoolExecutor(max_workers=3) as pool:
        selections = list(pool.map(lambda worker: worker.read(SLOTS[0], CONFIGURATION), workers))
    assert all(value.credential_id == SLOTS[0] and value.revision == 1 for value in selections)
    assert len(database.documents) == 1
    changed = workers[0].activate(SLOTS[1], 1, SLOTS[0], CONFIGURATION)
    assert workers[1].read(SLOTS[0], CONFIGURATION) == changed
    # A restart/default change never resets the existing pointer.
    assert workers[2].read(SLOTS[2], CONFIGURATION).credential_id == SLOTS[1]


def test_manual_switch_uses_cas_and_delayed_failure_cannot_undo_it():
    _, workers = stores()
    old = workers[0].read(SLOTS[0], CONFIGURATION)
    changed = workers[1].activate(SLOTS[1], 1, SLOTS[0], CONFIGURATION)
    with pytest.raises(AiSelectionConflict):
        workers[2].activate(SLOTS[2], 1, SLOTS[0], CONFIGURATION)
    assert workers[0].failed(old, SLOTS, 60) == changed


def test_sticky_failover_does_not_return_to_recovered_primary_or_round_robin():
    _, workers = stores()
    original = workers[0].read(SLOTS[0], CONFIGURATION)
    changed = workers[0].failed(original, SLOTS, 60)
    assert changed.credential_id == SLOTS[1]
    assert changed.blocked_until[SLOTS[0]] == NOW + timedelta(seconds=60)
    assert workers[1].read(SLOTS[0], CONFIGURATION) == changed
    # The next failed replacement skips the primary while its cooldown is active.
    second = workers[1].failed(changed, SLOTS, 60)
    assert second.credential_id == SLOTS[2]
    exhausted = workers[2].failed(second, SLOTS, 60)
    assert exhausted.credential_id == SLOTS[2]
    assert set(exhausted.blocked_until) == set(SLOTS)


def test_one_key_configuration_records_failure_and_never_invents_replacements():
    _, workers = stores()
    original = workers[0].read(SLOTS[0], CONFIGURATION)
    failed = workers[0].failed(original, (), 3600)
    assert failed.credential_id == SLOTS[0]
    assert failed.revision == 2
    assert failed.blocked_until[SLOTS[0]] == NOW + timedelta(hours=1)


def test_explicit_activation_clears_selected_cooldown_and_rebinds_rotated_config():
    _, workers = stores()
    original = workers[0].read(SLOTS[0], CONFIGURATION)
    failed = workers[0].failed(original, (), 86400)
    changed = workers[0].activate(SLOTS[0], failed.revision, SLOTS[0], "d" * 64)
    assert changed.blocked_until == {}
    assert changed.configuration == "d" * 64
    assert workers[1].failed(original, SLOTS, 60) == changed


@pytest.mark.parametrize("candidates,expected", [
    (("gemini-new", "openai-new"), "openai-new"),
    ((), "gemini-new"),
])
def test_rotated_configuration_drops_all_eight_removed_slot_cooldowns_before_failure(
    candidates, expected,
):
    database, workers = stores()
    removed_slots = tuple("old-" + str(index) for index in range(8))
    previous = workers[0].read(removed_slots[-1], CONFIGURATION)
    # All eight old credentials failed before an operator replaced the registry.
    # The old active credential is one of those slots, so this is reachable state.
    record = database.documents["unlabel_service_configuration/ai-active"]
    record["blocked_until"] = {
        slot: NOW + timedelta(hours=1) for slot in removed_slots
    }
    migrated = workers[1].activate("gemini-new", 1, "gemini-new", "d" * 64)
    assert len(migrated.blocked_until) == 8

    # Adding the newly failed active credential must not exceed the eight-slot
    # state bound or disable an otherwise available replacement.
    failed = workers[0].failed(migrated, candidates, 60)
    assert failed.credential_id == expected
    assert failed.configuration == "d" * 64
    assert failed.revision == 3
    assert failed.blocked_until == {"gemini-new": NOW + timedelta(seconds=60)}
    assert workers[2].read("gemini-new", "d" * 64) == failed
    # A delayed failure from the removed configuration cannot restore its policy.
    assert workers[2].failed(previous, removed_slots, 60) == failed


def test_recovering_alternative_never_shortens_existing_provider_cooldown():
    database, workers = stores()
    workers[0].read(SLOTS[0], CONFIGURATION)
    deadline = NOW + timedelta(seconds=59, microseconds=900000)
    database.documents["unlabel_service_configuration/ai-active"]["blocked_until"] = {
        SLOTS[0]: deadline
    }
    observed = workers[1].read(SLOTS[0], CONFIGURATION)
    # Gateway recovery passes integer remaining seconds. Rounding must not make
    # a provider credential eligible before its original Retry-After deadline.
    recovered = workers[0].failed(observed, SLOTS, 59)
    assert recovered.credential_id == SLOTS[1]
    assert recovered.blocked_until[SLOTS[0]] == deadline


def test_retry_does_not_increment_selection_twice_and_errors_are_sanitized():
    database, workers = stores()
    initial = workers[0].read(SLOTS[0], CONFIGURATION)
    database.abort_commits = 2
    changed = workers[0].activate(SLOTS[1], 1, SLOTS[0], CONFIGURATION)
    assert changed.revision == initial.revision + 1
    database.abort_reads = 3
    with pytest.raises(StoreUnavailable) as caught:
        workers[0].read(SLOTS[0], CONFIGURATION)
    assert "secret" not in str(caught.value)


def test_global_quota_is_atomic_and_applies_across_workers():
    database, workers = stores()
    def admit(index):
        try:
            workers[index % 3].admit(ACTOR, daily_limit=5, actor_limit=10)
            return True
        except StoreQuotaExceeded:
            return False
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(admit, range(20)))
    assert sum(results) == 5
    assert database.documents["unlabel_ai_limits/global"]["count"] == 5
    with pytest.raises(StoreQuotaExceeded):
        workers[1].admit(OTHER, daily_limit=5, actor_limit=10)
    assert all(set(value) == {"count", "day"} for value in database.documents.values())


def test_actor_limit_and_next_day_reset_keep_storage_bounded():
    database, workers = stores()
    workers[0].admit(ACTOR, daily_limit=100, actor_limit=1)
    with pytest.raises(StoreQuotaExceeded):
        workers[1].admit(ACTOR, daily_limit=100, actor_limit=1)
    tomorrow = FirestoreAiSelectionStore(database, clock=lambda: NOW + timedelta(days=1))
    tomorrow.admit(ACTOR, daily_limit=100, actor_limit=1)
    assert len(database.documents) == 2
    assert database.documents["unlabel_ai_limits/global"]["count"] == 1


@pytest.mark.parametrize("change", [
    {"revision": True}, {"credential_id": "bad/key"}, {"configuration": "bad"},
    {"schema_version": "2"}, {"api_key": "private"}, {"blocked_until": {"bad/key": NOW}},
])
def test_corrupt_shared_selection_fails_closed(change):
    database, workers = stores()
    workers[0].read(SLOTS[0], CONFIGURATION)
    original = copy.deepcopy(database.documents["unlabel_service_configuration/ai-active"])
    database.documents["unlabel_service_configuration/ai-active"] = original | change
    with pytest.raises(StoreUnavailable):
        workers[1].read(SLOTS[0], CONFIGURATION)
