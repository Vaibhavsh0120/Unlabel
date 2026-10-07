"""Resolve compatible facts while retaining each original assertion and table."""

import unicodedata
from collections import defaultdict
from dataclasses import dataclass
from datetime import UTC, date, datetime

from app.catalogue.facts import FactsLookup
from app.community.models import (
    CommunityLookup,
    CommunityRevision,
    ComparisonState,
    EvidenceState,
    FieldAlternative,
    FieldComparison,
    PreparedContribution,
    ResolvedField,
    ResolvedProduct,
)
from app.schemas.nutrition import NUTRIENT_NAMES, NutrientName, NutritionSnapshot


@dataclass(frozen=True)
class _TextEvidence:
    value: str | None
    complete: bool = True
    language: str | None = None


@dataclass(frozen=True)
class _Source:
    identifier: str
    text: dict[str, _TextEvidence]
    nutrition: NutritionSnapshot
    evidence_state: EvidenceState
    observed_on: date | None
    source_updated_at: datetime | None
    revision_context: str | None


def _fold(text: str) -> str:
    return " ".join(unicodedata.normalize("NFKC", text).casefold().split())


def _scripts(text: str) -> frozenset[str]:
    # Different scripts are not contradictory translations. This classification
    # does not translate or infer the language of a provider's unspecified text.
    return frozenset(
        unicodedata.name(character, "UNKNOWN").split()[0]
        for character in text
        if character.isalpha()
    )


def _text_comparison(field: str, sources: list[_Source]) -> FieldComparison:
    known = [
        (source.identifier, source.text[field])
        for source in sources
        if (value := source.text[field].value) is not None and value.strip()
    ]
    state: ComparisonState = "unknown"
    values = [entry.value for _, entry in known if entry.value is not None]
    if len(known) == 1:
        state = "single_source"
    elif len(known) > 1:
        languages = {entry.language for _, entry in known if entry.language is not None}
        if any(not entry.complete for _, entry in known):
            state = "not_comparable"
        elif len({_fold(value) for value in values}) == 1:
            state = "agreement"
        elif len(languages) > 1 or len({_scripts(value) for value in values}) > 1:
            state = "not_comparable"
        else:
            state = "conflict"
    return FieldComparison(
        field=field, state=state, source_ids=[identifier for identifier, _ in known]
    )


def _sources(snapshot: FactsLookup | None, community: CommunityLookup) -> list[_Source]:
    sources: list[_Source] = []
    if snapshot is not None and snapshot.status == "found":
        assert snapshot.product is not None and snapshot.details is not None
        assert snapshot.manifest is not None
        product = snapshot.product
        sources.append(
            _Source(
                identifier=f"off:{snapshot.manifest.snapshot_id}",
                text={
                    "identity.name": _TextEvidence(product.name),
                    "identity.brand": _TextEvidence(product.brands),
                    "identity.variant": _TextEvidence(None),
                    "identity.quantity": _TextEvidence(product.quantity_text),
                    "ingredients": _TextEvidence(product.ingredients_text),
                    # OFF ontology tags and literal declaration text are different
                    # representations. Empty tag arrays never prove label absence.
                    "contains": _TextEvidence(None),
                    "may_contain": _TextEvidence(None),
                },
                nutrition=snapshot.details.nutrition.snapshot,
                evidence_state="open_food_facts_community_data",
                observed_on=None,
                source_updated_at=snapshot.details.last_modified_at,
                # Client-provided context text cannot establish compatibility
                # with a provider revision lacking an explicit verified mapping.
                revision_context=None,
            )
        )
    for revision in community.revisions:
        facts = revision.facts
        text = {
            f"identity.{field}": _TextEvidence(
                getattr(facts.identity, field), language=facts.identity.language
            )
            for field in ("name", "brand", "variant", "quantity")
        }
        for field in ("ingredients", "contains", "may_contain"):
            section = getattr(facts, field)
            text[field] = _TextEvidence(
                value=section.text if section.status == "present" else None,
                complete=section.completeness == "complete",
                language=facts.identity.language,
            )
        sources.append(
            _Source(
                identifier=f"community:{revision.revision_id}",
                text=text,
                nutrition=revision.snapshot,
                evidence_state=revision.review_state,
                observed_on=facts.observed_on,
                source_updated_at=None,
                revision_context=facts.revision_context,
            )
        )
    return sources


