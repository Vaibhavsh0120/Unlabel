import copy
import hashlib
import hmac
import importlib.util
import json
from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from pydantic import ValidationError

from tests.community_fixtures import contribution_dict


def models():
    assert importlib.util.find_spec("app.community") is not None, "community contracts missing"
    from app.community import models

    return models


def service():
    models()
    from app.community import service

    return service


def test_confirmed_public_assertion_roundtrips_without_private_fields():
    request = models().ContributionRequest.model_validate(contribution_dict())
    assert request.identity.name == "Synthetic community oats"
    assert request.rows[0].value == 0
    assert request.contains.text == "Milk"
    assert request.may_contain.status == "not_observed"
    assert models().ContributionRequest.model_validate_json(request.model_dump_json()) == request
    public = service().contribution_facts(request).model_dump()
    assert "submission_id" not in public and "permission_to_share" not in public
    assert "confirmed" not in public
    assert public["ingredients"]["text"] == "Oats, milk"


@pytest.mark.parametrize(
    "field",
    [
        "confirmed",
        "front_confirmed",
        "back_confirmed",
        "same_product_confirmed",
    ],
)
@pytest.mark.parametrize("value", [1, "true", None])
def test_each_confirmation_requires_strict_boolean(field, value):
    with pytest.raises(ValidationError):
        models().ContributionRequest.model_validate(contribution_dict(**{field: value}))


@pytest.mark.parametrize(
    "extra",
    [
        {"photo_url": "https://example.test/image"},
        {"raw_ocr": "private text"},
        {"profile": {"name": "Private"}},
        {"capture_session_id": str(uuid4())},
        {"snapshot": {}},
        {"source_trust": "verified"},
        {"permission_to_share": True},
    ],
)
def test_unaccepted_private_and_server_owned_fields_are_rejected(extra):
    with pytest.raises(ValidationError):
        models().ContributionRequest.model_validate(contribution_dict(**extra))


@pytest.mark.parametrize(
    "extra",
    [
        {"submission_id": 1},
        {"submission_id": "not-a-uuid"},
        {"barcode": "１２３４５６７８"},
        {"barcode": "123456789"},
        {"share_license": "ODbL-1.0"},
        {"market": "world"},
        {"capture_method": "unsupported"},
        {"front_claims": ["x"] * 17},
        {"front_claims": ["x" * 257]},
        {"front_claims": ["High fibre\nprivate"]},
        {"front_claims": ["\ud800"]},
        {"front_claims": [""]},
    ],
)
def test_bounded_public_input_never_coerces_identity(extra):
    with pytest.raises(ValidationError):
        models().ContributionRequest.model_validate(contribution_dict(**extra))


@pytest.mark.parametrize("name", ["", "  ", "x" * 257, "name\x00", "\udfff"])
def test_product_name_is_bounded_visible_public_text(name):
    payload = contribution_dict()
    payload["identity"]["name"] = name
    with pytest.raises(ValidationError):
        models().ContributionRequest.model_validate(payload)


@pytest.mark.parametrize(
    "section",
    [
        {"status": "present", "text": None, "completeness": "complete"},
        {"status": "not_observed", "text": "Milk", "completeness": "complete"},
        {"status": "not_captured", "text": None, "completeness": "complete"},
        {"status": "present", "text": "x" * 16001, "completeness": "partial"},
    ],
)
def test_section_status_and_completeness_preserve_actual_observation(section):
    with pytest.raises(ValidationError):
        models().ContributionRequest.model_validate(contribution_dict(ingredients=section))


def test_no_back_fact_is_rejected_but_observed_absence_does_not_mean_allergen_safe():
    absent = {
        "status": "not_captured",
        "text": None,
        "completeness": "partial",
        "origin": "independently_transcribed_package",
    }
    with pytest.raises(ValidationError):
        models().ContributionRequest.model_validate(
            contribution_dict(rows=[], ingredients=absent, contains=absent, may_contain=absent)
        )
    request = models().ContributionRequest.model_validate(contribution_dict(rows=[]))
    prepared = service().prepare_submission(request)
    assert prepared.snapshot.tables == []
    assert prepared.snapshot.status == "partial"
    assert "nutrition_not_reported" in prepared.snapshot.warnings


def test_rows_are_unique_bounded_and_strict_numbers():
    payload = contribution_dict()
    payload["rows"].append(copy.deepcopy(payload["rows"][0]))
    with pytest.raises(ValidationError):
        models().ContributionRequest.model_validate(payload)
    for value in (True, "0", float("inf"), float("nan"), -1):
        payload = contribution_dict()
        payload["rows"][0]["value"] = value
        with pytest.raises(ValidationError):
            models().ContributionRequest.model_validate(payload)
    with pytest.raises(ValidationError):
        models().ContributionRequest.model_validate(contribution_dict(rows=[{}] * 65))


