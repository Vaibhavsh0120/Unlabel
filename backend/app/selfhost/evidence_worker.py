"""Archive public community observations to MongoDB through durable PostgreSQL jobs."""

import argparse
import hashlib
import logging
import signal

from psycopg.rows import dict_row
from pydantic import SecretStr
from pymongo import MongoClient
from pymongo.errors import DuplicateKeyError

from app.community.models import CommunityRevision
from app.community.store import _identifier
from app.selfhost.catalogue import canonical
from app.selfhost.community_store import EVIDENCE_TOPIC
from app.selfhost.worker import LeaseLost, Worker, connection_pool, healthy
from app.selfhost.worker_settings import SchedulerSettings


class EvidenceSettings(SchedulerSettings):
    mongo_url: SecretStr


def archive_observation(collection, reference, document, digest):
    _identifier(reference)
    _identifier(digest)
    if not isinstance(document, dict) or hashlib.sha256(canonical(document)).hexdigest() != digest:
        raise ValueError("Invalid community evidence digest")
    revision = CommunityRevision.model_validate_json(
        canonical(
            document
            | {
                "reviewed_at": None,
                "review_state": "submitter_confirmed_not_moderator_reviewed",
            }
        )
    )
    if document != revision.model_dump(mode="json", exclude={"reviewed_at", "review_state"}) or (
        revision.revision_id != reference
    ):
        raise ValueError("Invalid immutable community evidence")
    archived = {"_id": reference, "sha256": digest, "observation": document}
    try:
        collection.insert_one(archived)
    except DuplicateKeyError:
        # A lease could expire after Mongo commits but before PostgreSQL records
        # acknowledgement. Verify the unchanged document before accepting replay.
        if collection.find_one({"_id": reference}) != archived:
            raise ValueError("Immutable community evidence differs") from None


class EvidenceWorker(Worker):
    def __init__(self, pool, settings, collection):
        super().__init__(pool, settings, kind="evidence")
        self.collection = collection

    def tick(self):
        with self.pool.connection() as connection:
            connection.execute("SELECT operations.reap_exhausted()")
            with connection.cursor(row_factory=dict_row) as cursor:
                job = cursor.execute(
                    "SELECT * FROM operations.claim_topic_jobs(%s,%s,1)",
                    (self.worker_id, EVIDENCE_TOPIC),
                ).fetchone()
        if job is None:
            return 0
        try:
            with self.lease(job):
                reference = _identifier(job["payload"]["reference"])
                with self.pool.connection() as connection:
                    item = connection.execute(
                        "SELECT document,sha256 FROM community.publication WHERE revision_id=%s",
                        (reference,),
                    ).fetchone()
                if item is None:
                    raise ValueError("Publication reference is absent")
                archive_observation(self.collection, reference, *item)
            with self.pool.connection() as connection:
                connection.execute(
                    "SELECT operations.complete_job(%s,%s,%s)",
                    (job["id"], self.worker_id, job["lease_token"]),
                )
        except LeaseLost:
            pass
        except Exception:  # noqa: BLE001 - record only bounded, private-data-free error codes.
            with self.pool.connection() as connection:
                connection.execute(
                    "SELECT operations.fail_job(%s,%s,%s,%s)",
                    (job["id"], self.worker_id, job["lease_token"], "evidence_archive_failed"),
                )
        return 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--healthcheck", action="store_true")
    args = parser.parse_args()
    logging.getLogger("psycopg.pool").disabled = True
    try:
        settings = EvidenceSettings()
        with (
            connection_pool(settings) as pool,
            MongoClient(
                settings.mongo_url.get_secret_value(),
                maxPoolSize=3,
                timeoutMS=5000,
                serverSelectionTimeoutMS=3000,
                retryWrites=False,
            ) as mongo,
        ):
            pool.wait(timeout=10)
            database = mongo.get_database("unlabel_evidence")
            database.command("ping")
            if args.healthcheck:
                return 0 if healthy(pool, settings, "evidence") else 1
            worker = EvidenceWorker(pool, settings, database.community_observations)
            signal.signal(signal.SIGTERM, worker.stop)
            signal.signal(signal.SIGINT, worker.stop)
            worker.run()
    except Exception:  # noqa: BLE001 - keep credential details out of container logs.
        if not args.healthcheck:
            print("Evidence worker could not start. Check private configuration.", flush=True)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
