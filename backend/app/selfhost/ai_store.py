"""PostgreSQL transactions for the existing bounded, unverified AI policy.

Only structured metadata/facts enter these tables. The public observation is
append-only and enqueued atomically for the separate Mongo evidence archive.
"""

import hashlib
import json
import re
from dataclasses import dataclass
from datetime import datetime

from psycopg.types.json import Jsonb

from app.ai.observations import MachineObservation
from app.ai.staging import stage_machine_facts
from app.ai.store import TransactionalAiSelectionStore
from app.community.store import StoreUnavailable
from app.selfhost.private_store import storage_connection

AI_LOCK = 842317225
_KEYS = {
    "unlabel_service_configuration": r"ai-active",
    "unlabel_ai_limits": r"(?:global|actor-[0-9a-f]{2})",
    "unlabel_machine_staging": r"[0-9a-f]{2}",
    "unlabel_machine_products": r"(?:[0-9]{8}|[0-9]{12,14})",
    "unlabel_machine_limits": r"lifetime",
    "unlabel_machine_observations": r"[0-9a-f]{64}",
}


def _json(value):
    def default(item):
        if isinstance(item, datetime) and item.tzinfo is not None:
            return item.isoformat()
        raise TypeError("Unsupported AI metadata")

    return json.dumps(value, default=default, ensure_ascii=False, allow_nan=False,
                      sort_keys=True, separators=(",", ":"))


@dataclass(frozen=True)
class _Reference:
    collection: str
    id: str

    @property
    def path(self):
        return self.collection + "/" + self.id


class _Transaction:
    def __init__(self, connection):
        self.connection = connection

    def set(self, reference, value):
        if reference.collection == "unlabel_machine_observations":
            raise StoreUnavailable()
        self.connection.execute(
            """INSERT INTO ai.documents(collection,key,value) VALUES(%s,%s,%s)
            ON CONFLICT(collection,key) DO UPDATE SET value=excluded.value""",
            (reference.collection, reference.id, Jsonb(value, dumps=_json)),
        )

    def create(self, reference, value):
        if reference.collection != "unlabel_machine_observations":
            raise StoreUnavailable()
        try:
            observation = MachineObservation.model_validate_json(value["payload_json"])
            digest = hashlib.sha256(value["payload_json"].encode()).hexdigest()
            if reference.id != observation.observation_id or value["record_sha256"] != digest:
                raise ValueError()
        except (ValueError, KeyError, TypeError):
            raise StoreUnavailable() from None
        self.connection.execute(
            "INSERT INTO ai.observations(id,value) VALUES(%s,%s)",
            (reference.id, Jsonb(value)),
        )
        # Topic remains the existing evidence worker's leased queue. The stream
        # discriminator prevents machine facts becoming community assertions.
        self.connection.execute(
            """INSERT INTO operations.outbox(topic,idempotency_key,payload)
            VALUES('evidence.project',%s,%s)
            ON CONFLICT(topic,idempotency_key) DO NOTHING""",
            ("machine:" + reference.id, Jsonb({"reference": reference.id, "stream": "machine"})),
        )


class PostgresAiDocuments:
    def __init__(self, pool, actor=None):
        self.pool = pool
        self.actor = actor

    def _ref(self, collection, key):
        pattern = _KEYS.get(collection)
        if pattern is None or not isinstance(key, str) or re.fullmatch(pattern, key) is None:
            raise StoreUnavailable()
        return _Reference(collection, key)

    def _batch(self, references, transaction=None):
        if transaction is None or len(references) > 8:
            raise StoreUnavailable()
        result = {}
        try:
            for reference in references:
                if reference.collection == "unlabel_machine_observations":
                    row = transaction.connection.execute(
                        "SELECT value FROM ai.observations WHERE id=%s", (reference.id,),
                    ).fetchone()
                else:
                    row = transaction.connection.execute(
                        "SELECT value FROM ai.documents WHERE collection=%s AND key=%s",
                        (reference.collection, reference.id),
                    ).fetchone()
                value = row[0] if row else None
                # The legacy policy validates aware datetime objects strictly.
                # Decode only these schema-owned fields, never arbitrary text.
                if value is not None and reference.collection == "unlabel_service_configuration":
                    value["blocked_until"] = {
                        key: datetime.fromisoformat(until)
                        for key, until in value["blocked_until"].items()
                    }
                if value is not None and reference.collection == "unlabel_machine_staging":
                    for item in value["items"]:
                        item["created_at"] = datetime.fromisoformat(item["created_at"])
                result[reference.path] = value
        except (TypeError, KeyError, ValueError):
            raise StoreUnavailable() from None
        return result

    def _run(self, callback):
        with storage_connection(self.pool) as connection:
            # Shared lock covers absent-row creation, quotas and public pointers,
            # including the private staging purge during account deletion. No
            # network/provider operation runs inside this bounded transaction.
            connection.execute("SELECT pg_advisory_xact_lock(%s)", (AI_LOCK,))
            if self.actor is not None and connection.execute(
                "SELECT 1 FROM accounts.deletion_markers WHERE actor_hash=%s", (self.actor,),
            ).fetchone():
                raise StoreUnavailable()
            return callback(_Transaction(connection))


class PostgresAiSelectionStore(TransactionalAiSelectionStore):
    def __init__(self, pool, clock=None):
        super().__init__(PostgresAiDocuments(pool), clock)
        self.pool = pool

    def stage(self, actor, label):
        return stage_machine_facts(PostgresAiDocuments(self.pool, actor), actor, label, now=self._now())

    def admit(self, actor, *, daily_limit, actor_limit):
        guarded = TransactionalAiSelectionStore(PostgresAiDocuments(self.pool, actor), self._clock)
        guarded.admit(actor, daily_limit=daily_limit, actor_limit=actor_limit)


def delete_actor_staging(connection, actor):
    """Caller owns account lock; acquire AI lock second, as all deletion paths do."""
    if not isinstance(actor, str) or re.fullmatch(r"[0-9a-f]{64}", actor) is None:
        raise StoreUnavailable()
    connection.execute("SELECT pg_advisory_xact_lock(%s)", (AI_LOCK,))
    bucket = hashlib.sha256(actor.encode()).hexdigest()[:2]
    connection.execute(
        """UPDATE ai.documents SET value=jsonb_set(value,'{items}',
        COALESCE((SELECT jsonb_agg(item) FROM jsonb_array_elements(value->'items') item
        WHERE item->>'owner'<>%s),'[]'::jsonb))
        WHERE collection='unlabel_machine_staging' AND key=%s""",
        (actor, bucket),
    )
