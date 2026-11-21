"""Concurrent admission and evidence delivery with disposable PostgreSQL state."""

import hashlib
import os
import sys
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from pathlib import Path
from types import SimpleNamespace
from uuid import uuid4

import pytest
from app.community.service import prepare_submission
from app.community.store import StoreConflict, StoreQuotaExceeded
from tests.community_fixtures import CODE, NOW, contribution_request

psycopg = pytest.importorskip("psycopg")
psycopg_pool = pytest.importorskip("psycopg_pool")
pytest.importorskip("pymongo")
from app.selfhost.catalogue import canonical  # noqa: E402
from app.selfhost.community_store import PostgresContributionStore  # noqa: E402
from app.selfhost.evidence_worker import EvidenceWorker, archive_observation  # noqa: E402
from pymongo.errors import DuplicateKeyError  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
ACTOR, OTHER = "a" * 64, "b" * 64


@pytest.fixture(scope="module")
def database():
    dsn = os.environ.get("UNLABEL_TEST_POSTGRES_ADMIN_DSN")
    if not dsn:
        pytest.skip("An explicit disposable-database bootstrap connection is required")
    name = "unlabel_test_community_" + uuid4().hex
    roles = ["community_api_" + uuid4().hex, "evidence_test_" + uuid4().hex]
    with psycopg.connect(dsn, autocommit=True) as bootstrap:
        ident = psycopg.sql.Identifier
        query = psycopg.sql.SQL
        bootstrap.execute(query("CREATE DATABASE {}").format(ident(name)))
        try:
            for role in roles:
                bootstrap.execute(query("CREATE ROLE {} NOLOGIN").format(ident(role)))
            test_dsn = psycopg.conninfo.make_conninfo(dsn, dbname=name)
            with psycopg.connect(test_dsn) as c:
                for migration in sorted((ROOT / "backend/migrations/next_major").glob("*.sql")):
                    c.execute(migration.read_text().replace("TO unlabel_api", f"TO {roles[0]}"),
                              prepare=False)
                with pytest.MonkeyPatch.context() as paths:
                    paths.syspath_prepend(str(ROOT / "infrastructure/production"))
                    from configure_evidence_role import install_grants

                    install_grants(c, roles[1])
                # The helper's imports are local-only and no synthetic roles enter production.
                sys.modules.pop("configure_evidence_role", None)
            yield test_dsn, roles
        finally:
            bootstrap.execute(query("DROP DATABASE {} WITH (FORCE)").format(ident(name)))
            for role in roles:
                bootstrap.execute(query("DROP ROLE IF EXISTS {}").format(ident(role)))


@pytest.fixture
def stores(database):
    dsn, (api_role, evidence_role) = database
    clock = SimpleNamespace(now=NOW)

    def pool_role(role):
        def configure(connection):
            connection.execute(
                psycopg.sql.SQL("SET ROLE {}").format(psycopg.sql.Identifier(role))
            )
            connection.commit()
        return configure

    with (
        psycopg_pool.ConnectionPool(dsn, min_size=1, max_size=5, configure=pool_role(api_role)) as api,
        psycopg_pool.ConnectionPool(dsn, min_size=1, max_size=2, configure=pool_role(evidence_role)) as evidence,
        psycopg_pool.ConnectionPool(dsn, min_size=1, max_size=2) as operator,
    ):
        with operator.connection() as c:
            c.execute("TRUNCATE community.revisions,community.counters,community.review_holds CASCADE")
            c.execute("TRUNCATE operations.outbox,operations.worker_heartbeats")
        yield (
            PostgresContributionStore(api, lambda: clock.now),
            PostgresContributionStore(operator, lambda: clock.now),
            evidence,
            operator,
            clock,
        )


def assertion(**changes):
    return prepare_submission(contribution_request(submission_id=str(uuid4()), **changes))


class MemoryEvidence:
    """Mongo acknowledgement/replay behavior without live collection writes."""

    def __init__(self):
        self.records = {}

    def insert_one(self, document):
        key = document["_id"]
        if key in self.records:
            raise DuplicateKeyError("already archived")
        self.records[key] = document

    def find_one(self, query):
        return self.records.get(query["_id"])


def test_retries_and_cross_actor_semantic_dedup_are_transactional(stores):
    api, _, _, operator, _ = stores
    prepared = assertion()
    with ThreadPoolExecutor(max_workers=5) as executor:
        results = list(executor.map(lambda _: api.submit(ACTOR, prepared), range(5)))
    assert results == [results[0]] * 5
    original = results[0]
    repeated = assertion(capture_method="ocr_corrected")
    assert repeated.content_sha256 != prepared.content_sha256
    assert repeated.factual_sha256 == prepared.factual_sha256
    duplicate = api.submit(OTHER, repeated)
    assert duplicate.deduplicated and duplicate.revision_id == original.revision_id
    assert api.receipt(ACTOR, repeated.request.submission_id) is None
    assert api.receipt(OTHER, repeated.request.submission_id) == duplicate
    with operator.connection() as c:
        assert c.execute("SELECT count(*) FROM community.revisions").fetchone() == (1,)
        assert c.execute("SELECT count(*) FROM operations.outbox").fetchone() == (1,)
        assert c.execute("SELECT count FROM community.counters WHERE key='lifetime'").fetchone() == (2,)


