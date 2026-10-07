"""Explain confirmed facts without converting missing information into verdicts."""

import unicodedata
from datetime import UTC, datetime
from decimal import Decimal

from app import __version__
from app.claims.engine import assess_claims
from app.claims.knowledge import KnowledgeStore
from app.claims.models import ClaimName, ClaimsRequest, IdentifiedClaim
from app.community.models import LabelSection, ResolvedProduct
from app.community.service import contribution_facts
from app.reports.glossary import GlossaryStore
from app.reports.models import (
    LabelReport,
    ReportBasis,
    ReportCheckRequest,
    ReportClaim,
    ReportSection,
    StorageOutcome,
    SugarApproximation,
)
from app.schemas.nutrition import (
    NutrientName,
    NutritionSnapshot,
    NutritionTable,
)
from app.services.parsing.nutrition import UNIT_FACTORS, normalize_rows

# Identification is deliberately whole-string. Nearby marketing words, negation
# and arbitrary ingredient text cannot turn into a positive claim assessment.
CLAIM_WORDING: dict[str, ClaimName] = {
    "source of fibre": "source_of_fibre",
    "source of fiber": "source_of_fibre",
    "high fibre": "high_fibre",
    "high fiber": "high_fibre",
    "low sugar": "low_sugar",
    "low sugars": "low_sugar",
    "sugar free": "sugar_free",
    "sugar-free": "sugar_free",
    "low sodium": "low_sodium",
    "very low sodium": "very_low_sodium",
    "sodium free": "sodium_free",
    "sodium-free": "sodium_free",
    "high protein": "high_protein",
    "source of protein": "source_of_protein",
    "no added sugar": "no_added_sugar",
    "no added sugars": "no_added_sugar",
    "multigrain": "multigrain",
    "multi-grain": "multigrain",
    "multi grain": "multigrain",
}
CURRENT_SOURCE = "confirmed-label"


def _unique(values: list[str]) -> list[str]:
    return list(dict.fromkeys(values))


def _time(now: datetime | None) -> datetime:
    value = now or datetime.now(UTC)
    if value.tzinfo is None or value.utcoffset() is None:
        raise ValueError("Report time must have a timezone")
    return value


def _identify(text: str) -> ClaimName | None:
    wording = " ".join(unicodedata.normalize("NFKC", text).casefold().split())
    return CLAIM_WORDING.get(wording)


def _current_section(section: LabelSection) -> ReportSection:
    return ReportSection(
        status=section.status,
        text=section.text,
        completeness=section.completeness,
        source_ids=[CURRENT_SOURCE],
        evidence_state="user_confirmed_label",
    )


def _historical_section(resolved: ResolvedProduct, name: str) -> ReportSection:
    field = next((item for item in resolved.fields if item.field == name), None)
    if field is None:
        return ReportSection(status="unknown")
    selected = isinstance(field.value, str) and bool(field.value.strip())
    if selected:
        status = "present"
    elif field.state == "conflict":
        status = "conflict"
    elif field.state == "not_comparable":
        status = "not_comparable"
    else:
        status = "unknown"
    return ReportSection(
        status=status,
        text=field.value if selected and isinstance(field.value, str) else None,
        completeness=field.completeness,
        source_ids=field.source_ids,
        evidence_state=field.evidence_state,
    )


def _quantities_need_review(snapshot: NutritionSnapshot) -> bool:
    """Only impossible same-context amounts; no dietary health thresholds."""
    pairs: tuple[tuple[NutrientName, NutrientName], ...] = (
        ("added_sugars", "sugars"),
        ("saturated_fat", "fat"),
    )
    for table in snapshot.tables:
        basis = table.normalized_basis
        if basis.kind == "quantity" and basis.unit == "g" and basis.amount == 100:
            if any(
                cell.unit == "g" and cell.value is not None and cell.value > 100
                for cell in table.nutrients.values()
            ):
                return True
        for subset, total in pairs:
            left, right = table.nutrients[subset], table.nutrients[total]
            if left.value is not None and right.value is not None and left.value > right.value:
                # Rounding can explain small printed discrepancies, so retain
                # the transcription and request correction rather than reject it.
                return True
    return False


