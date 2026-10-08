import importlib.util
from datetime import datetime
from pathlib import Path
from typing import Any, Literal

import pytest

from app.claims.knowledge import KnowledgeStore
from app.community.models import CommunityLookup
from app.community.resolver import resolve_product
from tests.community_fixtures import CODE, NOW, candidate_revision, contribution_dict


def service():
    assert importlib.util.find_spec("app.reports") is not None, "Report package missing"
    from app.reports import service

    return service


def report(
    *,
    claims_store=None,
    glossary=None,
    selected: str | None = "back-table",
    context=None,
    **changes: Any,
):
    service()
    from app.reports.models import ReportCheckRequest

    body = ReportCheckRequest.model_validate(
        {
            "observation": contribution_dict(**changes),
            "selected_table_id": selected,
            "context": context,
        }
    )
    return service().report_from_observation(
        body, claims_store=claims_store, glossary=glossary, now=NOW
    )


def row(
    nutrient="sugars",
    value: float | None = 12,
    unit="g",
    basis=None,
    table="back-table",
    row_id=None,
    preparation="as_sold",
):
    return {
        "row_id": row_id or nutrient,
        "table_id": table,
        "nutrient": nutrient,
        "value": value,
        "unit": unit,
        "basis": basis or {"kind": "quantity", "amount": 40, "unit": "g"},
        "preparation": preparation,
    }


def knowledge():
    return KnowledgeStore(Path(__file__).resolve().parents[3] / "knowledge")


CONTEXT = {"food_category": "ordinary_general_food", "form": "solid", "preparation": "as_sold"}


def test_barcode_less_ingredient_only_report_is_useful_without_auth_storage_or_nutrition():
    result = report(barcode=None, rows=[])
    assert result.assessment_basis == "user_confirmed_label"
    assert result.identity is not None and result.identity.name == "Synthetic community oats"
    assert result.ingredients.text == "Oats, milk"
    assert result.contains.text == "Milk"
    assert result.may_contain.status == "not_observed"
    assert result.sugar is None and result.status == "partial"
    assert "nutrition_not_reported" in result.missing_inputs
    assert result.storage.status == "unavailable"
    assert result.claims[0].assessment is None
    assert "nutrition_not_reported" in result.claims[0].missing_inputs


def test_sugar_approximation_uses_original_quantity_instead_of_imagined_serving_or_package_weight():
    result = report(rows=[row()])
    assert result.sugar is not None
    assert result.sugar.sugars_g == 12 and result.sugar.cubes == 3
    assert result.sugar.grams_per_cube == 4
    assert result.sugar.basis.kind == "quantity"
    assert result.sugar.basis.amount == 40 and result.sugar.basis.unit == "g"
    assert result.sugar.source_table_id == "back-table"
    assert result.sugar.source_row_ids == ["sugars"]
    assert result.identity is not None and result.identity.quantity == "300 g"


def test_zero_sugar_is_known_while_missing_value_is_unknown():
    zero = report(rows=[row(value=0)])
    assert zero.sugar is not None and zero.sugar.cubes == 0
    result = report(rows=[row(value=None)])
    assert result.sugar is None
    assert "sugars_unknown_value" in result.missing_inputs


def test_declared_unmeasured_serving_can_be_illustrated_but_never_scaled_to_mass():
    result = report(
        rows=[row(value=2000, unit="mg", basis={"kind": "serving", "amount": None, "unit": None})]
    )
    assert result.sugar is not None and result.sugar.sugars_g == 2
    assert result.sugar.basis.kind == "serving" and result.sugar.basis.amount is None
    assert result.sugar.cubes == 0.5
    assert "measured_quantity_basis_required" in result.missing_inputs


def test_multiple_tables_without_selection_do_not_choose_or_mix_sugar():
    result = report(
        selected=None,
        rows=[
            row(),
            row(
                value=5,
                table="liquid",
                row_id="liquid-sugar",
                basis={"kind": "quantity", "amount": 100, "unit": "mL"},
            ),
        ],
    )
    assert result.sugar is None
    assert result.nutrition is not None
    assert len(result.nutrition.tables) == 2
    assert "selected_table_required" in result.missing_inputs
    missing = report(selected="missing-table", rows=[row()])
    assert missing.sugar is None
    assert "selected_table_missing" in missing.missing_inputs