def test_observation_date_is_not_unbounded_future_or_datetime():
    future = (datetime.now(UTC).date() + timedelta(days=2)).isoformat()
    with pytest.raises(ValidationError):
        models().ContributionRequest.model_validate(contribution_dict(observed_on=future))
    with pytest.raises(ValidationError):
        models().ContributionRequest.model_validate(
            contribution_dict(observed_on=datetime.now(UTC))
        )


def test_server_normalization_preserves_zero_unknown_and_independent_tables():
    payload = contribution_dict()
    unknown = copy.deepcopy(payload["rows"][0])
    unknown.update(row_id="protein", nutrient="protein", value=None)
    volume = copy.deepcopy(payload["rows"][0])
    volume.update(row_id="liquid-sugar", table_id="volume-table", value=5)
    volume["basis"] = {"kind": "quantity", "amount": 200, "unit": "mL"}
    payload["rows"].extend([unknown, volume])
    prepared = service().prepare_submission(models().ContributionRequest.model_validate(payload))
    tables = prepared.snapshot.tables
    assert len(tables) == 2
    assert tables[0].nutrients["sugars"].value == 0
    assert tables[0].nutrients["protein"].value is None
    assert tables[1].nutrients["sugars"].value == 2.5
    assert tables[1].normalized_basis.unit == "mL"


def test_conflicting_normalization_requires_correction_before_storage():
    payload = contribution_dict()
    second = copy.deepcopy(payload["rows"][0])
    second.update(row_id="different-sugar", value=2)
    payload["rows"].append(second)
    with pytest.raises(ValueError, match="correction"):
        service().prepare_submission(models().ContributionRequest.model_validate(payload))


def test_hash_is_canonical_excludes_submission_uuid_and_changes_with_public_facts():
    request = models().ContributionRequest.model_validate(contribution_dict())
    first = service().prepare_submission(request)
    second = service().prepare_submission(
        models().ContributionRequest.model_validate(contribution_dict(submission_id=str(uuid4())))
    )
    assert first.content_sha256 == second.content_sha256
    changed = contribution_dict(front_claims=["Low sugar"])
    assert (
        service()
        .prepare_submission(models().ContributionRequest.model_validate(changed))
        .content_sha256
        != first.content_sha256
    )
    canonical = service().canonical_content(request)
    assert json.loads(canonical)["barcode"] == "0123456789012"
    assert "submission_id" not in json.loads(canonical)
    assert first.content_sha256 == hashlib.sha256(canonical).hexdigest()


def test_private_subject_hash_is_keyed_and_rejects_empty_secrets():
    assert (
        service().actor_hash("firebase-subject", "x" * 32)
        == hmac.new(b"x" * 32, b"firebase-subject", hashlib.sha256).hexdigest()
    )
    assert service().actor_hash("firebase-subject", "x" * 32) != service().actor_hash(
        "firebase-subject", "y" * 32
    )
    for uid, secret in (("", "x" * 32), ("firebase-subject", ""), ("firebase-subject", "short")):
        with pytest.raises(ValueError):
            service().actor_hash(uid, secret)


def test_automatic_confirmation_is_eligible_without_any_sharing_permission_flag():
    request = models().ContributionRequest.model_validate(contribution_dict())
    prepared = service().prepare_submission(request)
    assert prepared.auto_eligible is True
    assert "permission_to_share" not in request.model_dump()
    for field in ("front_confirmed", "back_confirmed", "same_product_confirmed"):
        staged = models().ContributionRequest.model_validate(contribution_dict(**{field: False}))
        assert service().prepare_submission(staged).auto_eligible is False
    with pytest.raises(ValidationError):
        models().ContributionRequest.model_validate(contribution_dict(confirmed=False))


def test_barcode_less_and_uncorrected_observations_can_be_staged_without_public_eligibility():
    provisional = models().ContributionRequest.model_validate(
        contribution_dict(
            barcode=None,
            observation_state="provisional",
            confirmed=False,
            front_confirmed=False,
            back_confirmed=False,
            same_product_confirmed=False,
            capture_method="ocr_unconfirmed",
        )
    )
    prepared = service().prepare_submission(provisional)
    assert prepared.auto_eligible is False and prepared.request.barcode is None
    corrected = models().ContributionRequest.model_validate(contribution_dict(barcode=None))
    assert service().prepare_submission(corrected).auto_eligible is False
    payload = contribution_dict(
        observation_state="provisional", confirmed=False, capture_method="ocr_unconfirmed"
    )
    extra = copy.deepcopy(payload["rows"][0])
    extra.update(row_id="different", value=2)
    payload["rows"].append(extra)
    assert (
        service()
        .prepare_submission(models().ContributionRequest.model_validate(payload))
        .snapshot.status
        == "needs_correction"
    )