def _selected_table(
    snapshot: NutritionSnapshot,
    selected: str | None,
) -> tuple[NutritionTable | None, list[str]]:
    tables = snapshot.tables
    if not tables:
        return None, ["nutrition_not_reported"]
    if selected is None:
        return (tables[0], []) if len(tables) == 1 else (None, ["selected_table_required"])
    matches = [table for table in tables if table.source_table_id == selected]
    if not matches:
        return None, ["selected_table_missing"]
    if len(matches) != 1:
        return None, ["selected_table_ambiguous"]
    return matches[0], []


def _sugar(
    snapshot: NutritionSnapshot,
    table: NutritionTable,
    basis: ReportBasis,
    source_ids: list[str],
) -> tuple[SugarApproximation | None, list[str]]:
    cell = table.nutrients["sugars"]
    if cell.value is None:
        return None, [f"sugars_{cell.reason or 'unknown_value'}"]
    # Use original printed quantities, not rounded normalized values and not the
    # package's net weight. Repeated same-context rows must be equivalent.
    rows = [row for row in snapshot.original_rows if row.row_id in cell.source_row_ids]
    values = [
        Decimal(str(row.value)) * UNIT_FACTORS[row.unit] for row in rows if row.value is not None
    ]
    if not values or len(values) != len(rows) or len(set(values)) != 1:
        return None, ["sugars_unknown_value"]
    amount = values[0]
    missing = ["measured_quantity_basis_required"] if table.original_basis.amount is None else []
    return SugarApproximation(
        sugars_g=float(amount),
        cubes=float(amount / Decimal(4)),
        basis=table.original_basis,
        preparation=table.preparation,
        assessment_basis=basis,
        source_table_id=table.source_table_id,
        source_row_ids=cell.source_row_ids,
        source_ids=source_ids,
    ), missing


def _glossary_fields(ingredients: ReportSection, glossary: GlossaryStore | None) -> dict:
    if glossary is None:
        return {}
    return {
        "ingredient_insights": glossary.match(ingredients.text) if ingredients.text else [],
        "glossary_version": glossary.version,
        "glossary_artifact": glossary.artifact,
        "glossary_sources": glossary.sources(),
    }