def test_normalization_conflict_returns_original_evidence_and_blocks_positive_claim():
    result = report(
        claims_store=knowledge(),
        context=CONTEXT,
        front_claims=["Low sugar"],
        rows=[row(value=1), row(value=9, row_id="conflict")],
    )
    assert result.nutrition is not None
    assert result.nutrition.status == "needs_correction"
    assert len(result.nutrition.original_rows) == 2
    assert result.sugar is None
    assert "nutrition_needs_correction" in result.missing_inputs
    assert result.claims[0].assessment is not None
    assert result.claims[0].assessment.status == "insufficient_information"


@pytest.mark.parametrize(
    "rows",
    [
        [row("protein", 101, basis={"kind": "quantity", "amount": 100, "unit": "g"}), row(value=1)],
        [row("sugars", 2), row("added_sugars", 3)],
        [row("fat", 2), row("saturated_fat", 3), row(value=1)],
    ],
)
def test_inconsistent_same_table_quantities_preserve_partial_report_without_support(rows):
    result = report(
        claims_store=knowledge(), context=CONTEXT, front_claims=["Low sugar"], rows=rows
    )
    assert "nutrition_quantities_need_review" in result.warnings
    assert result.status == "partial"
    assert result.claims[0].assessment is None
    assert "nutrition_quantities_need_review" in result.claims[0].missing_inputs


def test_known_claim_uses_existing_reviewed_engine_on_confirmed_selected_original_table():
    result = report(
        claims_store=knowledge(),
        context=CONTEXT,
        front_claims=["  HIGH FIBRE  "],
        rows=[row("fibre", 6, basis={"kind": "quantity", "amount": 100, "unit": "g"})],
    )
    claim = result.claims[0]
    assert claim.claim == "high_fibre"
    assert claim.printed_text == "  HIGH FIBRE  "
    assert claim.assessment is not None
    assert claim.assessment.status == "supported"
    assert claim.assessment.scope == "numeric_criterion_only"
    assert claim.assessment.source_ids
    assert claim.assessment.row_ids == ["fibre"]


def test_claim_wording_is_whole_string_and_unknown_marketing_gets_no_verdict():
    result = report(
        claims_store=knowledge(),
        context=CONTEXT,
        front_claims=["Not sugar free", "Sugar free flavour", "Super healthy", "No added sugar"],
        rows=[row(value=0)],
    )
    assert [item.claim for item in result.claims] == [None, None, None, "no_added_sugar"]
    assert all(item.assessment is None for item in result.claims[:3])
    assert result.claims[3].assessment is not None
    assert result.claims[3].assessment.status == "insufficient_information"
    assert result.claims[3].assessment.applicability == "not_reviewed"


def test_missing_pairing_or_front_confirmation_prevents_claim_support_without_breaking_private_report():
    changes: list[dict[str, Any]] = [
        {"front_confirmed": False},
        {"back_confirmed": False},
        {"same_product_confirmed": False},
    ]
    for changed in changes:
        result = report(
            claims_store=knowledge(),
            context=CONTEXT,
            front_claims=["Low sugar"],
            rows=[row(value=0)],
            **changed,
        )
        assert result.ingredients.text == "Oats, milk"
        assert result.claims[0].assessment is None
        assert result.claims[0].missing_inputs


def test_claim_knowledge_outage_only_disables_claim_section():
    result = report(context=CONTEXT, rows=[row()], front_claims=["Low sugar"])
    assert result.sugar is not None and result.ingredients.text
    assert result.claims[0].assessment is None
    assert "reviewed_claim_knowledge_unavailable" in result.claims[0].missing_inputs


def test_naive_report_timestamp_is_rejected():
    from app.reports.models import ReportCheckRequest

    body = ReportCheckRequest.model_validate({"observation": contribution_dict()})
    with pytest.raises(ValueError, match="timezone"):
        service().report_from_observation(body, now=datetime(2026, 10, 7))


def test_historical_report_retains_resolved_sources_and_never_runs_current_claim_checks():
    community = CommunityLookup(
        requested_barcode=CODE, status="found", revisions=[candidate_revision(rows=[row()])]
    )
    resolved = resolve_product(None, community)
    result = service().report_from_resolved(resolved, claims_store=knowledge(), now=NOW)
    assert result.assessment_basis == "catalogue_historical"
    assert result.observation is None and result.resolved == resolved
    assert result.storage.status == "read_only"
    assert result.ingredients.text == "Oats, milk"
    assert result.claims[0].claim == "high_fibre" and result.claims[0].assessment is None
    assert "current_package_confirmation_required" in result.claims[0].missing_inputs
    assert result.sugar is not None and result.sugar.basis.amount == 40
    assert result.sugar.sugars_g == 12


