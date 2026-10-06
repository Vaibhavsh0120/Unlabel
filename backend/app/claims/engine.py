import math
from datetime import UTC, datetime
from fractions import Fraction

from app.claims.knowledge import KnowledgeStore
from app.claims.models import (
    ClaimAssessment,
    ClaimRule,
    ClaimsRequest,
    ClaimsResponse,
    CriterionAssessment,
    IdentifiedClaim,
    RuleCriterion,
    SourceId,
)
from app.schemas.nutrition import NutritionSnapshot, NutritionTable
from app.services.parsing.nutrition import UNIT_FACTORS, normalize_rows

UNREVIEWED_REQUIREMENTS = {
    "high_protein": ["reviewed_population_rda", "confirmed_target_population"],
    "source_of_protein": ["reviewed_population_rda", "confirmed_target_population"],
    "no_added_sugar": [
        "complete_ingredient_and_compound_ingredient_evidence",
        "sugar_addition_and_processing_evidence",
        "naturally_occurring_sugar_declaration",
    ],
    "multigrain": ["reviewed_category_composition_rule", "confirmed_grain_composition"],
}
UNREVIEWED_WORDING = {
    "high_protein": (
        "Protein claims use population-specific RDA criteria. This version does not assume a "
        "daily protein requirement or substitute a percentage of energy for that RDA."
    ),
    "source_of_protein": (
        "Protein claims use population-specific RDA criteria. A reviewed population and RDA "
        "reference are required before this claim can be assessed."
    ),
    "no_added_sugar": (
        "A zero added-sugars value cannot establish this claim. Ingredient and compound-ingredient "
        "evidence, sugar additions or replacements, processing and the required naturally "
        "occurring-sugar declaration have not been verified."
    ),
    "multigrain": (
        "This version has no reviewed category-specific composition rule for multigrain. "
        "Multiple grains alone do not establish better nutritional quality."
    ),
}


def _deduplicate(values: list[str]) -> list[str]:
    return list(dict.fromkeys(values))


def _exact_value(
    snapshot: NutritionSnapshot, row_ids: list[str], *, regulatory_energy: bool = False
) -> Fraction | None:
    values = []
    for row in snapshot.original_rows:
        if row.row_id in row_ids:
            if row.value is None:
                return None
            # Exact rational arithmetic avoids rounding a threshold when scaling
            # a basis such as 6 g or 14 g. The emitted normalization-v1 is unchanged.
            value = Fraction(str(row.value))
            if row.unit == "kJ":
                # Gazette Note 2 uses 4.2; normalization-v1 uses 4.184.
                value /= Fraction("4.2" if regulatory_energy else "4.184")
            else:
                value *= Fraction(UNIT_FACTORS[row.unit])
            if row.basis.amount is not None:
                value *= Fraction(100) / Fraction(str(row.basis.amount))
            values.append(value)
    return values[0] if values and all(value == values[0] for value in values) else None


def _criterion(
    criterion: RuleCriterion,
    body: ClaimsRequest,
    snapshot: NutritionSnapshot,
    table: NutritionTable | None,
    blockers: list[str],
) -> CriterionAssessment:
    arguments = {
        "criterion_id": criterion.criterion_id,
        "nutrient": criterion.nutrient,
        "basis": criterion.basis,
        "operator": criterion.operator,
        "threshold": criterion.threshold,
        "unit": criterion.unit,
    }
    if body.context.form != "unknown" and criterion.applicable_form not in (
        "either",
        body.context.form,
    ):
        return CriterionAssessment(
            **arguments,
            applicable=False,
            outcome="not_applicable",
            value=None,
            row_ids=[],
            reason="different_food_form",
        )
    if blockers or table is None:
        return CriterionAssessment(
            **arguments,
            applicable=True,
            outcome="unknown",
            value=None,
            row_ids=[],
            reason=blockers[0] if blockers else "selected_table_missing",
        )
    cell = table.nutrients[criterion.nutrient]
    row_ids = list(cell.source_row_ids)
    reason = cell.reason if cell.value is None or cell.reason is not None else None
    value = _exact_value(snapshot, row_ids) if reason is None else None
    if value is None:
        return CriterionAssessment(
            **arguments,
            applicable=True,
            outcome="unknown",
            value=None,
            row_ids=row_ids,
            reason=f"{criterion.nutrient}_{reason or 'unknown_value'}",
        )
    if criterion.basis == "per_100_kcal":
        energy = table.nutrients["energy"]
        row_ids = _deduplicate(row_ids + energy.source_row_ids)
        energy_value = (
            _exact_value(snapshot, energy.source_row_ids, regulatory_energy=True)
            if energy.value is not None and energy.reason is None
            else None
        )
        if energy_value is None or energy_value <= 0:
            return CriterionAssessment(
                **arguments,
                applicable=True,
                outcome="unknown",
                value=None,
                row_ids=row_ids,
                reason="positive_energy_same_table_required",
            )
        value = value * 100 / energy_value
    # Fraction can overflow float conversion; enforce the exact bound first.
    converted = float(value) if value <= 1_000_000_000 else None
    if converted is None or not math.isfinite(converted) or (value != 0 and converted == 0):
        return CriterionAssessment(
            **arguments,
            applicable=True,
            outcome="unknown",
            value=None,
            row_ids=row_ids,
            reason="criterion_conversion_out_of_bounds",
        )
    threshold = Fraction(str(criterion.threshold))
    passed = value >= threshold if criterion.operator == "gte" else value <= threshold
    return CriterionAssessment(
        **arguments,
        applicable=True,
        outcome="pass" if passed else "fail",
        value=converted,
        row_ids=row_ids,
        reason=None,
    )


