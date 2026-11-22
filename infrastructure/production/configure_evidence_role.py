"""Install the Oracle evidence worker's PostgreSQL login and SQL permissions."""

import argparse

from configure_reminder_roles import (
    ROOT,
    MigrationMismatch,
    SecretError,
    ensure_role,
    migrate,
    private_directory,
    psycopg,
    sql,
)

ROLE = "unlabel_evidence_worker"


def install_grants(connection, role):
    identifier = sql.Identifier(role)
    commands = [
        sql.SQL("GRANT CONNECT ON DATABASE {} TO {}").format(
            sql.Identifier(connection.info.dbname), identifier
        ),
        sql.SQL("GRANT USAGE ON SCHEMA operations, community, ai TO {}").format(identifier),
        sql.SQL("GRANT SELECT ON ai.observations TO {}").format(identifier),
        sql.SQL("GRANT SELECT ON community.publication TO {}").format(identifier),
        sql.SQL(
            "GRANT SELECT, INSERT, UPDATE(seen_at), DELETE ON operations.worker_heartbeats TO {}"
        ).format(identifier),
        sql.SQL(
            "GRANT SELECT, UPDATE(state, attempts, available_at, lease_owner, lease_token, "
            "lease_expires_at, error_code, completed_at) ON operations.outbox TO {}"
        ).format(identifier),
        sql.SQL(
            "GRANT EXECUTE ON FUNCTION operations.claim_topic_jobs(uuid,varchar,integer), "
            "operations.reap_exhausted(), operations.renew_job(uuid,uuid,uuid), "
            "operations.complete_job(uuid,uuid,uuid), operations.fail_job(uuid,uuid,uuid,varchar) TO {}"
        ).format(identifier),
    ]
    for command in commands:
        connection.execute(command)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=15432, help="Loopback SSH tunnel port")
    args = parser.parse_args()
    protected = ROOT / "infrastructure/production/.secrets"
    try:
        private_directory(protected)
        with psycopg.connect(
            host="127.0.0.1",
            port=args.port,
            user="unlabel_migrator",
            password=(protected / "pg-app-admin").read_text(encoding="utf-8").strip(),
            dbname="unlabel_app",
            connect_timeout=5,
        ) as connection:
            connection.execute("SELECT pg_advisory_xact_lock(842317224)")
            ensure_role(connection, ROLE, protected / "pg-evidence-worker")
            applied = migrate(connection)
            install_grants(connection, ROLE)
    except (psycopg.Error, OSError, ValueError, MigrationMismatch, SecretError):
        raise SystemExit("Evidence role setup failed. Configuration values were withheld.") from None
    print(f"Installed the evidence worker role. Applied migrations: {len(applied)}.")
    print("Refresh and verify the encrypted project secret backup.")


if __name__ == "__main__":
    main()
