"""Install separate PostgreSQL roles for the self-hosted reminder processes."""

import argparse
import secrets
import sys
from pathlib import Path

import psycopg
from psycopg import sql

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))
sys.path.insert(0, str(ROOT / "scripts"))

from app.selfhost.migrations import MigrationMismatch, migrate
from project_secrets import SecretError, private_directory

ROLE_FILES = {
    "unlabel_notification_worker": "pg-notification-worker",
    "unlabel_reminder_scheduler": "pg-reminder-scheduler",
}


def install_grants(connection, worker, scheduler):
    """Only process-specific tables and functions are available at runtime."""
    worker_id = sql.Identifier(worker)
    scheduler_id = sql.Identifier(scheduler)
    database = sql.Identifier(connection.info.dbname)
    for role_id in [worker_id, scheduler_id]:
        connection.execute(
            sql.SQL("GRANT CONNECT ON DATABASE {} TO {}").format(database, role_id)
        )
        connection.execute(
            sql.SQL("GRANT USAGE ON SCHEMA operations TO {}").format(role_id)
        )
        connection.execute(
            sql.SQL(
                "GRANT SELECT, INSERT, UPDATE(seen_at), DELETE ON operations.worker_heartbeats TO {}"
            ).format(role_id)
        )
    connection.execute(
        sql.SQL(
            "GRANT SELECT, UPDATE(last_delivered_day), DELETE ON operations.push_subscriptions TO {}"
        ).format(worker_id)
    )
    connection.execute(
        sql.SQL(
            "GRANT SELECT, UPDATE(state, attempts, available_at, lease_owner, lease_token, "
            "lease_expires_at, error_code, completed_at) ON operations.outbox TO {}"
        ).format(worker_id)
    )
    connection.execute(
        sql.SQL(
            "GRANT EXECUTE ON FUNCTION operations.claim_topic_jobs(uuid,varchar,integer), "
            "operations.reap_exhausted(), operations.renew_job(uuid,uuid,uuid), "
            "operations.complete_job(uuid,uuid,uuid), "
            "operations.fail_job(uuid,uuid,uuid,varchar) TO {}"
        ).format(worker_id)
    )
    connection.execute(
        sql.SQL(
            "GRANT EXECUTE ON FUNCTION operations.enqueue_daily_reminders(), "
            "operations.prune_finished_jobs() TO {}"
        ).format(scheduler_id)
    )


def ensure_role(connection, role, secret_file):
    if not secret_file.exists():
        with secret_file.open("x", encoding="utf-8") as file:
            file.write(secrets.token_urlsafe(48))
        secret_file.chmod(0o600)
    password = secret_file.read_text(encoding="utf-8").strip()
    if not password:
        raise ValueError("A notification service credential file is empty")
    if not connection.execute(
        "SELECT 1 FROM pg_roles WHERE rolname=%s", (role,)
    ).fetchone():
        connection.execute(sql.SQL("CREATE ROLE {}").format(sql.Identifier(role)))
    connection.execute(
        sql.SQL(
            "ALTER ROLE {} LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE "
            "NOREPLICATION NOBYPASSRLS NOINHERIT PASSWORD {}"
        ).format(sql.Identifier(role), sql.Literal(password))
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--port", type=int, default=15432, help="Loopback SSH tunnel port"
    )
    args = parser.parse_args()
    protected = ROOT / "infrastructure/production/.secrets"
    private_directory(protected)
    try:
        with psycopg.connect(
            host="127.0.0.1",
            port=args.port,
            user="unlabel_migrator",
            password=(protected / "pg-app-admin").read_text(encoding="utf-8").strip(),
            dbname="unlabel_app",
            connect_timeout=5,
        ) as connection:
            connection.execute("SELECT pg_advisory_xact_lock(842317224)")
            for role, filename in ROLE_FILES.items():
                ensure_role(connection, role, protected / filename)
            applied = migrate(connection)
            install_grants(connection, *ROLE_FILES)
    except (psycopg.Error, OSError, ValueError, MigrationMismatch, SecretError):
        raise SystemExit(
            "Reminder role setup failed. Configuration values were withheld."
        ) from None
    print(
        f"Installed reminder roles and verified grants. Applied migrations: {len(applied)}."
    )
    print("Refresh and verify the encrypted project secret backup.")


if __name__ == "__main__":
    main()
