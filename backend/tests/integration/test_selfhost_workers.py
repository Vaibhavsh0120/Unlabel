"""Exercise the real durable queue in a disposable PostgreSQL database."""

import base64
import hashlib
import importlib.util
import os
import threading
from datetime import UTC, datetime
from pathlib import Path
from types import SimpleNamespace
from uuid import uuid4

import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from pydantic import SecretStr
from pywebpush import WebPushException

from app.selfhost.worker_settings import NotificationWorkerSettings, SchedulerSettings

psycopg = pytest.importorskip("psycopg")
pytest.importorskip("psycopg_pool")
from app.selfhost import worker as module  # noqa: E402
from app.selfhost.worker import Worker, connection_pool, deliver_status, healthy  # noqa: E402

sql = psycopg.sql
make_conninfo = psycopg.conninfo.make_conninfo
MIGRATIONS = Path(__file__).resolve().parents[2] / "migrations/next_major"
ROLE_SETUP = (
    Path(__file__).resolve().parents[3] / "infrastructure/production/configure_reminder_roles.py"
)


def install_grants(connection, worker, scheduler):
    spec = importlib.util.spec_from_file_location("configure_reminder_roles", ROLE_SETUP)
    assert spec is not None and spec.loader is not None
    roles = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(roles)
    roles.install_grants(connection, worker, scheduler)


@pytest.fixture(scope="module")
def database():
    dsn = os.environ.get("UNLABEL_TEST_POSTGRES_ADMIN_DSN")
    if not dsn:
        pytest.skip("An explicit disposable-database bootstrap connection is required")
    name = "unlabel_test_workers_" + uuid4().hex
    role = "worker_test_" + uuid4().hex
    scheduler = "scheduler_test_" + uuid4().hex
    password = uuid4().hex
    with psycopg.connect(dsn, autocommit=True) as admin:
        admin.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(name)))
        try:
            for login in [role, scheduler]:
                admin.execute(
                    sql.SQL(
                        "CREATE ROLE {} LOGIN PASSWORD {} NOSUPERUSER NOCREATEDB "
                        "NOCREATEROLE NOREPLICATION"
                    ).format(sql.Identifier(login), sql.Literal(password))
                )
            admin_dsn = make_conninfo(dsn, dbname=name)
            with psycopg.connect(admin_dsn) as connection:
                for filename in [
                    "0001_foundation.sql",
                    "0002_source_views_and_delivery.sql",
                    "0003_research_projections.sql",
                    "0005_topic_workers.sql",
                ]:
                    connection.execute((MIGRATIONS / filename).read_text(), prepare=False)
                connection.execute(
                    sql.SQL("REVOKE CONNECT ON DATABASE {} FROM PUBLIC").format(
                        sql.Identifier(name)
                    )
                )
                install_grants(connection, role, scheduler)
            worker_dsn = make_conninfo(admin_dsn, user=role, password=password)
            scheduler_dsn = make_conninfo(admin_dsn, user=scheduler, password=password)
            yield admin_dsn, worker_dsn, scheduler_dsn
        finally:
            admin.execute(sql.SQL("DROP DATABASE {} WITH (FORCE)").format(sql.Identifier(name)))
            admin.execute(sql.SQL("DROP ROLE IF EXISTS {}").format(sql.Identifier(role)))
            admin.execute(sql.SQL("DROP ROLE IF EXISTS {}").format(sql.Identifier(scheduler)))


@pytest.fixture
def runtime(database):
    settings = NotificationWorkerSettings(
        _env_file=None,
        database_url=SecretStr(database[1]),
        process_instance="test-" + uuid4().hex,
        web_push_private_key=SecretStr("synthetic-private-key-not-used"),
    )
    with connection_pool(settings) as pool:
        pool.wait(timeout=10)
        yield pool, settings
    with psycopg.connect(database[0]) as connection:
        connection.execute(
            "TRUNCATE operations.outbox, operations.push_subscriptions, "
            "operations.worker_heartbeats"
        )


