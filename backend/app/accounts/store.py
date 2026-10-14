"""CAS snapshots with bounded Firestore RPCs, admission and integrity checks."""

import hashlib
import hmac
import re
from collections.abc import Callable
from datetime import UTC, date, datetime
from typing import Any, Protocol
from uuid import UUID

from app.accounts.models import (
    MAX_REVISION,
    MAX_SNAPSHOT_BYTES,
    PersonalData,
    SyncRequest,
    SyncSnapshot,
)
from app.community.store import (
    FirestoreContributionStore,
    StoreConflict,
    StoreQuotaExceeded,
    StoreUnavailable,
)

MAX_ACCOUNTS = 512
GLOBAL_WRITES_PER_DAY = 500
ACCOUNT_WRITES_PER_DAY = 60
_KEYS = {
    "schema_version",
    "owner_id",
    "revision",
    "updated_at",
    "data_json",
    "data_sha256",
    "mutation_id",
    "expected_revision",
}


class SyncConflict(StoreConflict):
    def __init__(self, revision: int) -> None:
        super().__init__()
        self.revision = revision


class SyncDeleted(StoreUnavailable):
    """A deletion marker prevents stale sessions from restoring private data."""


class PersonalStore(Protocol):
    def read(self, owner: str) -> SyncSnapshot: ...
    def replace(self, owner: str, body: SyncRequest) -> SyncSnapshot: ...
    def delete(self, owner: str, uid: str) -> None: ...


def owner_hash(uid: str, secret: str) -> str:
    if not isinstance(uid, str) or not 1 <= len(uid) <= 128 or len(secret) < 32:
        raise ValueError("Invalid private owner configuration")
    return hmac.new(
        secret.encode(), b"personal-sync-v1\0" + uid.encode(), hashlib.sha256
    ).hexdigest()


