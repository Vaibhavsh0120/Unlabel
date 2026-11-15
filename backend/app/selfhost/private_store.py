"""Owner-scoped PostgreSQL library snapshots and browser push subscriptions."""

import base64
import hashlib
import re
from contextlib import contextmanager
from datetime import UTC, datetime, timedelta
from uuid import UUID

import psycopg
from psycopg.types.json import Jsonb

from app.accounts.models import PersonalData, SyncSnapshot
from app.accounts.store import SyncConflict, SyncDeleted
from app.community.store import StoreQuotaExceeded, StoreUnavailable
from app.notifications import PushSubscription
from app.selfhost.catalogue import canonical
from app.selfhost.profile import MAX_PROFILE_REVISION, ProfileSnapshot, avatar_bytes


@contextmanager
def storage_connection(pool):
    try:
        with pool.connection() as connection:
            yield connection
    except psycopg.Error:
        raise StoreUnavailable() from None


@contextmanager
def owner_connection(pool, owner):
    """Serialize profile/library changes and deletion with the same owner lock."""
    if not isinstance(owner, str) or re.fullmatch(r"[0-9a-f]{64}", owner) is None:
        raise StoreUnavailable()
    with storage_connection(pool) as connection:
        connection.execute("SELECT pg_advisory_xact_lock(hashtextextended(%s,0))", (owner,))
        if connection.execute(
            "SELECT 1 FROM accounts.deletion_markers WHERE owner_hash=%s", (owner,)
        ).fetchone():
            raise SyncDeleted()
        yield connection


def owner_user(connection, owner):
    user = connection.execute(
        "SELECT id FROM accounts.users WHERE owner_hash=%s AND deleted_at IS NULL FOR UPDATE",
        (owner,),
    ).fetchone()
    if user is None:
        raise SyncDeleted()
    return user[0]


class PostgresProfileStore:
    def __init__(self, pool):
        self.pool = pool

    @staticmethod
    def snapshot(row):
        if row is None:
            return ProfileSnapshot()
        try:
            return ProfileSnapshot(
                revision=row[0],
                display_name=row[1],
                gender=row[2],
                avatar_png_base64=base64.b64encode(bytes(row[3])).decode("ascii")
                if row[3]
                else None,
                avatar_source=row[4],
                updated_at=row[5],
            )
        except (ValueError, TypeError):
            raise StoreUnavailable() from None

    def read(self, owner):
        with owner_connection(self.pool, owner) as connection:
            identifier = owner_user(connection, owner)
            row = connection.execute(
                """SELECT revision,display_name,gender,avatar_png,avatar_source,updated_at
                FROM accounts.profiles WHERE owner_id=%s""",
                (identifier,),
            ).fetchone()
            return self.snapshot(row)

    def replace(self, owner, body):
        binary = avatar_bytes(body.avatar_png_base64)
        with owner_connection(self.pool, owner) as connection:
            identifier = owner_user(connection, owner)
            old = connection.execute(
                "SELECT revision,avatar_png,avatar_source FROM accounts.profiles WHERE owner_id=%s",
                (identifier,),
            ).fetchone()
            revision = old[0] if old else 0
            if body.expected_revision != revision:
                raise SyncConflict(revision)
            if revision >= MAX_PROFILE_REVISION:
                raise StoreQuotaExceeded()
            source = "default" if binary is None else "custom"
            if old and binary is not None and old[1] == binary and old[2] == "google":
                source = "google"  # Preserve only a previously trusted provider avatar.
            row = connection.execute(
                """INSERT INTO accounts.profiles
                    (owner_id,revision,display_name,gender,avatar_png,avatar_source)
                VALUES(%s,%s,%s,%s,%s,%s) ON CONFLICT(owner_id) DO UPDATE SET
                    revision=excluded.revision,display_name=excluded.display_name,
                    gender=excluded.gender,avatar_png=excluded.avatar_png,
                    avatar_source=excluded.avatar_source,updated_at=now()
                RETURNING revision,display_name,gender,avatar_png,avatar_source,updated_at""",
                (identifier, revision + 1, body.display_name, body.gender, binary, source),
            ).fetchone()
            return self.snapshot(row)


