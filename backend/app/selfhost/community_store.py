"""Transactional community admission and public evidence projection."""

import hashlib
from datetime import UTC, datetime, timedelta

from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from app.catalogue.models import validate_barcode
from app.community.models import (
    CommunityLookup,
    CommunityRevision,
    ContributionReceipt,
    ContributionRequest,
    ReviewItem,
)
from app.community.service import (
    contribution_conflicts,
    contribution_facts,
    prepare_submission,
    verify_provider_references,
)
from app.community.store import (
    ACTOR_DAILY_LIMIT,
    GLOBAL_DAILY_LIMIT,
    LIFETIME_LIMIT,
    MAX_ACTIVE_REVISIONS,
    MAX_STAGED_PER_ACTOR,
    MAX_STORED_BLOB_BYTES,
    StoreConflict,
    StoreQuotaExceeded,
    StoreUnavailable,
    _identifier,
    _revision_id,
    _timestamp,
)
from app.selfhost.catalogue import canonical
from app.selfhost.private_store import storage_connection

EVIDENCE_TOPIC = "evidence.project"


def _prepared(row):
    try:
        prepared = prepare_submission(
            ContributionRequest.model_validate_json(canonical(row["request_json"]))
        )
        if (
            prepared.request.barcode != row["barcode"]
            or prepared.request.submission_id != row["submission_id"]
            or _revision_id(row["actor_id"], row["submission_id"]) != row["revision_id"]
            or prepared.content_sha256 != row["content_sha256"]
            or prepared.factual_sha256 != row["factual_sha256"]
        ):
            raise ValueError()
        return prepared
    except (ValueError, StoreConflict):
        raise StoreUnavailable() from None


def _public(row, prepared):
    if not prepared.auto_eligible or row["status"] not in {"candidate", "approved"}:
        raise StoreUnavailable()
    return CommunityRevision(
        revision_id=row["revision_id"],
        content_sha256=row["content_sha256"],
        factual_sha256=row["factual_sha256"],
        barcode=prepared.request.barcode,
        submitted_at=row["submitted_at"],
        reviewed_at=row["reviewed_at"],
        facts=contribution_facts(prepared.request),
        snapshot=prepared.snapshot,
        review_state=(
            "moderator_accepted_community_assertion"
            if row["status"] == "approved"
            else "submitter_confirmed_not_moderator_reviewed"
        ),
    )


def _receipt(owned, target):
    if owned["factual_sha256"] != target["factual_sha256"]:
        raise StoreUnavailable()
    return ContributionReceipt(
        submission_id=owned["submission_id"],
        revision_id=target["revision_id"],
        barcode=target["barcode"],
        content_sha256=owned["content_sha256"],
        factual_sha256=owned["factual_sha256"],
        status=target["status"],
        submitted_at=owned["submitted_at"],
        expires_at=target["expires_at"],
        reviewed_at=target["reviewed_at"],
        deduplicated=(
            owned["actor_id"] != target["actor_id"]
            or owned["submission_id"] != target["submission_id"]
        ),
        warnings=owned["warnings"],
    )


def _review_item(row):
    prepared = _prepared(row)
    return ReviewItem(
        revision_id=row["revision_id"],
        content_sha256=row["content_sha256"],
        factual_sha256=row["factual_sha256"],
        status=row["status"],
        submitted_at=row["submitted_at"],
        reviewed_at=row["reviewed_at"],
        expires_at=row["expires_at"],
        request=prepared.request,
        snapshot=prepared.snapshot,
        warnings=list(prepared.snapshot.warnings),
    )


def _lock(cursor):
    # One shared admission budget changes on every accepted new request. A single
    # bounded transaction lock also orders related barcode and operator changes.
    cursor.execute("SELECT pg_advisory_xact_lock(842317227)")


def _target(cursor, revision_id):
    return cursor.execute(
        "SELECT * FROM community.revisions WHERE revision_id=%s", (revision_id,)
    ).fetchone()


def _owned(cursor, actor_id, submission_id):
    return cursor.execute(
        "SELECT * FROM community.receipts WHERE actor_id=%s AND submission_id=%s",
        (actor_id, submission_id),
    ).fetchone()


def _active(cursor, barcode):
    rows = cursor.execute(
        """SELECT * FROM community.revisions
        WHERE barcode=%s AND status IN ('candidate','approved')
        ORDER BY submitted_at,revision_id LIMIT 9""",
        (barcode,),
    ).fetchall()
    if len(rows) > MAX_ACTIVE_REVISIONS:
        raise StoreUnavailable()
    return rows


def _hold(cursor, barcode):
    cursor.execute(
        "INSERT INTO community.review_holds(barcode) VALUES(%s) ON CONFLICT DO NOTHING",
        (barcode,),
    )


def _budget(cursor, actor_id, now):
    day = now.date()
    for key, window, limit in (
        (f"actor:{actor_id}:{day}", day, ACTOR_DAILY_LIMIT),
        (f"global:{day}", day, GLOBAL_DAILY_LIMIT),
        ("lifetime", None, LIFETIME_LIMIT),
    ):
        changed = cursor.execute(
            """INSERT INTO community.counters AS old(key,window_day,count) VALUES(%s,%s,1)
            ON CONFLICT(key) DO UPDATE SET count=old.count+1 WHERE old.count<%s""",
            (key, window, limit),
        ).rowcount
        if changed != 1:
            raise StoreQuotaExceeded()


