"""Install the restricted guest cleanup role; only local ignored files hold secrets."""

import secrets
import sys
from pathlib import Path

import psycopg
from psycopg import sql
from psycopg.conninfo import make_conninfo

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))
sys.path.insert(0, str(ROOT / "scripts"))
from app.selfhost.migrations import migrate
from project_secrets import private_directory


def main():
    directory = ROOT / "infrastructure/production/.secrets"
    private_directory(directory)
    target = directory / "pg-guest-cleanup"
    if target.exists():
        password = target.read_text().strip()
    else:
        password = secrets.token_urlsafe(48)
        with target.open("x", encoding="utf-8") as output:
            output.write(password)
        target.chmod(0o600)
    # Use the existing loopback SSH tunnel; bootstrap credentials never reach a service.
    common = {"host": "127.0.0.1", "port": 15432, "connect_timeout": 5}
    admin_password = (directory / "pg-app-admin").read_text().strip()
    with psycopg.connect(
        **common,
        user="unlabel_migrator",
        password=admin_password,
        dbname="unlabel_auth",
    ) as connection:
        if not connection.execute(
            "SELECT 1 FROM pg_roles WHERE rolname='unlabel_guest_gc'"
        ).fetchone():
            connection.execute(
                "CREATE ROLE unlabel_guest_gc LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE "
                "NOREPLICATION NOINHERIT"
            )
        connection.execute(
            sql.SQL("ALTER ROLE unlabel_guest_gc PASSWORD {}").format(
                sql.Literal(password)
            )
        )
        connection.execute("GRANT CONNECT ON DATABASE unlabel_auth TO unlabel_guest_gc")
    with psycopg.connect(
        **common,
        user="unlabel_auth",
        password=(directory / "pg-auth-admin").read_text().strip(),
        dbname="unlabel_auth",
    ) as connection:
        applied = migrate(connection, ROOT / "backend/migrations/identity")
        connection.execute("GRANT USAGE ON SCHEMA auth_maintenance TO unlabel_guest_gc")
        connection.execute(
            "GRANT EXECUTE ON FUNCTION auth_maintenance.prune_inactive_guests(), "
            "auth_maintenance.guest_cleanup_healthy() TO unlabel_guest_gc"
        )
    dsn = make_conninfo(
        **common, user="unlabel_guest_gc", password=password, dbname="unlabel_auth"
    )
    with psycopg.connect(dsn) as connection:
        removed = connection.execute(
            "SELECT auth_maintenance.prune_inactive_guests()"
        ).fetchone()[0]
        assert connection.execute(
            "SELECT auth_maintenance.guest_cleanup_healthy()"
        ).fetchone()[0]
    print(
        f"Identity migrations applied: {len(applied)}; expired guests removed: {removed}."
    )
    print(
        "Restricted cleanup role verified. Refresh and verify the encrypted secret backup."
    )


if __name__ == "__main__":
    try:
        main()
    except (psycopg.Error, OSError, ValueError, AssertionError):
        raise SystemExit(
            "Guest cleanup setup failed; credentials were not printed."
        ) from None
