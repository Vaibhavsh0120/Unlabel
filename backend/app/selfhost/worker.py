"""PostgreSQL reminder scheduling and topic-specific, fenced push delivery."""

import argparse
import logging
import signal
import threading
from contextlib import contextmanager
from datetime import UTC
from uuid import NAMESPACE_URL, uuid5

import psycopg
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb
from psycopg_pool import ConnectionPool

from app.selfhost.worker_settings import NotificationWorkerSettings, SchedulerSettings

TOPIC = "notifications.deliver"
LEASE_RENEW_SECONDS = 20


class LeaseLost(RuntimeError):
    pass


def deliver_status(config, subscription):
    from pywebpush import WebPushException

    from app.notifications import deliver

    try:
        deliver(config, subscription)
        return "sent"
    except WebPushException as error:
        return "expired" if getattr(error.response, "status_code", None) in {404, 410} else "failed"
    except Exception:  # noqa: BLE001 - outbound diagnostics can contain private push capability URLs.
        return "failed"


def process_id(settings, kind):
    return uuid5(NAMESPACE_URL, f"unlabel:{kind}:{settings.process_instance}")


def connection_pool(settings):
    return ConnectionPool(
        settings.database_url.get_secret_value(),
        min_size=1,
        max_size=3,
        max_waiting=4,
        timeout=3,
        open=False,
        kwargs={
            "connect_timeout": 5,
            "options": "-c statement_timeout=5000 -c lock_timeout=1500 "
            "-c idle_in_transaction_session_timeout=15000 -c timezone=UTC",
        },
    )


def healthy(pool, settings, kind):
    with pool.connection() as connection:
        return bool(
            connection.execute(
                """SELECT 1 FROM operations.worker_heartbeats WHERE worker_id=%s
            AND process_kind=%s AND seen_at > now()-interval '90 seconds'""",
                (process_id(settings, kind), kind),
            ).fetchone()
        )


