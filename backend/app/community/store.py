"""Transactional immutable assertions; no local filesystem or paid fallback."""

import hashlib
import re
from collections.abc import Callable
from datetime import UTC, datetime, timedelta
from typing import Any, Literal, Protocol, TypeVar
from uuid import UUID

from google.api_core.exceptions import Aborted
from google.cloud.firestore_v1.base_query import FieldFilter
from google.cloud.firestore_v1.transaction import Transaction

from app.catalogue.facts import FactsLookup
from app.catalogue.models import validate_barcode
from app.community.models import (
    CommunityLookup,
    CommunityRevision,
    ContributionReceipt,
    ContributionRequest,
    PreparedContribution,
    ReviewItem,
)
from app.community.service import contribution_facts, prepare_submission

RPC_TIMEOUT = 3.0
MAX_ATTEMPTS = 3
ACTOR_DAILY_LIMIT = 10
GLOBAL_DAILY_LIMIT = 200
LIFETIME_LIMIT = 10000
MAX_ACTIVE_REVISIONS = 8
MAX_STAGED_PER_ACTOR = 10
MAX_STORED_BLOB_BYTES = 256 * 1024
T = TypeVar("T")
_RECORD_KEYS = {
    "schema_version",
    "actor_id",
    "revision_id",
    "submission_id",
    "barcode",
    "content_sha256",
    "factual_sha256",
    "status",
    "submitted_at",
    "reviewed_at",
    "payload_json",
    "snapshot_json",
    "supersedes",
    "superseded_by",
    "expires_at",
}


class StoreUnavailable(Exception):
    def __init__(self) -> None:
        super().__init__("Community catalogue is unavailable")


class StoreConflict(Exception):
    def __init__(self) -> None:
        super().__init__("Community assertion conflicts with its immutable review state")


class StoreQuotaExceeded(Exception):
    def __init__(self) -> None:
        super().__init__("Community catalogue admission limit reached")


class ContributionStore(Protocol):
    def submit(
        self, actor_id: str, prepared: PreparedContribution, *, baseline: FactsLookup | None = None
    ) -> ContributionReceipt: ...
    def receipt(self, actor_id: str, submission_id: UUID) -> ContributionReceipt | None: ...
    def lookup(self, barcode: str) -> CommunityLookup: ...
    def pending(self, limit: int = 20) -> list[ReviewItem]: ...
    def inspect(self, revision_id: str) -> ReviewItem | None: ...
    def cleanup_expired(self, limit: int = 20) -> int: ...
    def review(
        self,
        revision_id: str,
        decision: Literal["approve", "reject"],
        expected_hash: str,
        supersedes: list[str] | None = None,
    ) -> ContributionReceipt: ...


class _BoundedTransaction(Transaction):
    """The pinned SDK decorator otherwise omits RPC deadlines on these calls."""

    def _begin(self, retry_id: bytes | None = None) -> None:
        if self.in_progress:
            raise StoreUnavailable()
        response = self._client._firestore_api.begin_transaction(
            request={
                "database": self._client._database_string,
                "options": self._options_protobuf(retry_id),
            },
            metadata=self._client._rpc_metadata,
            retry=None,
            timeout=RPC_TIMEOUT,
        )
        self._id = response.transaction

    def _commit(self) -> list:
        if not self.in_progress:
            raise StoreUnavailable()
        response = self._client._firestore_api.commit(
            request={
                "database": self._client._database_string,
                "writes": self._write_pbs,
                "transaction": self._id,
            },
            metadata=self._client._rpc_metadata,
            retry=None,
            timeout=RPC_TIMEOUT,
        )
        self._clean_up()
        self.write_results = list(response.write_results)
        self.commit_time = response.commit_time
        return self.write_results

    def _rollback(self) -> None:
        if not self.in_progress:
            return
        try:
            self._client._firestore_api.rollback(
                request={"database": self._client._database_string, "transaction": self._id},
                metadata=self._client._rpc_metadata,
                retry=None,
                timeout=RPC_TIMEOUT,
            )
        finally:
            self._clean_up()


