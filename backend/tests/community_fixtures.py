"""Synthetic public package assertions for community boundary tests."""

from datetime import UTC, datetime
from uuid import UUID

CODE = "0123456789012"
SUBMISSION_ID = UUID("10000000-0000-4000-8000-000000000001")
NOW = datetime(2026, 10, 7, 12, 0, tzinfo=UTC)


def contribution_dict(**changes):
    payload = {
        "submission_id": str(SUBMISSION_ID),
        "barcode": CODE,
        "observation_state": "confirmed",
        "identity": {
            "name": "Synthetic community oats",
            "brand": "Synthetic test brand",
            "variant": "Plain",
            "quantity": "300 g",
            "language": "en",
        },
        "ingredients": {
            "status": "present",
            "text": "Oats, milk",
            "completeness": "complete",
            "origin": "independently_transcribed_package",
        },
        "contains": {
            "status": "present",
            "text": "Milk",
            "completeness": "complete",
            "origin": "independently_transcribed_package",
        },
        "may_contain": {
            "status": "not_observed",
            "text": None,
            "completeness": "complete",
            "origin": "independently_transcribed_package",
        },
        "front_claims": ["High fibre"],
        "rows": [
            {
                "row_id": "sugar",
                "table_id": "back-table",
                "nutrient": "sugars",
                "value": 0,
                "unit": "g",
                "basis": {"kind": "quantity", "amount": 100, "unit": "g"},
                "preparation": "as_sold",
            }
        ],
        "nutrition_completeness": "partial",
        "nutrition_origin": "independently_transcribed_package",
        "revision_context": "Printed formulation v1",
        "observed_on": "2026-10-07",
        "capture_method": "manual",
        "confirmed": True,
        "front_confirmed": True,
        "back_confirmed": True,
        "same_product_confirmed": True,
        "share_license": "CC0-1.0",
        "market": "india",
    }
    return {**payload, **changes}


def contribution_request(**changes):
    from app.community.models import ContributionRequest

    return ContributionRequest.model_validate(contribution_dict(**changes))


def approved_revision(**changes):
    from app.community.models import CommunityRevision
    from app.community.service import contribution_facts, prepare_submission

    prepared = prepare_submission(contribution_request(**changes))
    assert prepared.request.barcode is not None
    return CommunityRevision(
        revision_id="a" * 64,
        content_sha256=prepared.content_sha256,
        factual_sha256=prepared.factual_sha256,
        barcode=prepared.request.barcode,
        submitted_at=NOW,
        reviewed_at=NOW,
        facts=contribution_facts(prepared.request),
        snapshot=prepared.snapshot,
    )


def candidate_revision(**changes):
    return approved_revision(**changes).model_copy(
        update={"reviewed_at": None, "review_state": "submitter_confirmed_not_moderator_reviewed"}
    )