def _nutrition_comparisons(
    sources: list[_Source], identity_conflict: bool
) -> list[FieldComparison]:
    # Contexts preserve preparation and denominator. An unmeasured serving has
    # no shared denominator and cannot be compared with another source.
    observations: dict[tuple[str, str], dict[str, dict[str, list[float]]]] = {}
    nutrient_contexts: dict[str, list[tuple[tuple[str, str], str]]] = defaultdict(list)
    for source in sources:
        for table in source.nutrition.tables:
            basis = table.normalized_basis
            denominator = (
                f"100{basis.unit}"
                if basis.kind == "quantity" and basis.amount == 100 and basis.unit is not None
                else "serving"
            )
            context = (table.preparation, denominator)
            nutrients = observations.setdefault(context, {})
            for nutrient in NUTRIENT_NAMES:
                cell = table.nutrients.get(nutrient)
                nutrient_sources = nutrients.setdefault(nutrient, {})
                if cell is not None and cell.value is not None:
                    nutrient_sources.setdefault(source.identifier, []).append(cell.value)
                    nutrient_contexts[nutrient].append((context, source.identifier))

    comparisons = []
    for context, nutrients in sorted(observations.items()):
        for nutrient in NUTRIENT_NAMES:
            known = nutrients[nutrient]
            state: ComparisonState = "unknown"
            distinct = {value for values in known.values() for value in values}
            incompatible_other_source = any(
                other_context != context and source_id not in known
                for other_context, source_id in nutrient_contexts[nutrient]
            )
            if known:
                if identity_conflict or context[1] == "serving":
                    state = "not_comparable"
                elif len(distinct) > 1:
                    state = "conflict"
                elif len(known) > 1:
                    state = "agreement"
                elif incompatible_other_source:
                    state = "not_comparable"
                else:
                    state = "single_source"
            comparisons.append(
                FieldComparison(
                    field=f"nutrition.{context[0]}.{context[1]}.{nutrient}",
                    state=state,
                    source_ids=list(known),
                )
            )
    return comparisons


def _select_equivalent(alternatives: list[FieldAlternative]) -> FieldAlternative:
    # This chooses metadata for equivalent values only. Review status never
    # resolves unequal facts and is not a source-of-truth ranking.
    order = {
        "moderator_accepted_community_assertion": 0,
        "submitter_confirmed_not_moderator_reviewed": 1,
        "open_food_facts_community_data": 2,
    }
    return min(
        alternatives,
        key=lambda item: (
            order[item.evidence_state],
            -(item.observed_on.toordinal() if item.observed_on else 0),
            item.source_id,
        ),
    )


def _resolved_field(
    field: str,
    state: ComparisonState,
    alternatives: list[FieldAlternative],
    reason: str,
    *,
    select: bool,
) -> ResolvedField:
    chosen = _select_equivalent(alternatives) if select and alternatives else None
    return ResolvedField(
        field=field,
        state=state,
        value=chosen.value if chosen else None,
        unit=chosen.unit if chosen else None,
        basis=chosen.basis if chosen else None,
        preparation=chosen.preparation if chosen else None,
        source_ids=list(dict.fromkeys(item.source_id for item in alternatives)),
        evidence_state=chosen.evidence_state if chosen else None,
        observed_on=chosen.observed_on if chosen else None,
        source_updated_at=chosen.source_updated_at if chosen else None,
        completeness=chosen.completeness if chosen else None,
        selection_reason=reason,
        alternatives=alternatives[:144],
    )