def report_from_observation(
    body: ReportCheckRequest,
    claims_store: KnowledgeStore | None = None,
    glossary: GlossaryStore | None = None,
    *,
    now: datetime | None = None,
) -> LabelReport:
    generated = _time(now)
    observation = body.observation
    snapshot = normalize_rows(observation.rows, completeness=observation.nutrition_completeness)
    table, missing = _selected_table(snapshot, body.selected_table_id)
    warnings = list(snapshot.warnings) + ["allergen_safety_not_assessed"]
    anomaly = _quantities_need_review(snapshot)
    if snapshot.status == "needs_correction":
        missing.append("nutrition_needs_correction")
    if anomaly:
        warnings.append("nutrition_quantities_need_review")
        missing.append("nutrition_quantities_need_review")
    sugar = None
    if table is not None and snapshot.status != "needs_correction" and not anomaly:
        sugar, sugar_missing = _sugar(snapshot, table, "user_confirmed_label", [CURRENT_SOURCE])
        missing.extend(sugar_missing)

    claim_blockers = []
    if not observation.rows:
        claim_blockers.append("nutrition_not_reported")
    if body.context is None:
        claim_blockers.append("claim_context_required")
    if claims_store is None:
        claim_blockers.append("reviewed_claim_knowledge_unavailable")
    if not observation.front_confirmed:
        claim_blockers.append("front_package_confirmation_required")
    if not observation.back_confirmed:
        claim_blockers.append("back_package_confirmation_required")
    if not observation.same_product_confirmed:
        claim_blockers.append("same_product_pairing_confirmation_required")
    if table is None:
        claim_blockers.extend(missing)
    if anomaly:
        claim_blockers.append("nutrition_quantities_need_review")

    claims = [
        ReportClaim(
            claim_id=f"front-claim-{index + 1}",
            printed_text=text,
            claim=_identify(text),
            source_ids=[CURRENT_SOURCE],
            missing_inputs=_unique(claim_blockers)
            if _identify(text) is not None
            else ["claim_wording_not_identified"],
        )
        for index, text in enumerate(observation.front_claims)
    ]
    identified = [
        IdentifiedClaim(claim_id=item.claim_id, claim=item.claim, region_id=None)
        for item in claims
        if item.claim is not None
    ]
    if (
        identified
        and not claim_blockers
        and claims_store is not None
        and body.context is not None
        and table is not None
    ):
        request = ClaimsRequest(
            client_request_id=observation.submission_id,
            capture_session_id=observation.submission_id,
            input_revision=0,
            confirmed=True,
            completeness=observation.nutrition_completeness,
            rows=observation.rows,
            claims=identified,
            selected_table_id=table.source_table_id,
            context=body.context,
        )
        assessed = assess_claims(request, claims_store, now=generated)
        assessments = {item.claim_id: item for item in assessed.assessments}
        claims = [
            ReportClaim(
                claim_id=item.claim_id,
                printed_text=item.printed_text,
                claim=item.claim,
                assessment=assessments.get(item.claim_id),
                source_ids=item.source_ids,
                missing_inputs=assessments[item.claim_id].missing_inputs
                if item.claim_id in assessments
                else item.missing_inputs,
            )
            for item in claims
        ]
        warnings.extend(assessed.warnings)
    missing.extend(reason for claim in claims for reason in claim.missing_inputs)
    sections = {
        name: _current_section(getattr(observation, name))
        for name in ("ingredients", "contains", "may_contain")
    }
    missing.extend(
        f"{name}_not_captured"
        for name, section in sections.items()
        if section.status == "not_captured"
    )
    missing.extend(
        f"{name}_partial_capture"
        for name, section in sections.items()
        if section.status == "present" and section.completeness == "partial"
    )
    if glossary is None:
        warnings.append("reviewed_ingredient_glossary_unavailable")
    return LabelReport(
        backend_version=__version__,
        generated_at=generated,
        assessment_basis="user_confirmed_label",
        status="partial" if missing or snapshot.status != "complete" else "ready",
        identity=observation.identity,
        observation=contribution_facts(observation),
        nutrition=snapshot,
        selected_table_id=table.source_table_id if table is not None else body.selected_table_id,
        context=body.context,
        sugar=sugar,
        claims=claims,
        ingredients=sections["ingredients"],
        contains=sections["contains"],
        may_contain=sections["may_contain"],
        knowledge_version=claims_store.knowledge_version if claims_store is not None else None,
        missing_inputs=_unique(missing),
        warnings=_unique(warnings),
        storage=StorageOutcome(status="unavailable"),
        **_glossary_fields(sections["ingredients"], glossary),
    )