def _reviewed_assessment(
    claim: IdentifiedClaim,
    rule: ClaimRule,
    body: ClaimsRequest,
    snapshot: NutritionSnapshot,
    table: NutritionTable | None,
    blockers: list[str],
) -> ClaimAssessment:
    criteria = [_criterion(item, body, snapshot, table, blockers) for item in rule.criteria]
    applicable = [criterion for criterion in criteria if criterion.applicable]
    if any(criterion.outcome == "pass" for criterion in applicable):
        status = "supported"
        explanation = rule.supported_wording
    elif applicable and all(criterion.outcome == "fail" for criterion in applicable):
        status = "contradicted"
        explanation = rule.contradicted_wording
    else:
        status = "insufficient_information"
        explanation = (
            "This numerical claim check needs confirmed, compatible label facts and current "
            "reviewed evidence. Missing or conflicting information cannot establish support "
            "or contradiction."
        )
    missing = _deduplicate(
        blockers + [item.reason for item in applicable if item.outcome == "unknown" and item.reason]
    )
    reasons = list(blockers)
    if status == "supported":
        reasons.append("at_least_one_numeric_alternative_met")
    elif status == "contradicted":
        reasons.append("all_applicable_numeric_alternatives_failed")
    elif not blockers:
        reasons.append("numeric_alternative_information_missing")
    return ClaimAssessment(
        claim_id=claim.claim_id,
        claim=claim.claim,
        region_id=claim.region_id,
        status=status,
        applicability="not_established" if blockers else "applicable",
        reasons=_deduplicate(reasons),
        missing_inputs=missing,
        row_ids=_deduplicate([row_id for item in criteria for row_id in item.row_ids]),
        criteria=criteria,
        rule_id=rule.rule_id,
        source_ids=rule.source_ids,
        explanation=explanation,
    )


def assess_claims(
    body: ClaimsRequest,
    store: KnowledgeStore,
    *,
    now: datetime | None = None,
) -> ClaimsResponse:
    assessed_at = now or datetime.now(UTC)
    if assessed_at.tzinfo is None or assessed_at.utcoffset() is None:
        raise ValueError("Assessment time must have a timezone")
    snapshot = normalize_rows(body.rows, completeness=body.completeness)
    selected = [
        table for table in snapshot.tables if table.source_table_id == body.selected_table_id
    ]
    table = selected[0] if len(selected) == 1 else None
    blockers = []
    if body.context.food_category != "ordinary_general_food":
        blockers.append("ordinary_general_food_scope_not_confirmed")
    if body.context.form == "unknown":
        blockers.append("food_form_not_confirmed")
    if body.context.preparation == "unknown":
        blockers.append("preparation_not_confirmed")
    if not selected:
        blockers.append("selected_table_missing")
    elif len(selected) != 1:
        blockers.append("selected_table_ambiguous")
    if snapshot.status == "needs_correction":
        blockers.append("nutrition_needs_correction")
    if table is not None:
        if table.preparation != body.context.preparation:
            blockers.append("selected_table_preparation_mismatch")
        if table.normalized_basis.kind != "quantity" or table.normalized_basis.amount != 100:
            blockers.append("measured_quantity_basis_required")
        elif (body.context.form == "solid" and table.normalized_basis.unit != "g") or (
            body.context.form == "liquid" and table.normalized_basis.unit != "mL"
        ):
            blockers.append("food_form_and_quantity_unit_mismatch")
    assessments = []
    for claim in body.claims:
        rule = store.rules.get(claim.claim)
        if rule is None:
            source_ids: list[SourceId] = (
                ["fssai-ac-2018-general"]
                if claim.claim == "no_added_sugar"
                else (
                    ["fssai-ac-2022-schedule-i"]
                    if claim.claim in ("high_protein", "source_of_protein")
                    else []
                )
            )
            assessments.append(
                ClaimAssessment(
                    claim_id=claim.claim_id,
                    claim=claim.claim,
                    region_id=claim.region_id,
                    status="insufficient_information",
                    applicability="not_reviewed",
                    reasons=["claim_not_implemented_with_reviewed_evidence"],
                    missing_inputs=UNREVIEWED_REQUIREMENTS[claim.claim],
                    row_ids=[],
                    criteria=[],
                    rule_id=None,
                    source_ids=source_ids,
                    explanation=UNREVIEWED_WORDING[claim.claim],
                )
            )
            continue
        rule_blockers = list(blockers)
        if not store.evidence_current(rule.source_ids, today=assessed_at.date()):
            rule_blockers.append("reviewed_source_not_current")
        assessments.append(_reviewed_assessment(claim, rule, body, snapshot, table, rule_blockers))
    warnings = [
        "numeric_criteria_only",
        "not_legal_certification",
        "not_overall_health_score",
        "confirmed_inputs_only",
    ]
    if body.context.preparation == "as_prepared":
        warnings.append("preparation_instructions_not_independently_verified")
    return ClaimsResponse(
        client_request_id=body.client_request_id,
        capture_session_id=body.capture_session_id,
        input_revision=body.input_revision,
        selected_table_id=body.selected_table_id,
        context=body.context,
        knowledge_version=store.knowledge_version,
        assessed_at=assessed_at,
        snapshot=snapshot,
        assessments=assessments,
        warnings=warnings,
    )