class FirestorePersonalStore:
    def __init__(self, database: Any, clock: Callable[[], datetime] | None = None) -> None:
        # Reuse the reviewed retry/deadline transaction implementation. No local
        # fallback, client rules change, paid services or additional credential.
        self._transactions = FirestoreContributionStore(database)
        self._clock = clock or (lambda: datetime.now(UTC))

    def _ref(self, owner: str) -> Any:
        if not isinstance(owner, str) or re.fullmatch(r"[0-9a-f]{64}", owner) is None:
            raise StoreUnavailable()
        return self._transactions._ref("unlabel_private_accounts", owner)

    @staticmethod
    def _load(record: Any, owner: str) -> tuple[SyncSnapshot, dict | None]:
        if record is None:
            return SyncSnapshot(), None
        if record == {"schema_version": "1", "deleted": True}:
            raise SyncDeleted()
        try:
            if not isinstance(record, dict) or set(record) != _KEYS:
                raise ValueError()
            value = record["data_json"]
            if (
                record["schema_version"] != "1"
                or record["owner_id"] != owner
                or not isinstance(value, str)
                or len(value.encode()) > MAX_SNAPSHOT_BYTES
                or hashlib.sha256(value.encode()).hexdigest() != record["data_sha256"]
                or type(record["expected_revision"]) is not int
                or record["expected_revision"] != record["revision"] - 1
                or str(UUID(record["mutation_id"])) != record["mutation_id"]
            ):
                raise ValueError()
            snapshot = SyncSnapshot(
                revision=record["revision"],
                updated_at=record["updated_at"],
                data=PersonalData.model_validate_json(value),
            )
            if snapshot.revision == 0 or snapshot.data.model_dump_json() != value:
                raise ValueError()
            return snapshot, record
        except Exception:
            raise StoreUnavailable() from None

    @staticmethod
    def _counter(value: Any, maximum: int) -> int:
        if value is None:
            return 0
        if (
            not isinstance(value, dict)
            or set(value) != {"count"}
            or type(value["count"]) is not int
            or not 0 <= value["count"] <= maximum
        ):
            raise StoreUnavailable()
        return value["count"]

    def read(self, owner: str) -> SyncSnapshot:
        reference = self._ref(owner)
        try:
            values = self._transactions._batch([reference])
            return self._load(values[reference.path], owner)[0]
        except StoreUnavailable:
            raise
        except Exception:
            raise StoreUnavailable() from None

    def delete(self, owner: str, uid: str) -> None:
        reference = self._ref(owner)
        if (
            not isinstance(uid, str)
            or not 1 <= len(uid) <= 128
            or "/" in uid
            or any(ord(character) < 32 for character in uid)
        ):
            raise StoreUnavailable()
        marker = self._transactions._ref("profile_deletions", uid)
        media = self._transactions._ref("profile_media", uid)
        actor = self._transactions._ref("unlabel_private_limits", "owner-" + owner)
        admission = self._transactions._ref("unlabel_private_limits", "accounts")

        def apply(transaction):
            # Read the same record as replace(), so an admitted old POST either
            # finishes first or retries against the permanent deletion marker.
            records = self._transactions._batch([reference, marker, admission], transaction)
            if (
                records[reference.path] == {"schema_version": "1", "deleted": True}
                and records[marker.path] == {"schema": 1}
            ):
                return  # A completed deletion retry consumes no document writes.
            if records[reference.path] is None:
                # Even a never-synced UID needs permanent markers to reject late
                # uploads. Count that first admission toward the same bounded
                # lifetime capacity; already-admitted data can always be purged.
                count = self._counter(records[admission.path], MAX_ACCOUNTS)
                if count >= MAX_ACCOUNTS:
                    raise StoreQuotaExceeded()
                transaction.set(admission, {"count": count + 1})
            transaction.set(reference, {"schema_version": "1", "deleted": True})
            transaction.set(marker, {"schema": 1})
            transaction.delete(media)
            transaction.delete(actor)

        self._transactions._run(apply)

    def replace(self, owner: str, body: SyncRequest) -> SyncSnapshot:
        reference = self._ref(owner)
        value = body.data.model_dump_json()
        value_hash = hashlib.sha256(value.encode()).hexdigest()
        now = self._clock()
        if now.tzinfo is None or now.utcoffset() is None:
            raise StoreUnavailable()
        now = now.astimezone(UTC)
        day = now.strftime("%Y-%m-%d")
        limits = [
            (self._transactions._ref("unlabel_private_limits", "accounts"), MAX_ACCOUNTS),
            (
                self._transactions._ref("unlabel_private_limits", "writes-" + day),
                GLOBAL_WRITES_PER_DAY,
            ),
        ]
        # Daily owner counters live in a fixed per-owner document; changing the
        # calendar date resets it without accumulating unlimited daily documents.
        actor_ref = self._transactions._ref("unlabel_private_limits", "owner-" + owner)

        def apply(transaction):
            refs = [reference, actor_ref, *(ref for ref, _ in limits)]
            records = self._transactions._batch(refs, transaction)
            current, previous = self._load(records[reference.path], owner)
            if previous is not None and previous["mutation_id"] == str(body.mutation_id):
                if (
                    previous["expected_revision"] == body.expected_revision
                    and previous["data_sha256"] == value_hash
                    and previous["data_json"] == value
                ):
                    return current
                raise SyncConflict(current.revision)
            if current.revision != body.expected_revision or current.revision == MAX_REVISION:
                raise SyncConflict(current.revision)
            if previous is not None and previous["data_json"] == value:
                return current  # Unchanged snapshot consumes no document writes.
            counters = [self._counter(records[ref.path], maximum) for ref, maximum in limits]
            actor = records[actor_ref.path]
            if actor is None:
                actor_count = 0
            elif (
                not isinstance(actor, dict)
                or set(actor) != {"day", "count"}
                or not isinstance(actor["day"], str)
                or re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", actor["day"]) is None
            ):
                raise StoreUnavailable()
            else:
                try:
                    if date.fromisoformat(actor["day"]).isoformat() != actor["day"]:
                        raise ValueError()
                except ValueError:
                    raise StoreUnavailable() from None
                actor_count = self._counter({"count": actor["count"]}, ACCOUNT_WRITES_PER_DAY)
                if actor["day"] != day:
                    actor_count = 0
            if (
                (previous is None and counters[0] >= MAX_ACCOUNTS)
                or counters[1] >= GLOBAL_WRITES_PER_DAY
                or actor_count >= ACCOUNT_WRITES_PER_DAY
            ):
                raise StoreQuotaExceeded()
            updated = SyncSnapshot(revision=current.revision + 1, updated_at=now, data=body.data)
            transaction.set(
                reference,
                {
                    "schema_version": "1",
                    "owner_id": owner,
                    "revision": updated.revision,
                    "updated_at": now,
                    "data_json": value,
                    "data_sha256": value_hash,
                    "mutation_id": str(body.mutation_id),
                    "expected_revision": body.expected_revision,
                },
            )
            if previous is None:
                transaction.set(limits[0][0], {"count": counters[0] + 1})
            transaction.set(limits[1][0], {"count": counters[1] + 1})
            transaction.set(actor_ref, {"day": day, "count": actor_count + 1})
            return updated

        return self._transactions._run(apply)