class PostgresPersonalStore:
    def __init__(self, pool, delete_identity, notification_owner=None):
        self.pool = pool
        self.delete_identity = delete_identity
        self.notification_owner = notification_owner

    @staticmethod
    def snapshot(row):
        if not row:
            return SyncSnapshot()
        return SyncSnapshot(
            revision=row[0],
            updated_at=row[1],
            data=PersonalData.model_validate_json(canonical(row[2])),
        )

    def read(self, owner):
        with owner_connection(self.pool, owner) as c:
            owner_user(c, owner)
            row = c.execute(
                """SELECT s.revision,s.updated_at,s.payload FROM accounts.users u
                JOIN accounts.library_snapshots s ON s.owner_id=u.id WHERE u.owner_hash=%s""",
                (owner,),
            ).fetchone()
            return self.snapshot(row)

    def replace(self, owner, body):
        payload = body.data.model_dump(mode="json")
        digest = hashlib.sha256(canonical(payload)).hexdigest()
        with owner_connection(self.pool, owner) as c:
            user_id = owner_user(c, owner)
            row = c.execute(
                """SELECT revision,updated_at,payload,mutation_id,expected_revision,payload_sha256
                FROM accounts.library_snapshots WHERE owner_id=%s""",
                (user_id,),
            ).fetchone()
            revision = row[0] if row else 0
            if row and row[3] == body.mutation_id:
                if row[4] != body.expected_revision or row[5] != digest:
                    raise SyncConflict(revision)
                return self.snapshot(row)
            if body.expected_revision != revision:
                raise SyncConflict(revision)
            result = c.execute(
                """INSERT INTO accounts.library_snapshots
                (owner_id,revision,mutation_id,expected_revision,payload,payload_sha256)
                VALUES(%s,%s,%s,%s,%s,%s) ON CONFLICT(owner_id) DO UPDATE SET
                revision=excluded.revision,mutation_id=excluded.mutation_id,
                expected_revision=excluded.expected_revision,payload=excluded.payload,
                payload_sha256=excluded.payload_sha256,updated_at=now()
                RETURNING revision,updated_at,payload""",
                (user_id, revision + 1, body.mutation_id, revision, Jsonb(payload), digest),
            ).fetchone()
            return self.snapshot(result)

    def delete(self, owner, uid):
        if not isinstance(owner, str) or re.fullmatch(r"[0-9a-f]{64}", owner) is None:
            raise StoreUnavailable()
        with storage_connection(self.pool) as c:
            c.execute("SELECT pg_advisory_xact_lock(hashtextextended(%s,0))", (owner,))
            user = c.execute(
                "SELECT id FROM accounts.users WHERE owner_hash=%s FOR UPDATE", (owner,)
            ).fetchone()
            marker = c.execute(
                "SELECT 1 FROM accounts.deletion_markers WHERE owner_hash=%s", (owner,)
            ).fetchone()
            if user and user[0] != UUID(uid) or not user and not marker:
                raise SyncDeleted()
            c.execute(
                "INSERT INTO accounts.deletion_markers(owner_hash) VALUES(%s) ON CONFLICT DO NOTHING",
                (owner,),
            )
            c.execute("DELETE FROM accounts.library_snapshots WHERE owner_id=%s", (UUID(uid),))
            c.execute("DELETE FROM accounts.profiles WHERE owner_id=%s", (UUID(uid),))
            if self.notification_owner is not None:
                c.execute(
                    "DELETE FROM operations.push_subscriptions WHERE owner_hash=%s",
                    (self.notification_owner(uid),),
                )
            c.execute("DELETE FROM accounts.users WHERE id=%s", (UUID(uid),))
        # A permanent marker commits first, so transient auth-provider failure
        # cannot restore private data. A recent owner token may retry deletion.
        self.delete_identity(uid)


