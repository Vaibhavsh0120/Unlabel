"""Synthetic comparison arithmetic, source identity and no-write boundaries."""

import copy
from pathlib import Path

import pytest
from pydantic import ValidationError

from app.catalogue.facts import FactsLookup
from app.community.models import CommunityLookup
from app.comparison.models import ComparisonRequest, ComparisonResponse
from app.comparison.service import compare
from tests.community_fixtures import CODE, candidate_revision, contribution_dict

ROOT = Path(__file__).resolve().parents[3]


def payload():
    side = {
        "kind": "current_confirmed_label",
        "observation": contribution_dict(),
        "selected_table_id": "back-table",
    }
    return {
        "client_request_id": "10000000-0000-4000-8000-000000000010",
        "comparison_session_id": "10000000-0000-4000-8000-000000000011",
        "input_revision": 3,
        "a": copy.deepcopy(side),
        "b": copy.deepcopy(side),
    }


def forbidden(_):
    raise AssertionError("Current comparison must make no provider or store calls")


def run(value, **options):
    return compare(
        ComparisonRequest.model_validate(value),
        off_lookup=options.get("off_lookup", forbidden),
        community_lookup=options.get("community_lookup", forbidden),
    )


def row(result, nutrient="sugars"):
    return next(value for value in result.nutrients if value.nutrient == nutrient)


@pytest.mark.parametrize(
    ("left", "unit", "amount", "right", "expected"),
    [
        (4, "g", 40, 10, 0),
        (4000, "mg", 40, 12, 2),
        (400000, "ug", 40, 0.8, -0.2),
        (0, "g", 100, 0, 0),
    ],
)
def test_exact_conversion_and_signed_direction(left, unit, amount, right, expected):
    value = payload()
    value["a"]["observation"]["rows"][0].update(value=left, unit=unit)
    value["a"]["observation"]["rows"][0]["basis"]["amount"] = amount
    value["b"]["observation"]["rows"][0]["value"] = right
    result = run(value)
    assert result.status == "partial"
    assert row(result).difference == expected
    assert row(result).lower == ("a" if expected > 0 else "b" if expected < 0 else "equal")
    assert result.a.snapshot.original_rows[0].value == left
    assert row(result, "added_sugars").difference is None
    assert result.storage == "read_only"
    ComparisonResponse.model_validate_json(result.model_dump_json())


def test_kj_uses_scientific_conversion_and_preserves_original():
    value = payload()
    for side in ("a", "b"):
        value[side]["observation"]["rows"][0].update(
            nutrient="energy",
            value=4.184 if side == "a" else 1,
            unit="kJ" if side == "a" else "kcal",
        )
    assert row(run(value), "energy").difference == 0


@pytest.mark.parametrize(
    "change",
    [
        "unknown",
        "unknown_duplicate",
        "conflict",
        "missing_basis",
        "different_preparation",
        "mass_volume",
        "ambiguous",
        "missing_table",
        "impossible",
    ],
)
def test_unknown_conflicting_or_incompatible_context_never_has_a_difference(change):
    value = payload()
    rows = value["a"]["observation"]["rows"]
    if change == "unknown":
        rows[0]["value"] = None
    elif change in ("unknown_duplicate", "conflict", "ambiguous"):
        duplicate = copy.deepcopy(rows[0])
        duplicate["row_id"] = "other"
        duplicate["value"] = None if change == "unknown_duplicate" else 1
        if change == "ambiguous":
            duplicate["basis"]["amount"] = 40
        rows.append(duplicate)
    elif change == "missing_basis":
        rows[0]["basis"] = {"kind": "serving", "amount": None, "unit": None}
    elif change == "different_preparation":
        rows[0]["preparation"] = "as_prepared"
    elif change == "mass_volume":
        rows[0]["basis"]["unit"] = "mL"
    elif change == "missing_table":
        value["a"]["selected_table_id"] = "absent"
    else:
        rows[0]["value"] = 101
    result = run(value)
    assert row(result).difference is None
    assert row(result).lower is None


@pytest.mark.parametrize(
    "change", ["provisional", "unconfirmed", "ocr_unconfirmed", "extra", "bool_revision"]
)
def test_strict_confirmation_and_extra_fields(change):
    value = payload()
    if change == "provisional":
        value["a"]["observation"]["observation_state"] = "provisional"
    elif change == "unconfirmed":
        value["a"]["observation"]["confirmed"] = False
    elif change == "ocr_unconfirmed":
        value["a"]["observation"]["capture_method"] = "ocr_unconfirmed"
    elif change == "extra":
        value["a"]["photo"] = "private"
    else:
        value["input_revision"] = True
    with pytest.raises(ValidationError):
        run(value)


def test_off_exact_reference_and_single_read_for_two_sides():
    facts = FactsLookup.model_validate_json(
        (ROOT / "contracts/examples/catalogue-facts-v1.synthetic.json").read_text()
    )
    value = payload()
    source = {
        "kind": "off_snapshot",
        "barcode": facts.requested_barcode,
        "snapshot_id": facts.manifest.snapshot_id,
        "source_sha256": facts.manifest.source_sha256,
        "selected_table_id": facts.details.nutrition.snapshot.tables[0].source_table_id,
    }
    value.update(a=source, b=copy.deepcopy(source))
    calls = []

    def lookup(code):
        calls.append(code)
        return facts

    result = run(value, off_lookup=lookup)
    assert len(calls) == 1
    assert result.a.source.manifest.source_sha256 == source["source_sha256"]
    assert result.a.assessment_basis == "catalogue_historical"
    value["b"]["source_sha256"] = "f" * 64
    result = run(value, off_lookup=lookup)
    assert result.b.status == "source_changed"
    assert result.a.snapshot is not None
    assert all(item.difference is None for item in result.nutrients)


def test_public_active_community_revision_only_and_unknown_is_not_zero():
    revision = candidate_revision()
    lookup = CommunityLookup(requested_barcode=CODE, status="found", revisions=[revision])
    value = payload()
    value["b"] = {
        "kind": "community_revision",
        "barcode": CODE,
        "revision_id": revision.revision_id,
        "factual_sha256": revision.factual_sha256,
        "selected_table_id": "back-table",
    }
    result = run(value, community_lookup=lambda _: lookup)
    assert result.b.source.reviewed_at is None
    assert result.b.source.review_state == "submitter_confirmed_not_moderator_reviewed"
    assert row(result).b.value == 0
    value["b"]["revision_id"] = "e" * 64
    result = run(value, community_lookup=lambda _: lookup)
    assert result.b.status == "not_found"
    assert row(result).b.value is None


def test_unavailable_reference_preserves_other_current_original_rows():
    value = payload()
    value["b"] = {
        "kind": "off_snapshot",
        "barcode": CODE,
        "snapshot_id": "missing",
        "source_sha256": "a" * 64,
        "selected_table_id": "back-table",
    }
    result = run(
        value, off_lookup=lambda _: FactsLookup(requested_barcode=CODE, status="unavailable")
    )
    assert result.a.status == "ready"
    assert result.b.status == "unavailable"
    assert row(result).a.value == 0
    assert row(result).difference is None
