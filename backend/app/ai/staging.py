"""Bounded private machine proposals, separate from confirmed public facts.

No photos, regions/raw OCR, provider envelopes, credentials or identities enter
this store. Fixed buckets bound storage; these proposals are not a durable user
library or a public product lookup. Confirmed contributions use the existing
immutable community admission path.
"""

import hashlib
import json
import re
from datetime import UTC, datetime, timedelta
from typing import Literal

from pydantic import AwareDatetime, BaseModel, ConfigDict, Field

from app.ai.models import ExtractedLabel
from app.community.store import FirestoreContributionStore, StoreUnavailable

MAX_FACT_BYTES = 32768
MAX_BUCKET_ITEMS = 8


class StagingResult(BaseModel):
    status: Literal["private_unverified", "not_stored"]
    content_sha256: str | None = None
    reason: Literal["too_large", "unavailable"] | None = None
    deduplicated: bool = False


class _Item(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    owner: str = Field(pattern=r"^[0-9a-f]{64}$")
    content_sha256: str = Field(pattern=r"^[0-9a-f]{64}$")
    facts_json: str = Field(max_length=MAX_FACT_BYTES)
    created_at: AwareDatetime


def stage_machine_facts(
    transactions: FirestoreContributionStore, actor: str, label: ExtractedLabel,
    *, now: datetime | None = None,
) -> StagingResult:
    if re.fullmatch(r"[0-9a-f]{64}", actor) is None:
        raise StoreUnavailable()
    # Retain literal structured values, unknowns and qualifiers. Exclude geometry
    # and its line text, which are only needed in the current photo session.
    facts = json.dumps(label.model_dump(mode="json", exclude={"regions"}),
                       sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    encoded = facts.encode("utf-8")
    if len(encoded) > MAX_FACT_BYTES:
        return StagingResult(status="not_stored", reason="too_large")
    digest = hashlib.sha256(encoded).hexdigest()
    date = now or datetime.now(UTC)
    if date.tzinfo is None:
        raise StoreUnavailable()
    reference = transactions._ref(
        "unlabel_machine_staging", hashlib.sha256(actor.encode()).hexdigest()[:2],
    )

    def apply(transaction):
        record = transactions._batch([reference], transaction)[reference.path]
        try:
            if record is None:
                items = []
            else:
                if (not isinstance(record, dict) or set(record) != {"schema_version", "items"}
                        or record["schema_version"] != "1" or not isinstance(record["items"], list)
                        or len(record["items"]) > MAX_BUCKET_ITEMS):
                    raise ValueError("Invalid staging bucket")
                items = [_Item.model_validate(item) for item in record["items"]]
                if any(len(item.facts_json.encode("utf-8")) > MAX_FACT_BYTES or
                       hashlib.sha256(item.facts_json.encode("utf-8")).hexdigest() != item.content_sha256
                       for item in items):
                    raise ValueError("Invalid staging content")
        except (TypeError, ValueError):
            raise StoreUnavailable() from None
        items = [item for item in items if item.created_at > date - timedelta(days=7)]
        if any(item.owner == actor and item.content_sha256 == digest for item in items):
            return StagingResult(status="private_unverified", content_sha256=digest, deduplicated=True)
        items.append(_Item(owner=actor, content_sha256=digest, facts_json=facts, created_at=date))
        items.sort(key=lambda item: item.created_at)
        transaction.set(reference, {"schema_version": "1", "items": [
            item.model_dump() for item in items[-MAX_BUCKET_ITEMS:]
        ]})
        return StagingResult(status="private_unverified", content_sha256=digest)

    return transactions._run(apply)