def _historical_sugar(resolved: ResolvedProduct) -> tuple[SugarApproximation | None, list[str]]:
    originals: list[tuple[str, NutritionSnapshot]] = [
        (f"community:{item.revision_id}", item.snapshot) for item in resolved.community.revisions
    ]
    off = resolved.off_snapshot
    if (
        off is not None
        and off.status == "found"
        and off.details is not None
        and off.manifest is not None
    ):
        originals.append((f"off:{off.manifest.snapshot_id}", off.details.nutrition.snapshot))
    selected: list[tuple[str, NutritionSnapshot, NutritionTable]] = []
    sugar_fields = [
        field
        for field in resolved.fields
        if field.field.endswith(".sugars") and isinstance(field.value, float)
    ]
    for source, snapshot in originals:
        if snapshot.status == "needs_correction" or _quantities_need_review(snapshot):
            continue
        for table in snapshot.tables:
            cell = table.nutrients["sugars"]
            for field in sugar_fields:
                if (
                    source in field.source_ids
                    and field.basis == table.normalized_basis
                    and field.preparation == table.preparation
                    and cell.value == field.value
                    and any(
                        alt.source_id == source
                        and alt.source_table_id == table.source_table_id
                        and alt.source_row_ids == cell.source_row_ids
                        for alt in field.alternatives
                    )
                ):
                    selected.append((source, snapshot, table))
                    break
    if len(selected) != 1:
        if len(selected) > 1:
            return None, ["selected_table_required"]
        if any(snapshot.tables for _, snapshot in originals):
            return None, ["compatible_original_sugar_table_required"]
        return None, ["nutrition_not_reported"]
    source, snapshot, table = selected[0]
    return _sugar(snapshot, table, "catalogue_historical", [source])


def report_from_resolved(
    resolved: ResolvedProduct,
    claims_store: KnowledgeStore | None = None,
    glossary: GlossaryStore | None = None,
    *,
    now: datetime | None = None,
) -> LabelReport:
    generated = _time(now)
    off = resolved.off_snapshot
    found = resolved.community.status == "found" or (off is not None and off.status == "found")
    unavailable = resolved.community.status == "unavailable" or (
        off is not None and off.status == "unavailable"
    )
    status = "partial" if found else "unavailable" if unavailable else "not_found"
    sections = {
        name: _historical_section(resolved, name)
        for name in ("ingredients", "contains", "may_contain")
    }
    sugar, missing = _historical_sugar(resolved)
    missing.extend(
        f"{name}_{section.status}"
        for name, section in sections.items()
        if section.status != "present"
    )
    missing.append("current_package_confirmation_required")
    claims_by_text: dict[str, ReportClaim] = {}
    truncated_claims = False
    for revision in resolved.community.revisions:
        for text in revision.facts.front_claims:
            if text in claims_by_text:
                current = claims_by_text[text]
                claims_by_text[text] = ReportClaim(
                    claim_id=current.claim_id,
                    printed_text=current.printed_text,
                    claim=current.claim,
                    source_ids=_unique(current.source_ids + [f"community:{revision.revision_id}"]),
                    missing_inputs=current.missing_inputs,
                )
            elif len(claims_by_text) < 16:
                claims_by_text[text] = ReportClaim(
                    claim_id=f"front-claim-{len(claims_by_text) + 1}",
                    printed_text=text,
                    claim=_identify(text),
                    source_ids=[f"community:{revision.revision_id}"],
                    missing_inputs=["current_package_confirmation_required"],
                )
            else:
                truncated_claims = True
    claims = list(claims_by_text.values())
    warnings = list(resolved.warnings) + ["dated_catalogue_facts_not_current_package_confirmation"]
    if truncated_claims:
        warnings.append("front_claim_summary_bounded_to_16")
    if glossary is None:
        warnings.append("reviewed_ingredient_glossary_unavailable")
    return LabelReport(
        backend_version=__version__,
        generated_at=generated,
        assessment_basis="catalogue_historical",
        status=status,
        resolved=resolved,
        resolved_nutrients=[
            field for field in resolved.fields if field.field.startswith("nutrition.")
        ],
        selected_table_id=sugar.source_table_id if sugar is not None else None,
        sugar=sugar,
        claims=claims,
        ingredients=sections["ingredients"],
        contains=sections["contains"],
        may_contain=sections["may_contain"],
        knowledge_version=claims_store.knowledge_version
        if claims_store is not None
        else resolved.knowledge_version,
        missing_inputs=_unique(missing),
        warnings=_unique(warnings)[:100],
        storage=StorageOutcome(status="read_only"),
        **_glossary_fields(sections["ingredients"], glossary),
    )