class PostgresNotifications:
    def __init__(self, pool):
        self.pool = pool

    @staticmethod
    def key(subscription):
        return hashlib.sha256(subscription.endpoint.encode()).hexdigest()

    def change(self, actor, body):
        key = self.key(body.subscription)
        value = body.subscription.model_dump()
        with storage_connection(self.pool) as c:
            # Endpoint capability and actor locks cover creation as well as update.
            # Different actors racing an unseen endpoint cannot bypass key checks.
            c.execute("SELECT pg_advisory_xact_lock(hashtextextended(%s,1))", (key,))
            c.execute("SELECT pg_advisory_xact_lock(hashtextextended(%s,0))", (actor,))
            old = c.execute(
                "SELECT subscription,owner_hash FROM operations.push_subscriptions WHERE id=%s FOR UPDATE",
                (key,),
            ).fetchone()
            if old and old[0] != value:
                raise StoreUnavailable()
            if not body.enabled:
                c.execute("DELETE FROM operations.push_subscriptions WHERE id=%s", (key,))
                return
            if not old or old[1] != actor:
                if (
                    c.execute(
                        "SELECT count(*) FROM operations.push_subscriptions WHERE owner_hash=%s",
                        (actor,),
                    ).fetchone()[0]
                    >= 3
                ):
                    raise StoreQuotaExceeded()
            if not old:
                c.execute(
                    """INSERT INTO operations.push_subscriptions(id,owner_hash,subscription)
                    VALUES(%s,%s,%s) ON CONFLICT(id) DO NOTHING""",
                    (key, actor, Jsonb(value)),
                )
            else:
                c.execute(
                    """UPDATE operations.push_subscriptions SET owner_hash=%s,
                    enabled=true,updated_at=now() WHERE id=%s""",
                    (actor, key),
                )

    def claim(self, subscription, *, test):
        key = self.key(subscription)
        with storage_connection(self.pool) as c:
            row = c.execute(
                """SELECT subscription,last_test_at,last_delivered_day
                FROM operations.push_subscriptions WHERE id=%s AND enabled FOR UPDATE""",
                (key,),
            ).fetchone()
            if not row or row[0] != subscription.model_dump():
                return False
            now = datetime.now(UTC)
            if test:
                if row[1] and now - row[1] < timedelta(minutes=1):
                    raise StoreQuotaExceeded()
                c.execute(
                    "UPDATE operations.push_subscriptions SET last_test_at=now() WHERE id=%s",
                    (key,),
                )
            else:
                if row[2] == now.date():
                    return False
                c.execute(
                    "UPDATE operations.push_subscriptions SET last_delivered_day=current_date WHERE id=%s",
                    (key,),
                )
            return True

    def subscriptions(self):
        with self.pool.connection() as c:
            return [
                PushSubscription.model_validate(row[0])
                for row in c.execute(
                    "SELECT subscription FROM operations.push_subscriptions WHERE enabled ORDER BY id LIMIT 10000"
                )
            ]

    def remove(self, subscription):
        with self.pool.connection() as c:
            c.execute(
                "DELETE FROM operations.push_subscriptions WHERE id=%s AND subscription=%s",
                (self.key(subscription), Jsonb(subscription.model_dump())),
            )

    def schedule(self):
        with self.pool.connection() as c:
            # Statement idempotency makes overlapping schedulers harmless. Work
            # is queued once per subscription/day and survives Redis loss.
            return c.execute("""INSERT INTO operations.outbox(topic,idempotency_key,payload)
                SELECT 'notifications.deliver','reminder:'||current_date::text||':'||id,
                    jsonb_build_object('reference',id) FROM operations.push_subscriptions
                WHERE enabled AND (last_delivered_day IS NULL OR last_delivered_day<current_date)
                AND current_time >= time '13:30:00' ON CONFLICT(topic,idempotency_key) DO NOTHING""").rowcount