def _resolved_text(
    comparison: FieldComparison, sources: list[_Source], identity_conflict: bool
) -> ResolvedField:
    field = comparison.field
    alternatives = []
    for source in sources:
        evidence = source.text[field]
        if evidence.value is not None and evidence.value.strip():
            alternatives.append(
                FieldAlternative(
                    source_id=source.identifier,
                    value=evidence.value,
                    evidence_state=source.evidence_state,
                    observed_on=source.observed_on,
                    source_updated_at=source.source_updated_at,
                    completeness="complete" if evidence.complete else "partial",
                )
            )
    state = comparison.state
    reason = "no_known_value"
    select = state in {"single_source", "agreement"}
    if state == "conflict":
        reason = "conflicting_assertions_require_confirmation"
    elif state == "not_comparable":
        reason = "partial_or_different_language_sections"
    elif select:
        reason = (
            "compatible_whole_section"
            if not field.startswith("identity.")
            else "compatible_identity_field"
        )
        if any(item.completeness == "partial" for item in alternatives):
            select, reason = False, "partial_section_retained_as_observed"
    if identity_conflict and not field.startswith("identity.") and alternatives:
        select, state, reason = False, "not_comparable", "identity_conflict_requires_confirmation"
    return _resolved_field(field, state, alternatives, reason, select=select)


def _nutrition_alternatives(sources: list[_Source]) -> dict[str, list[FieldAlternative]]:
    observations: dict[str, list[FieldAlternative]] = defaultdict(list)
    for source in sources:
        for table in source.nutrition.tables:
            basis = table.normalized_basis
            denominator = (
                f"100{basis.unit}"
                if basis.kind == "quantity" and basis.amount == 100 and basis.unit is not None
                else "serving"
            )
            for nutrient in NUTRIENT_NAMES:
                cell = table.nutrients.get(nutrient)
                if cell is not None and cell.value is not None:
                    observations[f"nutrition.{table.preparation}.{denominator}.{nutrient}"].append(
                        FieldAlternative(
                            source_id=source.identifier,
                            value=cell.value,
                            evidence_state=source.evidence_state,
                            observed_on=source.observed_on,
                            source_updated_at=source.source_updated_at,
                            source_table_id=table.source_table_id,
                            source_row_ids=cell.source_row_ids,
                            basis=basis,
                            preparation=table.preparation,
                            unit=cell.unit,
                        )
                    )
    return observations


def _nutrition_revision_unknown(sources: list[_Source]) -> bool:
    reported = [
        source
        for source in sources
        if any(
            cell.value is not None
            for table in source.nutrition.tables
            for cell in table.nutrients.values()
        )
    ]
    if len(reported) < 2:
        return False
    contexts = {source.revision_context for source in reported}
    return None in contexts or len(contexts) != 1


def _resolved_nutrition(
    comparisons: list[FieldComparison], sources: list[_Source], identity_conflict: bool
) -> list[ResolvedField]:
    observations = _nutrition_alternatives(sources)
    revision_unknown = _nutrition_revision_unknown(sources)
    fields = []
    for comparison in comparisons:
        alternatives = observations.get(comparison.field, [])
        state = comparison.state
        select = state in {"single_source", "agreement"}
        reason = "compatible_declared_nutrient" if select else "no_known_value"
        if state == "conflict":
            reason = "conflicting_assertions_require_confirmation"
        elif state == "not_comparable":
            reason = "incompatible_identity_or_nutrition_basis"
        if alternatives and identity_conflict:
            select, state, reason = (
                False,
                "not_comparable",
                "identity_conflict_requires_confirmation",
            )
        elif alternatives and revision_unknown and state != "conflict":
            select, state, reason = False, "not_comparable", "revision_compatibility_unknown"
        fields.append(_resolved_field(comparison.field, state, alternatives, reason, select=select))
    return fields


