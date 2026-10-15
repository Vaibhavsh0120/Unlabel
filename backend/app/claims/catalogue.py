"""Read-only numeric comparisons to dated catalogue tables, not package verdicts."""

from fractions import Fraction
from typing import Literal

from pydantic import Field

from app.ai.admission import Baseline, known_baseline
from app.ai.models import AiModel, ShortText
from app.ai.observations import compatible_identity, conflict_fields
from app.claims.knowledge import KnowledgeStore
from app.claims.models import ClaimName
from app.community.store import StoreUnavailable
from app.reports.service import _identify


class CatalogueClaimsRequest(AiModel):
    barcode: str = Field(pattern=r"^(?:[0-9]{8}|[0-9]{12,14})$")
    claims: list[ShortText] = Field(min_length=1, max_length=16)


class CatalogueCriterion(AiModel):
    source_id: str
    table_id: str
    criterion_id: str
    basis: str
    nutrient: str
    operator: Literal["gte", "lte"]
    threshold: float
    unit: str
    value: float | None
    outcome: Literal["pass", "fail", "unknown", "not_applicable"]


class CatalogueClaimAssessment(AiModel):
    text: str
    claim: ClaimName | None
    # Catalogue data does not establish current-package or regulatory context.
    status: Literal["insufficient_information"] = "insufficient_information"
    reasons: list[str]
    comparisons: list[CatalogueCriterion] = Field(default_factory=list, max_length=96)
    rule_source_ids: list[str] = Field(default_factory=list, max_length=3)


class CatalogueClaimsResponse(AiModel):
    schema_version: Literal["catalogue-claim-check-v1"] = "catalogue-claim-check-v1"
    status: Literal["ready", "unavailable", "not_found"]
    barcode: str
    assessment_basis: Literal["catalogue_historical"] = "catalogue_historical"
    knowledge_version: str | None
    source_ids: list[str] = Field(default_factory=list, max_length=32)
    assessments: list[CatalogueClaimAssessment] = Field(min_length=1, max_length=16)
    warnings: list[str] = Field(default_factory=lambda: [
        "dated_catalogue_not_current_package", "food_category_and_form_not_established",
        "numeric_comparisons_only_not_claim_verdicts", "not_legal_certification", "not_allergy_safety",
    ])


def _row_value(table: dict, nutrient: str) -> Fraction | None:
    found = []
    for row in table["rows"]:
        if row["nutrient"] != nutrient:
            continue
        if row["value"] is None or row.get("qualifier") != "exact":
            return None
        unit = row["unit"]
        # Research observations preserve the printed unit, including unknown or
        # malformed combinations. An energy unit cannot stand in for grams of
        # sugar, and mass alone cannot establish an energy denominator.
        if unit not in ({"kcal", "kJ"} if nutrient == "energy" else {"g", "mg", "ug"}):
            return None
        factor = {"g": "1", "mg": ".001", "ug": ".000001", "kcal": "1", "kJ": "1"}[unit]
        number = Fraction(str(row["value"])) * Fraction(factor)
        if unit == "kJ":
            number /= Fraction("4.2")  # Reviewed Schedule I Note 2, not 4.184.
        found.append(number)
    return found[0] if found and len(set(found)) == 1 else None


def _compare(table: dict, criterion, *, blocked: bool) -> CatalogueCriterion:
    basis = table["basis"]
    value = None
    outcome = "unknown"
    amount, unit = basis.get("amount"), basis.get("unit")
    if not blocked and table["preparation"] != "unknown" and amount and unit in {"g", "mL"} and basis.get("kind") in {None, "quantity"}:
        expected = {"per_100_g": "g", "per_100_mL": "mL"}.get(criterion.basis)
        if expected is not None and expected != unit:
            outcome = "not_applicable"
        else:
            number = _row_value(table, criterion.nutrient)
            if number is not None:
                if criterion.basis == "per_100_kcal":
                    energy = _row_value(table, "energy")
                    number = number * 100 / energy if energy is not None and energy > 0 else None
                else:
                    number = number * 100 / Fraction(str(amount))
                if number is not None and 0 <= number <= 1_000_000_000:
                    value = float(number)
                    threshold = Fraction(str(criterion.threshold))
                    passed = number >= threshold if criterion.operator == "gte" else number <= threshold
                    outcome = "pass" if passed else "fail"
    return CatalogueCriterion(source_id=table["source_id"], table_id=table["table_id"],
        criterion_id=criterion.criterion_id, basis=criterion.basis, nutrient=criterion.nutrient,
        operator=criterion.operator, threshold=criterion.threshold, unit=criterion.unit,
        value=value, outcome=outcome)


def assess_catalogue_claims(state, body: CatalogueClaimsRequest, knowledge: KnowledgeStore | None) -> CatalogueClaimsResponse:
    from datetime import UTC, datetime

    try:
        baseline = known_baseline(state, body.barcode)
        status = "ready" if baseline.identities else "not_found"
    except (StoreUnavailable, ValueError, OSError):
        baseline = Baseline(body.barcode)
        status = "unavailable"
    if knowledge is None:
        status = "unavailable"
    conflicts = conflict_fields(baseline.values)
    identity_conflict = any(not compatible_identity(left, right)
                            for left in baseline.identities for right in baseline.identities)
    assessments = []
    for text in body.claims:
        claim = _identify(text)
        rule = knowledge.rules.get(claim) if knowledge is not None and claim else None
        reasons = ["current_package_not_confirmed", "food_category_and_form_not_established"]
        comparisons = []
        if status != "ready":
            reasons.append("catalogue_" + status)
        if rule is None:
            reasons.append("claim_not_implemented_with_reviewed_evidence")
        elif not knowledge.evidence_current(rule.source_ids, today=datetime.now(UTC).date()):
            reasons.append("reviewed_source_not_current")
        else:
            if identity_conflict:
                reasons.append("catalogue_identity_conflict")
            if len(baseline.tables) > 32:
                reasons.append("catalogue_table_limit")
            if not baseline.tables:
                reasons.append("direct_nutrition_table_missing")
            for table in baseline.tables[:32]:
                for criterion in rule.criteria:
                    nutrient_conflict = any(f".{criterion.nutrient}." in field for field in conflicts)
                    if nutrient_conflict and "catalogue_nutrient_conflict" not in reasons:
                        reasons.append("catalogue_nutrient_conflict")
                    comparisons.append(_compare(table, criterion, blocked=(
                        status != "ready" or identity_conflict or nutrient_conflict or len(baseline.tables) > 32)))
        assessments.append(CatalogueClaimAssessment(text=text, claim=claim, reasons=reasons,
            comparisons=comparisons, rule_source_ids=rule.source_ids if rule else []))
    return CatalogueClaimsResponse(status=status, barcode=body.barcode,
        knowledge_version=knowledge.knowledge_version if knowledge else None,
        source_ids=baseline.source_ids[:32], assessments=assessments)