def subscription(index=0):
    public = (
        ec.generate_private_key(ec.SECP256R1())
        .public_key()
        .public_bytes(serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint)
    )
    return {
        "endpoint": f"https://fcm.googleapis.com/fcm/send/synthetic-{index}",
        "keys": {
            "p256dh": base64.urlsafe_b64encode(public).decode().rstrip("="),
            "auth": base64.urlsafe_b64encode(b"x" * 16).decode().rstrip("="),
        },
    }


def enqueue(database, *, index=0, topic="notifications.deliver", created=None):
    value = subscription(index)
    reference = hashlib.sha256(value["endpoint"].encode()).hexdigest()
    with psycopg.connect(database[0]) as connection:
        connection.execute(
            "INSERT INTO operations.push_subscriptions(id,owner_hash,subscription) "
            "VALUES(%s,%s,%s) ON CONFLICT DO NOTHING",
            (reference, "a" * 64, psycopg.types.json.Jsonb(value)),
        )
        connection.execute(
            "INSERT INTO operations.outbox(topic,idempotency_key,payload) VALUES(%s,%s,%s)",
            (topic, str(uuid4()), psycopg.types.json.Jsonb({"reference": reference})),
        )
        if created:
            connection.execute("UPDATE operations.outbox SET created_at=%s", (created,))
    return reference


def state(pool):
    with pool.connection() as connection:
        return connection.execute(
            "SELECT state,attempts,error_code FROM operations.outbox ORDER BY created_at,id"
        ).fetchall()


def test_worker_claims_only_its_own_topic_and_records_actual_delivery(runtime, database):
    pool, settings = runtime
    enqueue(database, topic="evidence.project", index=1)
    enqueue(database)
    sent = []
    worker = Worker(pool, settings, sender=lambda *args: sent.append(True) or "sent")
    assert worker.tick() == 1
    assert sent == [True]
    assert {row[0] for row in state(pool)} == {"queued", "completed"}
    with pool.connection() as c:
        assert (
            c.execute(
                "SELECT count(*) FROM operations.push_subscriptions "
                "WHERE last_delivered_day=(now() AT TIME ZONE 'UTC')::date"
            ).fetchone()[0]
            == 1
        )
    assert worker.tick() == 0


@pytest.mark.parametrize("action", ["DELETE", "DISABLE"])
def test_unsubscribe_before_claim_prevents_delivery(runtime, database, action):
    pool, settings = runtime
    key = enqueue(database)
    with psycopg.connect(database[0]) as c:
        c.execute(
            "DELETE FROM operations.push_subscriptions WHERE id=%s"
            if action == "DELETE"
            else "UPDATE operations.push_subscriptions SET enabled=false WHERE id=%s",
            (key,),
        )
    worker = Worker(pool, settings, sender=lambda *_: pytest.fail("Unsubscribed push was sent"))
    assert worker.tick() == 1
    assert state(pool)[0][0] == "completed"


def test_obsolete_reminder_is_completed_without_sending(runtime, database):
    pool, settings = runtime
    enqueue(database, created=datetime(2020, 1, 1, tzinfo=UTC))
    worker = Worker(pool, settings, sender=lambda *_: pytest.fail("Obsolete push was sent"))
    assert worker.tick() == 1
    assert state(pool)[0][0] == "completed"


def test_expired_push_subscription_is_removed(runtime, database):
    pool, settings = runtime
    enqueue(database)
    assert Worker(pool, settings, sender=lambda *_: "expired").tick() == 1
    with pool.connection() as c:
        assert c.execute("SELECT count(*) FROM operations.push_subscriptions").fetchone()[0] == 0
    assert state(pool)[0][0] == "completed"


