"""Server preparation and private ownership hashes for immutable submissions."""

import hashlib
import hmac
import json

from app.catalogue.facts import FactsLookup
from app.community.models import (
    CommunityRevision,
    ContributionFacts,
    ContributionRequest,
    PreparedContribution,
)
from app.services.parsing.nutrition import normalize_rows


def contribution_facts(request: ContributionRequest) -> ContributionFacts:
    fields = set(ContributionFacts.model_fields)
    return ContributionFacts.model_validate(request.model_dump(include=fields))


def canonical_content(request: ContributionRequest) -> bytes:
    """Canonical public assertion; random request IDs do not change its content."""
    return json.dumps(
        request.model_dump(mode="json", exclude={"submission_id"}),
        sort_keys=True,
        ensure_ascii=False,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")


def content_hash(request: ContributionRequest) -> str:
    return hashlib.sha256(canonical_content(request)).hexdigest()


def factual_hash(request: ContributionRequest) -> str:
    """Deduplicate facts; dates and review state belong to separate observations.

    Table membership/context is preserved while opaque client table/row IDs and
    ordering do not create new facts. Ingredient text remains ordered verbatim.
    """
    facts = contribution_facts(request).model_dump(
        mode="json", exclude={"observed_on", "capture_method", "rows"}
    )
    tables: dict[str, list[dict]] = {}
    for row in request.rows:
        tables.setdefault(row.table_id, []).append(
            row.model_dump(mode="json", exclude={"row_id", "table_id"})
        )

    def encode(value: object) -> str:
        return json.dumps(
            value, sort_keys=True, ensure_ascii=False, separators=(",", ":"), allow_nan=False
        )

    facts["tables"] = sorted([sorted(rows, key=encode) for rows in tables.values()], key=encode)
    facts["front_claims"] = sorted(set(request.front_claims))
    facts["provider_references"] = sorted(facts["provider_references"], key=encode)
    return hashlib.sha256(encode(facts).encode("utf-8")).hexdigest()


def verify_provider_references(body: ContributionRequest, snapshot: FactsLookup | None) -> None:
    for reference in body.provider_references:
        if (
            snapshot is None
            or snapshot.status != "found"
            or snapshot.manifest is None
            or snapshot.requested_barcode != reference.barcode
            or snapshot.manifest.snapshot_id != reference.source_id
        ):
            raise ValueError("Provider reference does not match the available snapshot")


def prepare_submission(
    body: ContributionRequest, snapshot: FactsLookup | None = None
) -> PreparedContribution:
    if snapshot is not None:
        verify_provider_references(body, snapshot)
    normalized = normalize_rows(body.rows, completeness=body.nutrition_completeness)
    if normalized.status == "needs_correction" and body.observation_state == "confirmed":
        raise ValueError("Nutrition needs correction before contribution")
    eligible = (
        body.observation_state == "confirmed"
        and body.barcode is not None
        and body.confirmed
        and body.front_confirmed
        and body.back_confirmed
        and body.same_product_confirmed
        and normalized.status != "needs_correction"
    )
    return PreparedContribution(
        request=body,
        content_sha256=content_hash(body),
        factual_sha256=factual_hash(body),
        snapshot=normalized,
        auto_eligible=eligible,
    )


def contribution_conflicts(
    prepared: PreparedContribution,
    revisions: list[CommunityRevision],
    snapshot: FactsLookup | None = None,
) -> bool:
    from app.community.resolver import contribution_conflicts as resolver_conflicts

    return resolver_conflicts(prepared, revisions, snapshot)


def actor_hash(uid: str, secret: str) -> str:
    """A backend secret prevents public hashes from exposing authentication IDs."""
    if not isinstance(uid, str) or not uid or len(uid) > 128:
        raise ValueError("Authenticated subject is invalid")
    if not isinstance(secret, str) or len(secret) < 32:
        raise ValueError("Ownership hashing requires a secret of at least 32 characters")
    return hmac.new(secret.encode("utf-8"), uid.encode("utf-8"), hashlib.sha256).hexdigest()