def resolve_product(
    snapshot: FactsLookup | None,
    community: CommunityLookup,
    knowledge_version: str | None = None,
) -> ResolvedProduct:
    """Expose usable fields without treating catalogue evidence as caller confirmation."""
    if snapshot is not None and snapshot.requested_barcode != community.requested_barcode:
        raise ValueError("Source barcode does not match the requested barcode")
    sources = _sources(snapshot, community)
    comparisons = [
        _text_comparison(field, sources)
        for field in (
            "identity.name",
            "identity.brand",
            "identity.variant",
            "identity.quantity",
            "ingredients",
            "contains",
            "may_contain",
        )
    ]
    identity_conflict = any(
        item.field.startswith("identity.") and item.state == "conflict" for item in comparisons
    )
    fields = [_resolved_text(comparison, sources, identity_conflict) for comparison in comparisons]
    nutrition_comparisons = _nutrition_comparisons(sources, identity_conflict)
    fields.extend(_resolved_nutrition(nutrition_comparisons, sources, identity_conflict))
    comparisons.extend(nutrition_comparisons)
    warnings = [
        "community_assertions_not_current_label_confirmation",
        "allergen_safety_not_assessed",
        "generic_composition_not_used_for_packaged_facts",
    ]
    if identity_conflict:
        warnings.append("identity_conflict_requires_confirmation")
    if any(item.state == "conflict" for item in comparisons):
        warnings.append("sources_disagree_requires_confirmation")
    if any(item.state == "not_comparable" for item in comparisons):
        warnings.append("incompatible_or_partial_evidence_requires_confirmation")
    if _nutrition_revision_unknown(sources):
        warnings.append("revision_compatibility_unknown")
    if snapshot is not None:
        warnings.extend(snapshot.warnings)
    warnings.extend(community.warnings)
    return ResolvedProduct(
        requested_barcode=community.requested_barcode,
        off_snapshot=snapshot,
        community=community,
        knowledge_version=knowledge_version,
        comparisons=comparisons,
        fields=fields,
        warnings=list(dict.fromkeys(warnings))[:100],
    )


def contribution_conflicts(
    prepared: PreparedContribution,
    revisions: list[CommunityRevision],
    snapshot: FactsLookup | None = None,
) -> bool:
    """Admission detects contradiction; absence or repetition cannot confer trust."""
    from app.community.service import contribution_facts

    barcode = prepared.request.barcode
    if barcode is None or not prepared.auto_eligible:
        return True
    for table in prepared.snapshot.tables:
        basis = table.normalized_basis
        if basis.kind == "quantity" and basis.unit == "g" and basis.amount == 100:
            if any(
                cell.unit == "g" and cell.value is not None and cell.value > 100
                for cell in table.nutrients.values()
            ):
                return True
        subset_pairs: tuple[tuple[NutrientName, NutrientName], ...] = (
            ("added_sugars", "sugars"),
            ("saturated_fat", "fat"),
        )
        for subset, total in subset_pairs:
            subset_cell, total_cell = table.nutrients.get(subset), table.nutrients.get(total)
            if (
                subset_cell is not None
                and total_cell is not None
                and subset_cell.value is not None
                and total_cell.value is not None
                and subset_cell.value > total_cell.value
            ):
                # Printed rounding can explain a small discrepancy. Keep the
                # observation for review rather than rejecting its transcription.
                return True
    if snapshot is not None and snapshot.requested_barcode != barcode:
        raise ValueError("Baseline barcode does not match contribution")
    candidate = CommunityRevision(
        revision_id=prepared.content_sha256,
        content_sha256=prepared.content_sha256,
        factual_sha256=prepared.factual_sha256,
        barcode=barcode,
        submitted_at=datetime.now(UTC),
        reviewed_at=None,
        facts=contribution_facts(prepared.request),
        snapshot=prepared.snapshot,
        review_state="submitter_confirmed_not_moderator_reviewed",
    )
    existing = CommunityLookup(
        requested_barcode=barcode, status="found" if revisions else "not_found", revisions=revisions
    )
    incoming = CommunityLookup(requested_barcode=barcode, status="found", revisions=[candidate])
    sources = _sources(snapshot, existing) + _sources(None, incoming)
    comparisons = [
        _text_comparison(field, sources)
        for field in (
            "identity.name",
            "identity.brand",
            "identity.variant",
            "identity.quantity",
            "ingredients",
            "contains",
            "may_contain",
        )
    ]
    if any(item.state == "conflict" for item in comparisons):
        return True
    # Compare numerical declarations even when their revision compatibility is
    # unknown; differing same-basis observations require review, never a winner.
    if any(item.state == "conflict" for item in _nutrition_comparisons(sources, False)):
        return True
    return any(
        revision.facts.revision_context != prepared.request.revision_context
        and revision.factual_sha256 != prepared.factual_sha256
        for revision in revisions
    )