@pytest.mark.parametrize("outcome", ["failed", None])
def test_failure_retries_boundedly_without_false_delivery(runtime, database, outcome):
    pool, settings = runtime
    enqueue(database)
    worker = Worker(pool, settings, sender=lambda *_: outcome)
    for attempt in range(1, 6):
        assert worker.tick() == 1
        expected = "dead" if attempt == 5 else "queued"
        assert state(pool) == [(expected, attempt, "delivery_failed")]
        with pool.connection() as c:
            assert (
                c.execute(
                    "SELECT last_delivered_day FROM operations.push_subscriptions"
                ).fetchone()[0]
                is None
            )
            c.execute("UPDATE operations.outbox SET available_at=now()-interval '1 second'")
    assert worker.tick() == 0


def test_lease_replacement_fences_subscription_metadata(runtime, database):
    pool, settings = runtime
    enqueue(database)
    replacement = uuid4()

    def steal(*_):
        with psycopg.connect(database[0]) as c:
            c.execute("UPDATE operations.outbox SET lease_expires_at=now()-interval '1 second'")
            c.execute(
                "SELECT * FROM operations.claim_topic_jobs(%s,'notifications.deliver',1)",
                (replacement,),
            ).fetchone()
        return "sent"

    assert Worker(pool, settings, sender=steal).tick() == 1
    with pool.connection() as c:
        assert (
            c.execute("SELECT last_delivered_day FROM operations.push_subscriptions").fetchone()[0]
            is None
        )
        assert c.execute("SELECT lease_owner,state FROM operations.outbox").fetchone() == (
            replacement,
            "leased",
        )


def test_long_running_job_renews_its_fenced_lease(runtime, database, monkeypatch):
    pool, settings = runtime
    enqueue(database)
    worker = Worker(pool, settings)
    monkeypatch.setattr(module, "LEASE_RENEW_SECONDS", 0.02)
    with pool.connection() as c:
        with c.cursor(row_factory=psycopg.rows.dict_row) as cursor:
            job = cursor.execute(
                "SELECT * FROM operations.claim_topic_jobs(%s,%s,1)",
                (worker.worker_id, module.TOPIC),
            ).fetchone()
    renewed = threading.Event()
    original = worker._renew
    count = 0

    def renew(value):
        nonlocal count
        result = original(value)
        count += 1
        if count >= 2:
            renewed.set()
        return result

    monkeypatch.setattr(worker, "_renew", renew)
    with worker.lease(job):
        assert renewed.wait(2)
    assert count >= 2


def test_health_is_instance_specific_and_rejects_stale_progress(runtime):
    pool, settings = runtime
    worker = Worker(pool, settings)
    assert healthy(pool, settings, "worker") is False
    worker.heartbeat()
    assert healthy(pool, settings, "worker") is True
    assert healthy(pool, settings, "scheduler") is False
    with pool.connection() as c:
        c.execute("UPDATE operations.worker_heartbeats SET seen_at=now()-interval '2 minutes'")
    assert healthy(pool, settings, "worker") is False


def test_scheduler_bounds_batches_and_is_idempotent_in_utc(runtime, database):
    value = subscription()
    with psycopg.connect(database[0]) as c:
        with c.cursor() as cursor:
            cursor.executemany(
                "INSERT INTO operations.push_subscriptions(id,owner_hash,subscription) "
                "VALUES(%s,%s,%s)",
                [
                    (
                        hashlib.sha256(str(i).encode()).hexdigest(),
                        "a" * 64,
                        psycopg.types.json.Jsonb(value),
                    )
                    for i in range(501)
                ],
            )
        c.execute("SET TIME ZONE 'Pacific/Auckland'")
        assert (
            c.execute(
                "SELECT operations.enqueue_daily_reminders(%s)",
                (datetime(2026, 11, 15, 13, 29, tzinfo=UTC),),
            ).fetchone()[0]
            == 0
        )
        assert (
            c.execute(
                "SELECT operations.enqueue_daily_reminders(%s)",
                (datetime(2026, 11, 15, 13, 30, tzinfo=UTC),),
            ).fetchone()[0]
            == 500
        )
        assert (
            c.execute(
                "SELECT operations.enqueue_daily_reminders(%s)",
                (datetime(2026, 11, 15, 13, 30, tzinfo=UTC),),
            ).fetchone()[0]
            == 1
        )
        assert (
            c.execute(
                "SELECT operations.enqueue_daily_reminders(%s)",
                (datetime(2026, 11, 15, 15, tzinfo=UTC),),
            ).fetchone()[0]
            == 0
        )