def test_historical_ambiguous_tables_do_not_illustrate_sugar_from_merged_values():
    community = CommunityLookup(
        requested_barcode=CODE,
        status="found",
        revisions=[
            candidate_revision(
                rows=[
                    row(),
                    row(
                        value=5,
                        table="liquid",
                        row_id="liquid",
                        basis={"kind": "quantity", "amount": 100, "unit": "mL"},
                    ),
                ]
            )
        ],
    )
    result = service().report_from_resolved(resolve_product(None, community), now=NOW)
    assert result.sugar is None
    assert "selected_table_required" in result.missing_inputs


def test_historical_missing_sources_have_typed_not_found_or_unavailable_status():
    from app.catalogue.facts import FactsLookup

    statuses: list[Literal["not_found", "unavailable"]] = ["not_found", "unavailable"]
    for status in statuses:
        community = CommunityLookup(requested_barcode=CODE, status=status)
        off = (
            FactsLookup(requested_barcode=CODE, status="unavailable")
            if status == "unavailable"
            else None
        )
        result = service().report_from_resolved(resolve_product(off, community), now=NOW)
        assert result.status == status
        assert result.sugar is None and result.claims == []
        assert result.ingredients.status == "unknown"


def test_ingredient_glossary_matches_original_text_and_provides_resolvable_reviewed_sources():
    from app.reports.glossary import GlossaryStore

    text = "Oats, emulsifier INS 322(i), citric acid, INS 415, unknown spice"
    result = report(
        glossary=GlossaryStore(),
        ingredients={
            "status": "present",
            "text": text,
            "completeness": "partial",
            "origin": "independently_transcribed_package",
        },
    )
    assert result.ingredients.text == text and result.ingredients.completeness == "partial"
    assert {item.entry.entry_id for item in result.ingredient_insights} == {
        "lecithin",
        "citric_acid",
        "xanthan_gum",
    }
    assert result.glossary_version == "ingredients-2026-10-08.1"
    assert result.glossary_artifact is not None and result.glossary_artifact.entry_count == 6
    sources = {source.source_id for source in result.glossary_sources}
    for match in result.ingredient_insights:
        assert text[match.start : match.end] == match.matched_text
        assert set(match.entry.source_ids) <= sources
    assert "ingredients_partial_capture" in result.missing_inputs


def test_current_unknown_declaration_never_becomes_an_allergy_free_verdict():
    section = {
        "status": "not_captured",
        "text": None,
        "completeness": "partial",
        "origin": "independently_transcribed_package",
    }
    result = report(contains=section, may_contain=section)
    assert result.contains.status == "not_captured" and result.contains.text is None
    assert "contains_not_captured" in result.missing_inputs
    assert "may_contain_not_captured" in result.missing_inputs
    assert "allergen_safety_not_assessed" in result.warnings


def test_dated_off_direct_sugar_table_retains_its_evidence_while_tags_never_become_declarations():
    from tests.unit.test_community_resolver import off

    resolved = resolve_product(
        off(sugar=8), CommunityLookup(requested_barcode=CODE, status="not_found")
    )
    result = service().report_from_resolved(resolved, now=NOW)
    assert result.sugar is not None and result.sugar.cubes == 2
    assert result.sugar.source_ids == ["off:synthetic-off-test"]
    assert result.sugar.assessment_basis == "catalogue_historical"
    assert result.contains.status == "unknown" and result.may_contain.status == "unknown"
    assert result.claims == []


def test_unknown_provider_revision_compatibility_cannot_select_historical_sugar():
    from tests.unit.test_community_resolver import off

    resolved = resolve_product(
        off(),
        CommunityLookup(requested_barcode=CODE, status="found", revisions=[candidate_revision()]),
    )
    result = service().report_from_resolved(resolved, now=NOW)
    assert result.sugar is None
    assert "compatible_original_sugar_table_required" in result.missing_inputs
    assert result.resolved is not None and result.resolved.off_snapshot is not None