def test_conflict_withdraws_candidates_until_explicit_approval(stores):
    api, moderator, _, _, _ = stores
    first = api.submit(ACTOR, assertion())
    conflicting = assertion(
        identity={"name": "Synthetic different product", "language": "en"}
    )
    second = api.submit(OTHER, conflicting)
    assert second.status == "pending"
    assert api.lookup(CODE).status == "not_found"
    assert api.lookup(CODE).warnings == ["product_conflict_requires_review"]
    assert api.receipt(ACTOR, first.submission_id).status == "pending"
    assert api.submit(ACTOR, assertion()).status == "pending"
    with pytest.raises(StoreConflict):
        moderator.review(second.revision_id, "approve", "c" * 64)
    approved = moderator.review(first.revision_id, "approve", first.content_sha256)
    assert approved.status == "approved"
    assert api.lookup(CODE).revisions[0].revision_id == first.revision_id
    assert api.submit(OTHER, assertion()).deduplicated


def test_quota_failure_rolls_back_receipt_and_every_counter(stores):
    api, _, _, operator, _ = stores
    with operator.connection() as c:
        c.execute("INSERT INTO community.counters VALUES('lifetime',NULL,10000)")
    prepared = assertion()
    with pytest.raises(StoreQuotaExceeded):
        api.submit(ACTOR, prepared)
    with operator.connection() as c:
        assert c.execute("SELECT key,count FROM community.counters").fetchall() == [
            ("lifetime", 10000)
        ]
        assert c.execute("SELECT count(*) FROM operations.outbox").fetchone() == (0,)
    assert api.receipt(ACTOR, prepared.request.submission_id) is None


def test_api_can_enqueue_duplicate_keys_without_reading_private_job_payloads(stores):
    api, _, _, operator, _ = stores
    api.submit(ACTOR, assertion())
    with api.pool.connection() as c:
        keys = c.execute("SELECT topic,idempotency_key FROM operations.outbox").fetchall()
        assert len(keys) == 1
        with pytest.raises(psycopg.errors.InsufficientPrivilege):
            c.execute("SELECT payload FROM operations.outbox")
    with operator.connection() as c:
        assert c.execute("SELECT count(*) FROM operations.outbox").fetchone() == (1,)


def test_staged_observations_stay_private_then_expire(stores):
    api, moderator, _, operator, clock = stores
    result = api.submit(ACTOR, assertion(
        barcode=None,
        observation_state="provisional",
        confirmed=False,
        front_confirmed=False,
        back_confirmed=False,
        same_product_confirmed=False,
    ))
    assert result.status == "provisional"
    assert api.lookup(CODE).status == "not_found"
    assert api.receipt(ACTOR, result.submission_id) == result
    clock.now += timedelta(days=8)
    assert api.receipt(ACTOR, result.submission_id) is None
    assert moderator.cleanup_expired() == 1
    with operator.connection() as c:
        assert c.execute("SELECT count(*) FROM community.publication").fetchone() == (0,)
        assert c.execute("SELECT count(*) FROM community.receipts").fetchone() == (0,)


def test_worker_archives_without_owner_fields_and_fences_replays(stores):
    api, _, evidence, operator, _ = stores
    receipt = api.submit(ACTOR, assertion())
    documents = MemoryEvidence()
    worker = EvidenceWorker(evidence, SimpleNamespace(process_instance="test"), documents)
    worker.heartbeat()
    assert worker.tick() == 1
    assert worker.tick() == 0
    saved = documents.records[receipt.revision_id]
    assert ACTOR not in canonical(saved).decode()
    assert str(receipt.submission_id) not in canonical(saved).decode()
    assert saved["sha256"] == hashlib.sha256(canonical(saved["observation"])).hexdigest()
    archive_observation(documents, saved["_id"], saved["observation"], saved["sha256"])
    with pytest.raises(ValueError, match="differs"):
        documents.records[saved["_id"]] = {"_id": saved["_id"], "sha256": "bad"}
        archive_observation(documents, saved["_id"], saved["observation"], saved["sha256"])
    with evidence.connection() as c, pytest.raises(psycopg.errors.InsufficientPrivilege):
        c.execute("SELECT actor_id FROM community.receipts LIMIT 0")
    with operator.connection() as c:
        assert c.execute("SELECT state FROM operations.outbox").fetchall() == [("completed",)]