def test_finished_job_retention_preserves_pending_work(runtime, database):
    enqueue(database)
    enqueue(database, index=1)
    with psycopg.connect(database[0]) as c:
        c.execute(
            "UPDATE operations.outbox SET state='completed', completed_at=now()-interval '8 days' "
            "WHERE id=(SELECT id FROM operations.outbox ORDER BY id LIMIT 1)"
        )
    with psycopg.connect(database[2]) as c:
        assert c.execute("SELECT operations.prune_finished_jobs()").fetchone()[0] == 1
    with psycopg.connect(database[0]) as c:
        assert c.execute("SELECT state FROM operations.outbox").fetchone()[0] == "queued"


def test_worker_role_cannot_read_accounts(runtime):
    pool, _ = runtime
    with pytest.raises(psycopg.errors.InsufficientPrivilege), pool.connection() as c:
        c.execute("SELECT * FROM accounts.users")


def test_scheduler_can_run_without_reading_subscriptions_or_jobs(database):
    settings = SchedulerSettings(_env_file=None, database_url=SecretStr(database[2]))
    with connection_pool(settings) as pool:
        worker = Worker(pool, settings, kind="scheduler")
        assert worker.schedule() == 0
        worker.heartbeat()
        assert healthy(pool, settings, "scheduler")
        for statement in [
            "SELECT subscription FROM operations.push_subscriptions",
            "DELETE FROM operations.outbox",
            "SELECT operations.enqueue_daily_reminders(now())",
        ]:
            with pytest.raises(psycopg.errors.InsufficientPrivilege), pool.connection() as c:
                c.execute(statement)


def test_worker_cannot_create_or_delete_outbox_jobs(runtime):
    pool, _ = runtime
    for statement in [
        "DELETE FROM operations.outbox",
        "INSERT INTO operations.outbox(topic,idempotency_key,payload) "
        "VALUES('notifications.deliver','synthetic','{}')",
    ]:
        with pytest.raises(psycopg.errors.InsufficientPrivilege), pool.connection() as c:
            c.execute(statement)


@pytest.mark.parametrize(
    "status,expected", [(404, "expired"), (410, "expired"), (429, "failed"), (503, "failed")]
)
def test_push_transport_classifies_provider_failures_without_logging(
    monkeypatch, capsys, status, expected
):
    def fail(*_):
        raise WebPushException(
            "synthetic-private-transport-details", response=SimpleNamespace(status_code=status)
        )

    monkeypatch.setattr(module, "deliver", fail)
    assert deliver_status(None, None) == expected
    assert "synthetic-private" not in capsys.readouterr().out


def test_scheduler_needs_only_app_database_and_stops_while_idle(runtime, monkeypatch):
    pool, settings = runtime
    scheduler_settings = SchedulerSettings(
        _env_file=None,
        database_url=settings.database_url,
        process_instance=settings.process_instance,
    )
    worker = Worker(pool, scheduler_settings, kind="scheduler")
    monkeypatch.setattr(worker, "schedule", lambda: 0)
    progressed = threading.Event()
    monkeypatch.setattr(worker, "heartbeat", progressed.set)
    thread = threading.Thread(target=worker.run)
    thread.start()
    assert progressed.wait(2)
    worker.stop()
    thread.join(timeout=1)
    assert not thread.is_alive()