def _publish(cursor, row, prepared):
    revision = _public(row, prepared)
    # Moderation and withdrawal remain SQL visibility state. The immutable
    # Mongo evidence contains only the public assertion as actually submitted.
    document = revision.model_dump(mode="json", exclude={"reviewed_at", "review_state"})
    digest = hashlib.sha256(canonical(document)).hexdigest()
    cursor.execute(
        """INSERT INTO community.publication(revision_id,document,sha256)
        VALUES(%s,%s,%s) ON CONFLICT(revision_id) DO NOTHING""",
        (revision.revision_id, Jsonb(document), digest),
    )
    cursor.execute(
        """INSERT INTO operations.outbox(topic,idempotency_key,payload)
        VALUES(%s,%s,%s) ON CONFLICT(topic,idempotency_key) DO NOTHING""",
        (EVIDENCE_TOPIC, revision.revision_id, Jsonb({"reference": revision.revision_id})),
    )


class PostgresContributionStore:
    def __init__(self, pool, clock=None):
        self.pool = pool
        self.clock = clock or (lambda: datetime.now(UTC))

    def submit(self, actor_id, prepared, *, baseline=None):
        body = prepared.request
        revision_id = _revision_id(actor_id, body.submission_id)
        if prepare_submission(body) != prepared:
            raise StoreConflict()
        payload = body.model_dump(mode="json")
        if len(canonical(payload)) > MAX_STORED_BLOB_BYTES:
            raise StoreConflict()
        now = _timestamp(self.clock())
        with storage_connection(self.pool) as connection, connection.cursor(row_factory=dict_row) as cur:
            _lock(cur)
            saved = _owned(cur, actor_id, body.submission_id)
            if saved:
                if (
                    prepared.content_sha256 != saved["content_sha256"]
                    or prepared.factual_sha256 != saved["factual_sha256"]
                ):
                    raise StoreConflict()
                return self._restore_receipt(cur, saved, now)
            try:
                verify_provider_references(body, baseline)
            except ValueError:
                raise StoreConflict() from None
            _budget(cur, actor_id, now)

            barcode = body.barcode
            active = _active(cur, barcode) if prepared.auto_eligible else []
            revisions = [_public(row, _prepared(row)) for row in active]
            conflict = prepared.auto_eligible and contribution_conflicts(prepared, revisions, baseline)
            held = prepared.auto_eligible and bool(
                cur.execute("SELECT 1 FROM community.review_holds WHERE barcode=%s", (barcode,)).fetchone()
            )
            target = next(
                (row for row in active if row["factual_sha256"] == prepared.factual_sha256),
                None,
            ) if not (conflict or held) else None
            if target is None:
                if not prepared.auto_eligible:
                    count = cur.execute(
                        """SELECT count(*) AS count FROM community.revisions
                        WHERE status='provisional' AND actor_id=%s AND expires_at>%s""",
                        (actor_id, now),
                    ).fetchone()["count"]
                    if count >= MAX_STAGED_PER_ACTOR:
                        raise StoreQuotaExceeded()
                    status, expires = "provisional", now + timedelta(days=7)
                else:
                    status = "pending" if conflict or held or len(active) >= MAX_ACTIVE_REVISIONS else "candidate"
                    expires = None
                cur.execute(
                    """INSERT INTO community.revisions(revision_id,actor_id,submission_id,
                    barcode,content_sha256,factual_sha256,request_json,status,submitted_at,expires_at)
                    VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
                    (revision_id, actor_id, body.submission_id, barcode, prepared.content_sha256,
                     prepared.factual_sha256, Jsonb(payload), status, now, expires),
                )
                target = _target(cur, revision_id)
                if conflict:
                    cur.execute(
                        "UPDATE community.revisions SET status='pending' WHERE barcode=%s AND status='candidate'",
                        (barcode,),
                    )
                    _hold(cur, barcode)
                if status == "candidate":
                    _publish(cur, target, prepared)
            owned = cur.execute(
                """INSERT INTO community.receipts(actor_id,submission_id,target_id,
                content_sha256,factual_sha256,submitted_at,warnings)
                VALUES(%s,%s,%s,%s,%s,%s,%s) RETURNING *""",
                (actor_id, body.submission_id, target["revision_id"], prepared.content_sha256,
                 prepared.factual_sha256, now, list(prepared.snapshot.warnings)),
            ).fetchone()
            return _receipt(owned, target)

    @staticmethod
    def _restore_receipt(cur, saved, now, *, expired_as_missing=False):
        row = _target(cur, saved["target_id"])
        if row is None:
            raise StoreUnavailable()
        if row["expires_at"] is not None and row["expires_at"] <= now:
            if expired_as_missing:
                return None
            raise StoreConflict()
        _prepared(row)
        return _receipt(saved, row)

    def receipt(self, actor_id, submission_id):
        _revision_id(actor_id, submission_id)
        with storage_connection(self.pool) as connection, connection.cursor(row_factory=dict_row) as cur:
            cur.execute("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY")
            saved = _owned(cur, actor_id, submission_id)
            return (
                self._restore_receipt(cur, saved, _timestamp(self.clock()), expired_as_missing=True)
                if saved else None
            )

    def lookup(self, barcode):
        validate_barcode(barcode)
        with storage_connection(self.pool) as connection, connection.cursor(row_factory=dict_row) as cur:
            cur.execute("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY")
            revisions = [_public(row, _prepared(row)) for row in _active(cur, barcode)]
            held = cur.execute(
                "SELECT 1 FROM community.review_holds WHERE barcode=%s", (barcode,)
            ).fetchone()
        return CommunityLookup(
            requested_barcode=barcode,
            status="found" if revisions else "not_found",
            revisions=revisions,
            warnings=["product_conflict_requires_review"] if held else [],
        )

    def pending(self, limit=20):
        if type(limit) is not int or not 1 <= limit <= 100:
            raise StoreConflict()
        with storage_connection(self.pool) as connection, connection.cursor(row_factory=dict_row) as cur:
            rows = cur.execute(
                """SELECT * FROM community.revisions WHERE status='pending'
                ORDER BY submitted_at,revision_id LIMIT %s""", (limit,),
            ).fetchall()
            return [_review_item(row) for row in rows]

    def inspect(self, revision_id):
        _identifier(revision_id)
        with storage_connection(self.pool) as connection, connection.cursor(row_factory=dict_row) as cur:
            row = _target(cur, revision_id)
            if row is None or row["expires_at"] is not None and row["expires_at"] <= _timestamp(self.clock()):
                return None
            return _review_item(row)

    def review(self, revision_id, decision, expected_hash, supersedes=None):
        _identifier(revision_id)
        _identifier(expected_hash)
        replacements = sorted(supersedes or [])
        if (
            decision not in {"approve", "reject"} or len(replacements) > MAX_ACTIVE_REVISIONS
            or len(set(replacements)) != len(replacements) or revision_id in replacements
            or decision == "reject" and replacements
        ):
            raise StoreConflict()
        for old_id in replacements:
            _identifier(old_id)
        status = "approved" if decision == "approve" else "rejected"
        now = _timestamp(self.clock())
        with storage_connection(self.pool) as connection, connection.cursor(row_factory=dict_row) as cur:
            _lock(cur)
            row = _target(cur, revision_id)
            if not row or row["content_sha256"] != expected_hash or row["status"] == "provisional":
                raise StoreConflict()
            prepared = _prepared(row)
            owned = _owned(cur, row["actor_id"], row["submission_id"])
            if row["status"] not in {"pending", "candidate"}:
                if row["status"] != status or row["supersedes"] != replacements:
                    raise StoreConflict()
                return _receipt(owned, row)
            if now < row["submitted_at"]:
                raise StoreUnavailable()
            active = {item["revision_id"] for item in _active(cur, row["barcode"])}
            if not set(replacements).issubset(active) or (
                status == "approved" and len(active - set(replacements) - {revision_id}) >= MAX_ACTIVE_REVISIONS
            ):
                raise StoreConflict()
            cur.execute(
                """UPDATE community.revisions SET status=%s,reviewed_at=%s,supersedes=%s
                WHERE revision_id=%s""", (status, now, replacements, revision_id),
            )
            decided = _target(cur, revision_id)
            if status == "approved":
                cur.execute("DELETE FROM community.review_holds WHERE barcode=%s", (row["barcode"],))
                cur.execute(
                    """UPDATE community.revisions SET status='superseded',
                    reviewed_at=coalesce(reviewed_at,%s),superseded_by=%s WHERE revision_id=ANY(%s)""",
                    (now, revision_id, replacements),
                )
                _publish(cur, decided, prepared)
            elif revision_id in active:
                _hold(cur, row["barcode"])
            cur.execute(
                """INSERT INTO community.review_audit(revision_id,content_sha256,decision,reviewed_at,supersedes)
                VALUES(%s,%s,%s,%s,%s)""", (revision_id, expected_hash, decision, now, replacements),
            )
            return _receipt(owned, decided)

    def cleanup_expired(self, limit=20):
        if type(limit) is not int or not 1 <= limit <= 100:
            raise StoreConflict()
        now = _timestamp(self.clock())
        with storage_connection(self.pool) as connection:
            with connection.cursor() as cur:
                _lock(cur)
                cur.execute(
                    """DELETE FROM community.counters WHERE key IN (SELECT key FROM community.counters
                    WHERE window_day<%s ORDER BY window_day,key LIMIT %s)""",
                    (now.date() - timedelta(days=7), limit),
                )
                return cur.execute(
                    """DELETE FROM community.revisions WHERE revision_id IN
                    (SELECT revision_id FROM community.revisions WHERE status='provisional'
                    AND expires_at<=%s ORDER BY expires_at,revision_id LIMIT %s)""",
                    (now, limit),
                ).rowcount