def test_conflicting_historical_ingredients_are_not_selected_or_explained_as_one_formula():
    from app.reports.glossary import GlossaryStore

    changed = candidate_revision(
        ingredients={
            "status": "present",
            "text": "Oats, INS 415",
            "completeness": "complete",
            "origin": "independently_transcribed_package",
        }
    ).model_copy(update={"revision_id": "b" * 64})
    resolved = resolve_product(
        None,
        CommunityLookup(
            requested_barcode=CODE, status="found", revisions=[candidate_revision(), changed]
        ),
    )
    result = service().report_from_resolved(resolved, glossary=GlossaryStore(), now=NOW)
    assert result.ingredients.status == "conflict" and result.ingredients.text is None
    assert result.ingredient_insights == []
    assert "ingredients_conflict" in result.missing_inputs


def test_historical_many_printed_claims_keep_source_originals_and_signal_bounded_summary():
    first = candidate_revision(front_claims=[f"Unknown claim {i}" for i in range(16)])
    second = candidate_revision(front_claims=["High fibre"]).model_copy(
        update={"revision_id": "b" * 64}
    )
    resolved = resolve_product(
        None, CommunityLookup(requested_barcode=CODE, status="found", revisions=[first, second])
    )
    result = service().report_from_resolved(resolved, now=NOW)
    assert len(result.claims) == 16
    assert (
        result.resolved is not None
        and len(result.resolved.community.revisions[1].facts.front_claims) == 1
    )
    assert "front_claim_summary_bounded_to_16" in result.warnings


def test_historical_unknown_serving_retains_original_without_overriding_resolver_qualification():
    rows = [row(value=4, basis={"kind": "serving", "amount": None, "unit": None})]
    resolved = resolve_product(
        None,
        CommunityLookup(
            requested_barcode=CODE, status="found", revisions=[candidate_revision(rows=rows)]
        ),
    )
    result = service().report_from_resolved(resolved, now=NOW)
    assert result.sugar is None
    assert "compatible_original_sugar_table_required" in result.missing_inputs
    assert result.resolved is not None
    table = result.resolved.community.revisions[0].snapshot.tables[0]
    assert table.nutrients["sugars"].value == 4 and table.original_basis.amount is None


def test_maximum_current_observation_stays_bounded_with_original_rows_and_sections():
    from app.reports.glossary import GlossaryStore
    from app.reports.models import LabelReport

    rows = [row(value=12, row_id=f"sugar-{i}", table=f"table-{i}") for i in range(64)]
    section = {
        "status": "present",
        "text": "c" * 16000,
        "completeness": "partial",
        "origin": "independently_transcribed_package",
    }
    result = report(
        selected=None,
        context=CONTEXT,
        claims_store=knowledge(),
        glossary=GlossaryStore(),
        front_claims=["High fibre"] * 16,
        rows=rows,
        ingredients=section,
        contains=section,
        may_contain=section,
    )
    assert result.nutrition is not None and len(result.nutrition.tables) == 64
    assert len(result.nutrition.original_rows) == 64 and len(result.claims) == 16
    assert result.sugar is None and len(result.missing_inputs) <= 100
    assert len(result.warnings) <= 100 and result.ingredients.text == section["text"]
    assert LabelReport.model_validate_json(result.model_dump_json()) == result


def test_maximum_historical_originals_remain_available_with_bounded_views():
    from app.reports.glossary import GlossaryStore
    from app.reports.models import LabelReport

    revisions = []
    for index in range(8):
        rows = [row(value=12, row_id=f"r-{i}", table=f"t-{i}") for i in range(64)]
        revision = candidate_revision(
            rows=rows, front_claims=[f"Source {index} claim {i}" for i in range(16)]
        )
        revisions.append(revision.model_copy(update={"revision_id": f"{index + 1:064x}"}))
    resolved = resolve_product(
        None, CommunityLookup(requested_barcode=CODE, status="found", revisions=revisions)
    )
    result = service().report_from_resolved(resolved, glossary=GlossaryStore(), now=NOW)
    assert result.resolved is not None and len(result.resolved.community.revisions) == 8
    assert sum(len(item.snapshot.tables) for item in result.resolved.community.revisions) == 512
    assert all(len(field.alternatives) <= 144 for field in result.resolved.fields)
    assert len(result.claims) == 16 and "front_claim_summary_bounded_to_16" in result.warnings
    assert result.sugar is None and "selected_table_required" in result.missing_inputs
    assert LabelReport.model_validate_json(result.model_dump_json()) == result
