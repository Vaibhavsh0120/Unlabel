"""Real PostgreSQL tests in a disposable database, never an existing user database.

Set UNLABEL_TEST_POSTGRES_ADMIN_DSN to a local development or SSH-tunnel bootstrap
connection. The role must be able to create a temporary database and test role.
"""

import os
from pathlib import Path
from uuid import uuid4

import pytest

psycopg = pytest.importorskip("psycopg")
sql = psycopg.sql
make_conninfo = psycopg.conninfo.make_conninfo

MIGRATION = Path(__file__).resolve().parents[2] / "migrations/identity/0001_inactive_guests.sql"


@pytest.fixture(scope="module")
def database():
    dsn = os.environ.get("UNLABEL_TEST_POSTGRES_ADMIN_DSN")
    if not dsn:
        pytest.skip("An explicit disposable-database bootstrap connection is required")
    name = "unlabel_test_guest_" + uuid4().hex
    role = "guest_test_" + uuid4().hex
    with psycopg.connect(dsn, autocommit=True) as admin:
        admin.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(name)))
        try:
            admin.execute(sql.SQL("CREATE ROLE {} NOLOGIN").format(sql.Identifier(role)))
            test_dsn = make_conninfo(dsn, dbname=name)
            with psycopg.connect(test_dsn) as connection:
                connection.execute("""
                    CREATE SCHEMA auth;
                    CREATE TABLE auth.users (
                        id uuid PRIMARY KEY, is_anonymous boolean,
                        created_at timestamptz, updated_at timestamptz,
                        last_sign_in_at timestamptz, email text, phone text);
                    CREATE TABLE auth.identities (
                        id uuid PRIMARY KEY, user_id uuid REFERENCES auth.users ON DELETE CASCADE);
                    CREATE TABLE auth.sessions (
                        id uuid PRIMARY KEY, user_id uuid REFERENCES auth.users ON DELETE CASCADE,
                        created_at timestamptz, updated_at timestamptz, refreshed_at timestamptz);
                    CREATE TABLE auth.refresh_tokens (
                        id uuid PRIMARY KEY, session_id uuid REFERENCES auth.sessions ON DELETE CASCADE);
                """)
                connection.execute(MIGRATION.read_text(), prepare=False)
                connection.execute(
                    (MIGRATION.parent / "0003_weekly_guest_retention.sql").read_text(),
                    prepare=False,
                )
                connection.execute(
                    sql.SQL("GRANT USAGE ON SCHEMA auth_maintenance TO {}").format(
                        sql.Identifier(role)
                    )
                )
                connection.execute(
                    sql.SQL(
                        "GRANT EXECUTE ON FUNCTION "
                        "auth_maintenance.prune_inactive_guests(), "
                        "auth_maintenance.guest_cleanup_healthy() TO {}"
                    ).format(sql.Identifier(role))
                )
            yield test_dsn, role
        finally:
            admin.execute(sql.SQL("DROP DATABASE {} WITH (FORCE)").format(sql.Identifier(name)))
            admin.execute(sql.SQL("DROP ROLE IF EXISTS {}").format(sql.Identifier(role)))


@pytest.fixture
def connection(database):
    with psycopg.connect(database[0]) as connection:
        yield connection
        connection.rollback()
        connection.execute("TRUNCATE auth.users, auth_maintenance.runs CASCADE")


def user(connection, *, hours=192, anonymous=True, email=None, phone=None):
    identity = uuid4()
    connection.execute(
        """INSERT INTO auth.users
        (id,is_anonymous,created_at,updated_at,last_sign_in_at,email,phone)
        VALUES (%s,%s,now()-%s*interval '1 hour',now()-%s*interval '1 hour',
            now()-%s*interval '1 hour',%s,%s)""",
        (identity, anonymous, hours, hours, hours, email, phone),
    )
    return identity


def session(connection, identity, *, hours=192, refreshed_hours=None):
    identifier = uuid4()
    connection.execute(
        """INSERT INTO auth.sessions VALUES
        (%s,%s,now()-%s*interval '1 hour',now()-%s*interval '1 hour',
         now()-%s*interval '1 hour')""",
        (identifier, identity, hours, hours, hours if refreshed_hours is None else refreshed_hours),
    )
    return identifier