def test_semantic_fingerprint_ignores_transport_and_observation_metadata_but_preserves_revision():
    first = service().prepare_submission(
        models().ContributionRequest.model_validate(contribution_dict())
    )
    payload = contribution_dict(
        submission_id=str(uuid4()), observed_on="2026-10-06", capture_method="ocr_corrected"
    )
    payload["rows"][0]["row_id"] = "different-row"
    payload["rows"][0]["table_id"] = "different-table"
    second = service().prepare_submission(models().ContributionRequest.model_validate(payload))
    assert first.content_sha256 != second.content_sha256
    assert first.factual_sha256 == second.factual_sha256
    changed = service().prepare_submission(
        models().ContributionRequest.model_validate(
            contribution_dict(revision_context="Printed formulation v2")
        )
    )
    assert changed.factual_sha256 != first.factual_sha256


def test_semantic_fingerprint_preserves_ingredient_order_and_table_membership():
    original = contribution_dict()
    row = copy.deepcopy(original["rows"][0])
    row.update(row_id="protein", nutrient="protein", value=3)
    original["rows"].append(row)
    first = service().prepare_submission(models().ContributionRequest.model_validate(original))
    renamed = copy.deepcopy(original)
    renamed["rows"].reverse()
    for index, item in enumerate(renamed["rows"]):
        item["row_id"] = f"renamed-{index}"
        item["table_id"] = "renamed"
    assert (
        service()
        .prepare_submission(models().ContributionRequest.model_validate(renamed))
        .factual_sha256
        == first.factual_sha256
    )
    renamed["rows"][0]["table_id"] = "separate-table"
    assert (
        service()
        .prepare_submission(models().ContributionRequest.model_validate(renamed))
        .factual_sha256
        != first.factual_sha256
    )
    swapped = contribution_dict()
    swapped["ingredients"]["text"] = "Milk, oats"
    assert (
        service()
        .prepare_submission(models().ContributionRequest.model_validate(swapped))
        .factual_sha256
        != service()
        .prepare_submission(models().ContributionRequest.model_validate(contribution_dict()))
        .factual_sha256
    )


def test_provider_prefilled_content_cannot_be_declared_original_package_content():
    payload = contribution_dict()
    payload["ingredients"]["origin"] = "provider_reference"
    with pytest.raises(ValidationError):
        models().ContributionRequest.model_validate(payload)
    with pytest.raises(ValidationError):
        models().ContributionRequest.model_validate(
            contribution_dict(nutrition_origin="open_food_facts")
        )


def test_provider_reference_is_metadata_only_and_requires_actual_matching_snapshot():
    from tests.unit.test_community_resolver import off

    reference = {
        "provider": "off_snapshot",
        "source_id": "synthetic-off-test",
        "barcode": "0123456789012",
        "fields": ["identity.name"],
    }
    request = models().ContributionRequest.model_validate(
        contribution_dict(provider_references=[reference])
    )
    service().verify_provider_references(request, off())
    with pytest.raises(ValueError, match="reference"):
        service().verify_provider_references(request, None)
    bad = {**reference, "text": "Copied OFF ingredients"}
    with pytest.raises(ValidationError):
        models().ContributionRequest.model_validate(contribution_dict(provider_references=[bad]))


def test_unreviewed_revision_and_deduplicated_receipt_retain_honest_evidence_dates():
    from tests.community_fixtures import NOW, candidate_revision

    revision = candidate_revision()
    assert revision.reviewed_at is None
    assert revision.review_state == "submitter_confirmed_not_moderator_reviewed"
    common = dict(
        submission_id=str(uuid4()),
        revision_id="a" * 64,
        barcode=revision.barcode,
        content_sha256=revision.content_sha256,
        factual_sha256=revision.factual_sha256,
        status="approved",
        submitted_at=NOW + timedelta(days=1),
        reviewed_at=NOW,
    )
    assert (
        models().ContributionReceipt.model_validate({**common, "deduplicated": True}).deduplicated
        is True
    )
    with pytest.raises(ValidationError):
        models().ContributionReceipt.model_validate(common)