class Worker:
    def __init__(self, pool, settings, *, kind="worker", sender=deliver_status):
        self.pool = pool
        self.settings = settings
        self.kind = kind
        self.sender = sender
        self.worker_id = process_id(settings, kind)
        self.stopped = threading.Event()
        self.config = None
        if kind == "worker":
            from app.core.config import Settings

            self.config = Settings(
                _env_file=None,
                web_push_private_key=settings.web_push_private_key,
            )

    def stop(self, *_):
        self.stopped.set()

    def heartbeat(self):
        with self.pool.connection() as connection:
            connection.execute(
                """INSERT INTO operations.worker_heartbeats(worker_id,process_kind) VALUES(%s,%s)
                ON CONFLICT(worker_id) DO UPDATE SET seen_at=now()""",
                (self.worker_id, self.kind),
            )
            connection.execute(
                "DELETE FROM operations.worker_heartbeats WHERE seen_at<now()-interval '1 day'"
            )

    def _renew(self, job):
        with self.pool.connection() as connection:
            return connection.execute(
                "SELECT operations.renew_job(%s,%s,%s)",
                (job["id"], self.worker_id, job["lease_token"]),
            ).fetchone()[0]

    @contextmanager
    def lease(self, job):
        if not self._renew(job):
            raise LeaseLost()
        finished, lost = threading.Event(), threading.Event()

        def renew():
            while not finished.wait(LEASE_RENEW_SECONDS):
                try:
                    if not self._renew(job):
                        lost.set()
                        return
                except (psycopg.Error, TimeoutError):
                    lost.set()
                    return

        keeper = threading.Thread(target=renew, name="job-lease", daemon=True)
        keeper.start()
        try:
            yield lost
            if lost.is_set():
                raise LeaseLost()
        finally:
            finished.set()
            keeper.join(timeout=9)

    def notification(self, job):
        from app.notifications import PushSubscription

        reference = job["payload"]["reference"]
        with self.pool.connection() as connection:
            today = connection.execute("SELECT (now() AT TIME ZONE 'UTC')::date").fetchone()[0]
            if job["created_at"].astimezone(UTC).date() != today:
                return  # Yesterday's message is obsolete, not a catch-up notification.
            row = connection.execute(
                """SELECT subscription,last_delivered_day,updated_at
                FROM operations.push_subscriptions WHERE id=%s AND enabled FOR UPDATE""",
                (reference,),
            ).fetchone()
            if not row or row[1] == today or row[2] > job["created_at"]:
                return
            subscription = PushSubscription.model_validate(row[0])
            status = self.sender(self.config, subscription)
            # Fence metadata writes too, not just the final acknowledgement.
            if not connection.execute(
                """SELECT 1 FROM operations.outbox WHERE id=%s AND state='leased'
                AND lease_owner=%s AND lease_token=%s AND lease_expires_at>clock_timestamp()
                FOR UPDATE""",
                (job["id"], self.worker_id, job["lease_token"]),
            ).fetchone():
                raise LeaseLost()
            if status == "expired":
                connection.execute(
                    "DELETE FROM operations.push_subscriptions WHERE id=%s AND subscription=%s",
                    (reference, Jsonb(subscription.model_dump())),
                )
            elif status == "sent":
                connection.execute(
                    """UPDATE operations.push_subscriptions SET last_delivered_day=%s
                    WHERE id=%s AND enabled AND subscription=%s""",
                    (today, reference, Jsonb(subscription.model_dump())),
                )
            else:
                raise RuntimeError("push_transport_failed")

    def tick(self):
        with self.pool.connection() as connection:
            connection.execute("SELECT operations.reap_exhausted()")
            with connection.cursor(row_factory=dict_row) as cursor:
                job = cursor.execute(
                    "SELECT * FROM operations.claim_topic_jobs(%s,%s,1)",
                    (self.worker_id, TOPIC),
                ).fetchone()
        if not job:
            return 0
        try:
            with self.lease(job):
                self.notification(job)
            with self.pool.connection() as connection:
                connection.execute(
                    "SELECT operations.complete_job(%s,%s,%s)",
                    (job["id"], self.worker_id, job["lease_token"]),
                )
        except LeaseLost:
            pass  # A stale owner must not mutate the replacement lease.
        except Exception:  # noqa: BLE001 - durable error codes exclude all private transport details.
            with self.pool.connection() as connection:
                connection.execute(
                    "SELECT operations.fail_job(%s,%s,%s,%s)",
                    (job["id"], self.worker_id, job["lease_token"], "delivery_failed"),
                )
        return 1

    def schedule(self):
        with self.pool.connection() as connection:
            count = connection.execute("SELECT operations.enqueue_daily_reminders()").fetchone()[0]
            connection.execute("SELECT operations.prune_finished_jobs()")
            return count

    def run(self):
        while not self.stopped.is_set():
            try:
                self.schedule() if self.kind == "scheduler" else self.tick()
                self.heartbeat()  # A failed iteration must not advertise successful progress.
            except Exception:  # noqa: BLE001 - values, endpoints and DSNs never enter output.
                print("Background iteration failed; durable state retained.", flush=True)
            self.stopped.wait(30 if self.kind == "scheduler" else 5)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=["worker", "scheduler"])
    parser.add_argument("--healthcheck", action="store_true")
    args = parser.parse_args()
    # The process reports bounded status messages instead of raw connection errors.
    logging.getLogger("psycopg.pool").disabled = True
    try:
        # Health checks require only the database; scheduler never receives VAPID.
        settings = (
            SchedulerSettings()
            if args.healthcheck or args.kind == "scheduler"
            else NotificationWorkerSettings()
        )
        with connection_pool(settings) as pool:
            pool.wait(timeout=10)
            if args.healthcheck:
                return 0 if healthy(pool, settings, args.kind) else 1
            worker = Worker(pool, settings, kind=args.kind)
            signal.signal(signal.SIGTERM, worker.stop)
            signal.signal(signal.SIGINT, worker.stop)
            worker.run()
    except Exception:  # noqa: BLE001 - fail closed without printing secret-bearing config/DSNs.
        if not args.healthcheck:
            print("Background process could not start; check private configuration.", flush=True)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