def prune(connection):
    return connection.execute("SELECT auth_maintenance.prune_inactive_guests()").fetchone()[0]


def exists(connection, identifier):
    return bool(
        connection.execute("SELECT 1 FROM auth.users WHERE id=%s", (identifier,)).fetchone()
    )


def test_stale_guest_removed_with_sessions_and_refresh_tokens(connection):
    identifier = user(connection)
    session_id = session(connection, identifier)
    connection.execute("INSERT INTO auth.refresh_tokens VALUES(%s,%s)", (uuid4(), session_id))
    assert prune(connection) == 1
    assert not exists(connection, identifier)
    assert connection.execute("SELECT count(*) FROM auth.sessions").fetchone()[0] == 0
    assert connection.execute("SELECT count(*) FROM auth.refresh_tokens").fetchone()[0] == 0
    assert prune(connection) == 0


@pytest.mark.parametrize("hours", [0, 1, 167.99])
def test_recent_guest_preserved(connection, hours):
    identifier = user(connection, hours=hours)
    assert prune(connection) == 0
    assert exists(connection, identifier)


def test_recent_refresh_in_any_session_preserves_guest(connection):
    identifier = user(connection)
    session(connection, identifier)
    session(connection, identifier, refreshed_hours=0)
    assert prune(connection) == 0
    assert exists(connection, identifier)


@pytest.mark.parametrize(
    "values",
    [
        {"anonymous": False},
        {"email": "synthetic@example.invalid"},
        {"phone": "+10000000000"},
    ],
)
def test_converted_or_linking_account_preserved(connection, values):
    identifier = user(connection, hours=1000, **values)
    assert prune(connection) == 0
    assert exists(connection, identifier)


def test_provider_identity_preserves_guest_even_before_conversion_flag(connection):
    identifier = user(connection)
    connection.execute("INSERT INTO auth.identities VALUES(%s,%s)", (uuid4(), identifier))
    assert prune(connection) == 0
    assert exists(connection, identifier)


def test_execution_is_bounded(connection):
    for _ in range(105):
        user(connection)
    assert prune(connection) == 100
    assert prune(connection) == 0
    connection.execute("UPDATE auth_maintenance.runs SET completed_at=now()-interval '25 hours'")
    assert prune(connection) == 5


def test_scheduler_has_execute_only_access(connection, database):
    user(connection)
    connection.execute(sql.SQL("SET ROLE {}").format(sql.Identifier(database[1])))
    assert prune(connection) == 1
    assert connection.execute("SELECT auth_maintenance.guest_cleanup_healthy()").fetchone()[0]
    with pytest.raises(psycopg.errors.InsufficientPrivilege), connection.transaction():
        connection.execute("SELECT * FROM auth.users")
    with pytest.raises(psycopg.errors.InsufficientPrivilege), connection.transaction():
        connection.execute("DELETE FROM auth.users")
    connection.execute("RESET ROLE")


@pytest.mark.parametrize("locked", ["user", "session"])
def test_login_or_refresh_in_flight_is_skipped(connection, database, locked):
    identifier = user(connection)
    session_id = session(connection, identifier)
    connection.commit()
    with psycopg.connect(database[0]) as other:
        if locked == "user":
            other.execute("SELECT id FROM auth.users WHERE id=%s FOR UPDATE", (identifier,))
        else:
            other.execute("SELECT id FROM auth.sessions WHERE id=%s FOR UPDATE", (session_id,))
        assert prune(connection) == 0
        assert exists(connection, identifier)
        connection.commit()
    assert prune(connection) == 0  # A skipped locked row is reconsidered on the next daily run.
    connection.execute("UPDATE auth_maintenance.runs SET completed_at=now()-interval '25 hours'")
    assert prune(connection) == 1


def test_parallel_scheduler_does_not_duplicate_work(connection, database):
    identifier = user(connection)
    connection.commit()
    with psycopg.connect(database[0]) as other:
        other.execute("SELECT pg_advisory_xact_lock(842317225)")
        assert prune(connection) == 0
        assert exists(connection, identifier)
        connection.commit()
    assert prune(connection) == 1