def _identifier(value: str) -> str:
    if not isinstance(value, str) or re.fullmatch(r"[0-9a-f]{64}", value) is None:
        raise StoreConflict()
    return value


def _revision_id(actor_id: str, submission_id: UUID) -> str:
    _identifier(actor_id)
    if not isinstance(submission_id, UUID):
        raise StoreConflict()
    return hashlib.sha256(f"{actor_id}:{submission_id}".encode("ascii")).hexdigest()


def _timestamp(value: datetime) -> datetime:
    if not isinstance(value, datetime) or value.tzinfo is None or value.utcoffset() is None:
        raise StoreUnavailable()
    return value.astimezone(UTC)


def _counter(data: dict | None, limit: int) -> int:
    if data is None:
        return 0
    count = data.get("count")
    if set(data) != {"count"} or type(count) is not int or count < 0 or count > limit:
        raise StoreUnavailable()
    return count


class FirestoreContributionStore:
    def __init__(self, db: Any, clock: Callable[[], datetime] | None = None) -> None:
        self._db = db
        self._clock = clock or (lambda: datetime.now(UTC))

    def _ref(self, collection: str, key: str) -> Any:
        return self._db.collection(collection).document(key)

    def _batch(self, references: list[Any], transaction: Transaction | None = None) -> dict:
        if not references:
            return {}
        snapshots = list(
            self._db.get_all(
                references,
                transaction=transaction,
                retry=None,
                timeout=RPC_TIMEOUT,
            )
        )
        values = {
            item.reference.path: item.to_dict() if item.exists else None for item in snapshots
        }
        if len(snapshots) != len(references) or set(values) != {ref.path for ref in references}:
            raise StoreUnavailable()
        return values

    def _run(self, callback: Callable[[Transaction], T]) -> T:
        # Preserve the first aborted transaction's position in Firestore's queue,
        # as the pinned SDK does. Include read contention in the same retry budget.
        transaction = _BoundedTransaction(self._db, max_attempts=MAX_ATTEMPTS)
        retry_id = None
        try:
            for _ in range(MAX_ATTEMPTS):
                transaction._clean_up()
                transaction._begin(retry_id=retry_id)
                if retry_id is None:
                    retry_id = transaction.id
                try:
                    result = callback(transaction)
                    transaction._commit()
                    return result
                except Aborted:
                    continue
            raise StoreUnavailable()
        except Exception as error:
            try:
                transaction._rollback()
            except Exception:
                pass
            if isinstance(error, (StoreConflict, StoreQuotaExceeded, StoreUnavailable)):
                raise
            raise StoreUnavailable() from None

    def _load(self, record: Any, revision_id: str) -> tuple[dict, PreparedContribution]:
        try:
            if not isinstance(record, dict) or set(record) != _RECORD_KEYS:
                raise ValueError()
            if record["schema_version"] != "1" or record["revision_id"] != revision_id:
                raise ValueError()
            for name in ("payload_json", "snapshot_json"):
                value = record[name]
                if not isinstance(value, str) or len(value.encode("utf-8")) > MAX_STORED_BLOB_BYTES:
                    raise ValueError()
            body = ContributionRequest.model_validate_json(record["payload_json"])
            prepared = prepare_submission(body)
            if (
                record["content_sha256"] != prepared.content_sha256
                or record["factual_sha256"] != prepared.factual_sha256
                or record["barcode"] != body.barcode
                or record["submission_id"] != str(body.submission_id)
                or revision_id != _revision_id(record["actor_id"], body.submission_id)
                or record["snapshot_json"] != prepared.snapshot.model_dump_json()
            ):
                raise ValueError()
            supersedes = record["supersedes"]
            if (
                not isinstance(supersedes, list)
                or len(supersedes) > MAX_ACTIVE_REVISIONS
                or len(set(supersedes)) != len(supersedes)
                or any(_identifier(item) == revision_id for item in supersedes)
                or record["superseded_by"] is not None
                and _identifier(record["superseded_by"]) == revision_id
                or record["status"] != "superseded"
                and record["superseded_by"] is not None
                or record["status"] == "superseded"
                and record["superseded_by"] is None
                or record["status"] in {"provisional", "candidate", "pending", "rejected"}
                and supersedes
            ):
                raise ValueError()
            if record["status"] == "provisional":
                if _timestamp(record["expires_at"]) != _timestamp(
                    record["submitted_at"]
                ) + timedelta(days=7):
                    raise ValueError()
            elif record["expires_at"] is not None:
                raise ValueError()
            if (
                record["status"] in {"candidate", "approved", "superseded"}
                and not prepared.auto_eligible
            ):
                raise ValueError()
            self._receipt(record, prepared)
            return record, prepared
        except Exception:
            raise StoreUnavailable() from None

    @staticmethod
    def _receipt(
        record: dict, prepared: PreparedContribution, target: dict | None = None
    ) -> ContributionReceipt:
        actual = target if target is not None else record
        return ContributionReceipt(
            submission_id=prepared.request.submission_id,
            revision_id=actual["revision_id"],
            barcode=prepared.request.barcode,
            content_sha256=prepared.content_sha256,
            factual_sha256=prepared.factual_sha256,
            status=actual["status"],
            submitted_at=record["submitted_at"],
            reviewed_at=actual["reviewed_at"],
            expires_at=actual["expires_at"],
            deduplicated=record["revision_id"] != actual["revision_id"],
            warnings=list(prepared.snapshot.warnings),
        )

    def _load_receipt(self, raw: Any, key: str) -> tuple[dict, PreparedContribution, str]:
        try:
            if not isinstance(raw, dict) or set(raw) != _RECORD_KEYS | {"target_revision_id"}:
                raise ValueError()
            target = _identifier(raw["target_revision_id"])
            record, prepared = self._load({name: raw[name] for name in _RECORD_KEYS}, key)
            return record, prepared, target
        except Exception:
            raise StoreUnavailable() from None

    @staticmethod
    def _public_revision(record: dict, prepared: PreparedContribution) -> CommunityRevision:
        if (
            record["status"] not in {"candidate", "approved"}
            or not prepared.auto_eligible
            or prepared.request.barcode is None
        ):
            raise StoreUnavailable()
        return CommunityRevision(
            revision_id=record["revision_id"],
            content_sha256=prepared.content_sha256,
            factual_sha256=prepared.factual_sha256,
            barcode=prepared.request.barcode,
            submitted_at=record["submitted_at"],
            reviewed_at=record["reviewed_at"],
            facts=contribution_facts(prepared.request),
            snapshot=prepared.snapshot,
            review_state=(
                "moderator_accepted_community_assertion"
                if record["status"] == "approved"
                else "submitter_confirmed_not_moderator_reviewed"
            ),
        )

    @staticmethod
    def _staged(data: Any) -> list[dict]:
        if data is None:
            return []
        if not isinstance(data, dict) or set(data) != {"entries"}:
            raise StoreUnavailable()
        entries = data["entries"]
        if not isinstance(entries, list) or len(entries) > MAX_STAGED_PER_ACTOR:
            raise StoreUnavailable()
        identifiers = []
        for item in entries:
            if not isinstance(item, dict) or set(item) != {"revision_id", "expires_at"}:
                raise StoreUnavailable()
            identifiers.append(_identifier(item["revision_id"]))
            _timestamp(item["expires_at"])
        if len(set(identifiers)) != len(identifiers):
            raise StoreUnavailable()
        return entries

    @staticmethod
    def _review_item(record: dict, prepared: PreparedContribution) -> ReviewItem:
        return ReviewItem(
            revision_id=record["revision_id"],
            content_sha256=prepared.content_sha256,
            factual_sha256=prepared.factual_sha256,
            status=record["status"],
            submitted_at=record["submitted_at"],
            reviewed_at=record["reviewed_at"],
            expires_at=record["expires_at"],
            request=prepared.request,
            snapshot=prepared.snapshot,
            warnings=list(prepared.snapshot.warnings),
        )

    @staticmethod
    def _pointer(data: dict | None, barcode: str) -> list[str]:
        if data is None:
            return []
        if not isinstance(data, dict) or set(data) != {
            "barcode",
            "revision_ids",
            "updated_at",
            "review_required",
        }:
            raise StoreUnavailable()
        ids = data["revision_ids"]
        if (
            data["barcode"] != barcode
            or type(data["review_required"]) is not bool
            or not isinstance(ids, list)
            or len(ids) > MAX_ACTIVE_REVISIONS
            or len(ids) != len(set(ids))
            or any(
                not isinstance(item, str) or re.fullmatch(r"[0-9a-f]{64}", item) is None
                for item in ids
            )
        ):
            raise StoreUnavailable()
        _timestamp(data["updated_at"])
        return ids

    def submit(
        self, actor_id: str, prepared: PreparedContribution, *, baseline: FactsLookup | None = None
    ) -> ContributionReceipt:
        from app.community.service import contribution_conflicts, verify_provider_references

        revision_id = _revision_id(actor_id, prepared.request.submission_id)
        if prepare_submission(prepared.request) != prepared:
            raise StoreConflict()
        now = _timestamp(self._clock())
        day = now.date().isoformat()
        reference = self._ref("community_revisions", revision_id)
        receipt_ref = self._ref("community_receipts", revision_id)
        pointer = (
            self._ref("community_public", prepared.request.barcode)
            if prepared.request.barcode
            else None
        )
        staging = self._ref("community_staging", actor_id)
        limits = [ACTOR_DAILY_LIMIT, GLOBAL_DAILY_LIMIT, LIFETIME_LIMIT]
        counters = [
            self._ref("community_counters", key)
            for key in (f"actor_{actor_id}_{day}", f"submissions_{day}", "submissions_lifetime")
        ]
        record = {
            "schema_version": "1",
            "actor_id": actor_id,
            "revision_id": revision_id,
            "submission_id": str(prepared.request.submission_id),
            "barcode": prepared.request.barcode,
            "content_sha256": prepared.content_sha256,
            "factual_sha256": prepared.factual_sha256,
            "status": "candidate" if prepared.auto_eligible else "provisional",
            "submitted_at": now,
            "reviewed_at": None,
            "payload_json": prepared.request.model_dump_json(),
            "snapshot_json": prepared.snapshot.model_dump_json(),
            "supersedes": [],
            "superseded_by": None,
            "expires_at": None if prepared.auto_eligible else now + timedelta(days=7),
        }
        if any(
            len(record[name].encode("utf-8")) > MAX_STORED_BLOB_BYTES
            for name in ("payload_json", "snapshot_json")
        ):
            raise StoreConflict()

        def perform(transaction: Transaction) -> ContributionReceipt:
            references = [receipt_ref, *counters]
            if pointer is not None:
                references.append(pointer)
            if not prepared.auto_eligible:
                references.append(staging)
            values = self._batch(references, transaction)
            existing = values[receipt_ref.path]
            if existing is not None:
                original, original_prepared, target_id = self._load_receipt(existing, revision_id)
                if original_prepared.request != prepared.request:
                    raise StoreConflict()
                target_ref = self._ref("community_revisions", target_id)
                target, target_prepared = self._load(
                    self._batch([target_ref], transaction)[target_ref.path], target_id
                )
                if target_prepared.factual_sha256 != original_prepared.factual_sha256:
                    raise StoreUnavailable()
                return self._receipt(original, original_prepared, target)
            try:
                verify_provider_references(prepared.request, baseline)
            except ValueError:
                raise StoreConflict() from None
            counts = [
                _counter(values[ref.path], limit)
                for ref, limit in zip(counters, limits, strict=True)
            ]
            if any(count >= limit for count, limit in zip(counts, limits, strict=True)):
                raise StoreQuotaExceeded()
            active = (
                self._pointer(values[pointer.path], prepared.request.barcode)
                if pointer is not None and prepared.request.barcode is not None
                else []
            )
            active_refs = [self._ref("community_revisions", item) for item in active]
            active_values = self._batch(active_refs, transaction)
            active_records = [self._load(active_values[item.path], item.id) for item in active_refs]
            revisions = [self._public_revision(data, facts) for data, facts in active_records]
            if any(revision.barcode != prepared.request.barcode for revision in revisions):
                raise StoreUnavailable()
            # An observation admitted during a source outage is not evidence
            # against later known contradictions. Check the current baseline
            # before attaching even a semantically identical new receipt.
            conflict = prepared.auto_eligible and contribution_conflicts(
                prepared, revisions, baseline
            )
            held = (
                pointer is not None
                and values[pointer.path] is not None
                and values[pointer.path]["review_required"]
            )
            duplicate = next(
                (
                    data
                    for data, facts in active_records
                    if prepared.auto_eligible
                    and not conflict
                    and not held
                    and facts.factual_sha256 == prepared.factual_sha256
                ),
                None,
            )
            decided = record.copy()
            staged_entries = []
            if not prepared.auto_eligible:
                staged_entries = [
                    entry
                    for entry in self._staged(values[staging.path])
                    if entry["expires_at"] > now
                ]
                if len(staged_entries) >= MAX_STAGED_PER_ACTOR:
                    raise StoreQuotaExceeded()
            if prepared.auto_eligible and duplicate is None:
                if len(active) >= MAX_ACTIVE_REVISIONS or conflict or held:
                    decided["status"] = "pending"
            target = duplicate if duplicate is not None else decided
            result = self._receipt(decided, prepared, target)
            transaction.create(receipt_ref, decided | {"target_revision_id": target["revision_id"]})
            if duplicate is None:
                transaction.create(reference, decided)
                if conflict and pointer is not None:
                    withdrawn = [
                        data["revision_id"]
                        for data, _ in active_records
                        if data["status"] == "candidate"
                    ]
                    for identifier in withdrawn:
                        transaction.update(
                            self._ref("community_revisions", identifier), {"status": "pending"}
                        )
                    transaction.set(
                        pointer,
                        {
                            "barcode": prepared.request.barcode,
                            "revision_ids": [item for item in active if item not in withdrawn],
                            "updated_at": now,
                            "review_required": True,
                        },
                    )
                if decided["status"] == "candidate" and pointer is not None:
                    transaction.set(
                        pointer,
                        {
                            "barcode": prepared.request.barcode,
                            "revision_ids": active + [revision_id],
                            "updated_at": now,
                            "review_required": False,
                        },
                    )
                elif decided["status"] == "provisional":
                    transaction.set(
                        staging,
                        {
                            "entries": staged_entries
                            + [{"revision_id": revision_id, "expires_at": decided["expires_at"]}]
                        },
                    )
            for counter, count in zip(counters, counts, strict=True):
                transaction.set(counter, {"count": count + 1})
            return result

        return self._run(perform)

    def receipt(self, actor_id: str, submission_id: UUID) -> ContributionReceipt | None:
        revision_id = _revision_id(actor_id, submission_id)
        try:
            reference = self._ref("community_receipts", revision_id)
            raw = self._batch([reference])[reference.path]
            if raw is None:
                return None
            data, prepared, target_id = self._load_receipt(raw, revision_id)
            if data["actor_id"] != actor_id:
                raise StoreUnavailable()
            target_ref = self._ref("community_revisions", target_id)
            target, target_prepared = self._load(
                self._batch([target_ref])[target_ref.path], target_id
            )
            if target_prepared.factual_sha256 != prepared.factual_sha256:
                raise StoreUnavailable()
            return self._receipt(data, prepared, target)
        except Exception:
            raise StoreUnavailable() from None

    def lookup(self, barcode: str) -> CommunityLookup:
        validate_barcode(barcode)
        pointer = self._ref("community_public", barcode)
        try:
            values = self._batch([pointer])
            identifiers = self._pointer(values[pointer.path], barcode)
            references = [
                self._ref("community_revisions", identifier) for identifier in identifiers
            ]
            records = self._batch(references)
            revisions = []
            for reference in references:
                data, prepared = self._load(records[reference.path], reference.id)
                if data["barcode"] != barcode:
                    raise StoreUnavailable()
                revisions.append(self._public_revision(data, prepared))
            return CommunityLookup(
                requested_barcode=barcode,
                status="found" if revisions else "not_found",
                revisions=revisions,
                warnings=["product_conflict_requires_review"]
                if values[pointer.path] is not None and values[pointer.path]["review_required"]
                else [],
            )
        except Exception:
            raise StoreUnavailable() from None

    def pending(self, limit: int = 20) -> list[ReviewItem]:
        if type(limit) is not int or not 1 <= limit <= 100:
            raise StoreConflict()
        try:
            query = (
                self._db.collection("community_revisions")
                .where(filter=FieldFilter("status", "==", "pending"))
                .limit(limit)
            )
            items = []
            for snapshot in query.stream(retry=None, timeout=RPC_TIMEOUT):
                record, prepared = self._load(snapshot.to_dict(), snapshot.id)
                if record["status"] != "pending":
                    raise StoreUnavailable()
                items.append(self._review_item(record, prepared))
            if len(items) > limit:
                raise StoreUnavailable()
            return sorted(items, key=lambda item: (item.submitted_at, item.revision_id))
        except Exception:
            raise StoreUnavailable() from None

    def inspect(self, revision_id: str) -> ReviewItem | None:
        _identifier(revision_id)
        try:
            reference = self._ref("community_revisions", revision_id)
            record = self._batch([reference])[reference.path]
            if record is None:
                return None
            data, prepared = self._load(record, revision_id)
            return self._review_item(data, prepared)
        except Exception:
            raise StoreUnavailable() from None

    def review(
        self,
        revision_id: str,
        decision: Literal["approve", "reject"],
        expected_hash: str,
        supersedes: list[str] | None = None,
    ) -> ContributionReceipt:
        _identifier(revision_id)
        _identifier(expected_hash)
        supersedes = sorted(supersedes or [])
        if (
            decision not in {"approve", "reject"}
            or len(supersedes) > MAX_ACTIVE_REVISIONS
            or len(set(supersedes)) != len(supersedes)
            or revision_id in supersedes
            or decision == "reject"
            and supersedes
        ):
            raise StoreConflict()
        for identifier in supersedes:
            _identifier(identifier)
        reference = self._ref("community_revisions", revision_id)
        now = _timestamp(self._clock())
        status = "approved" if decision == "approve" else "rejected"

        def perform(transaction: Transaction) -> ContributionReceipt:
            existing = self._batch([reference], transaction)[reference.path]
            if existing is None:
                raise StoreConflict()
            record, prepared = self._load(existing, revision_id)
            if record["content_sha256"] != expected_hash:
                raise StoreConflict()
            if record["status"] == "provisional":
                raise StoreConflict()
            if record["status"] not in {"pending", "candidate"}:
                if record["status"] != status or record["supersedes"] != supersedes:
                    raise StoreConflict()
                return self._receipt(record, prepared)
            if now < record["submitted_at"]:
                raise StoreUnavailable()
            pointer = self._ref("community_public", record["barcode"])
            active = self._pointer(
                self._batch([pointer], transaction)[pointer.path], record["barcode"]
            )
            others = [
                self._ref("community_revisions", item)
                for item in sorted(set(active + supersedes) - {revision_id})
            ]
            values = self._batch(others, transaction)
            other_records = {}
            for other in others:
                old, _ = self._load(values[other.path], other.id)
                other_records[other.id] = old
                if (
                    old["status"] not in {"candidate", "approved"}
                    or old["barcode"] != record["barcode"]
                ):
                    raise StoreConflict()
            if any(item not in active for item in supersedes):
                raise StoreConflict()
            remaining = [item for item in active if item not in supersedes and item != revision_id]
            if status == "approved" and len(remaining) >= MAX_ACTIVE_REVISIONS:
                raise StoreConflict()
            decided = record | {"status": status, "reviewed_at": now, "supersedes": supersedes}
            result = self._receipt(decided, prepared)
            transaction.update(
                reference, {"status": status, "reviewed_at": now, "supersedes": supersedes}
            )
            if status == "approved":
                transaction.set(
                    pointer,
                    {
                        "barcode": record["barcode"],
                        "revision_ids": remaining + [revision_id],
                        "updated_at": now,
                        "review_required": False,
                    },
                )
                for identifier in supersedes:
                    transaction.update(
                        self._ref("community_revisions", identifier),
                        {
                            "status": "superseded",
                            "superseded_by": revision_id,
                            "reviewed_at": other_records[identifier]["reviewed_at"] or now,
                        },
                    )
            elif revision_id in active:
                transaction.set(
                    pointer,
                    {
                        "barcode": record["barcode"],
                        "revision_ids": remaining,
                        "updated_at": now,
                        "review_required": True,
                    },
                )
            transaction.create(
                self._ref("community_review_audit", revision_id),
                {
                    "revision_id": revision_id,
                    "content_sha256": expected_hash,
                    "decision": decision,
                    "reviewed_at": now,
                    "supersedes": supersedes,
                },
            )
            return result

        return self._run(perform)

    def cleanup_expired(self, limit: int = 20) -> int:
        """Operator-only bounded cleanup; no paid TTL/background infrastructure."""
        if type(limit) is not int or not 1 <= limit <= 100:
            raise StoreConflict()
        now = _timestamp(self._clock())
        try:
            query = (
                self._db.collection("community_revisions")
                .where(filter=FieldFilter("expires_at", "<=", now))
                .limit(limit)
            )
            identifiers = [
                snapshot.id for snapshot in query.stream(retry=None, timeout=RPC_TIMEOUT)
            ]
            if len(identifiers) > limit:
                raise StoreUnavailable()
            removed = 0
            for identifier in identifiers:
                reference = self._ref("community_revisions", _identifier(identifier))

                def perform(transaction: Transaction, reference: Any = reference) -> int:
                    raw = self._batch([reference], transaction)[reference.path]
                    if raw is None:
                        return 0
                    record, _ = self._load(raw, reference.id)
                    if record["status"] != "provisional" or record["expires_at"] > now:
                        return 0
                    staging = self._ref("community_staging", record["actor_id"])
                    receipt = self._ref("community_receipts", reference.id)
                    values = self._batch([staging, receipt], transaction)
                    entries = [
                        item
                        for item in self._staged(values[staging.path])
                        if item["revision_id"] != reference.id
                    ]
                    if values[receipt.path] is not None:
                        _, _, target = self._load_receipt(values[receipt.path], reference.id)
                        if target != reference.id:
                            raise StoreUnavailable()
                    transaction.delete(reference)
                    transaction.delete(receipt)
                    transaction.set(staging, {"entries": entries})
                    return 1

                removed += self._run(perform)
            return removed
        except (StoreConflict, StoreUnavailable):
            raise
        except Exception:
            raise StoreUnavailable() from None


def create_emulator_store(
    project_id: str = "demo-unlabel", database_id: str = "unlabel"
) -> FirestoreContributionStore:
    """Explicit tests only: loopback emulator, demo project and no auth bypass."""
    import os
    from urllib.parse import urlsplit

    from google.auth.credentials import AnonymousCredentials
    from google.cloud.firestore_v1 import Client

    host = os.environ.get("FIRESTORE_EMULATOR_HOST", "")
    parsed = urlsplit("http://" + host)
    if (
        parsed.hostname not in {"localhost", "127.0.0.1", "::1"}
        or not parsed.port
        or parsed.path
        or parsed.username
        or parsed.password
        or not project_id.startswith("demo-")
        or database_id != "unlabel"
    ):
        raise StoreUnavailable()
    return FirestoreContributionStore(
        Client(project=project_id, database=database_id, credentials=AnonymousCredentials())
    )
