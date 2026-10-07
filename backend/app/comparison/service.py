"""Exact original-row arithmetic and at most two read-only source resolutions."""

from collections.abc import Callable
from datetime import UTC, datetime
from fractions import Fraction
from math import isfinite

from app import __version__
from app.catalogue.facts import FactsLookup
from app.community.models import CommunityLookup
from app.community.store import StoreConflict, StoreQuotaExceeded, StoreUnavailable
from app.comparison.models import (
    CommunityInput,
    CommunitySource,
    ComparisonCell,
    ComparisonIdentity,
    ComparisonRequest,
    ComparisonResponse,
    ComparisonSide,
    CurrentInput,
    CurrentSource,
    NutrientComparison,
    OffInput,
    OffSource,
)
from app.schemas.nutrition import NUTRIENT_NAMES, NutrientRow, NutritionBasis, NutritionSnapshot
from app.services.parsing.nutrition import UNIT_FACTORS, normalize_rows
from app.services.parsing.nutrition_checks import quantities_need_review


def _select(side: ComparisonSide, snapshot: NutritionSnapshot, *, warnings=()) -> ComparisonSide:
    matches = [
        table for table in snapshot.tables if table.source_table_id == side.selected_table_id
    ]
    reasons = list(warnings)
    if not matches:
        reasons.append("selected_table_missing")
    elif len(matches) != 1:
        reasons.append("selected_table_ambiguous")
    if snapshot.status == "needs_correction":
        reasons.append("nutrition_needs_correction")
    if quantities_need_review(snapshot):
        reasons.append("nutrition_quantities_need_review")
    if "provider_tables_disagree" in warnings:
        reasons.append("provider_tables_disagree")
    blocked = bool(reasons)
    return ComparisonSide.model_validate(
        {
            **side.model_dump(),
            "snapshot": snapshot,
            "selected_table": matches[0] if len(matches) == 1 else None,
            "status": "needs_correction" if blocked else "ready",
            "warnings": list(dict.fromkeys([*side.warnings, *reasons, *snapshot.warnings]))[:100],
        }
    )


def compare(
    request: ComparisonRequest,
    *,
    off_lookup: Callable[[str], FactsLookup],
    community_lookup: Callable[[str], CommunityLookup],
    generated_at: datetime | None = None,
) -> ComparisonResponse:
    reads: dict[tuple[str, str], FactsLookup | CommunityLookup | None] = {}

    def resolve(value) -> ComparisonSide:
        current = isinstance(value, CurrentInput)
        side = ComparisonSide(
            status="unavailable",
            requested_kind=value.kind,
            requested_reference=None if current else value,
            selected_table_id=value.selected_table_id,
            assessment_basis="user_confirmed_label" if current else "catalogue_historical",
        )
        if current:
            observation = value.observation
            assert observation.capture_method in ("manual", "ocr_corrected")
            identity = observation.identity
            side = side.model_copy(
                update={
                    "identity": ComparisonIdentity(
                        barcode=observation.barcode,
                        name=identity.name,
                        brand=identity.brand,
                        quantity=identity.quantity,
                        variant=identity.variant,
                    ),
                    "source": CurrentSource(
                        submission_id=observation.submission_id,
                        observed_on=observation.observed_on,
                        capture_method=observation.capture_method,
                    ),
                }
            )
            return _select(
                side,
                normalize_rows(observation.rows, completeness=observation.nutrition_completeness),
            )

        key = (value.kind, value.barcode)
        if key not in reads:
            try:
                reads[key] = (
                    off_lookup(value.barcode)
                    if isinstance(value, OffInput)
                    else community_lookup(value.barcode)
                )
            except (StoreConflict, StoreQuotaExceeded, StoreUnavailable, OSError, ValueError):
                reads[key] = None
        lookup = reads[key]
        if lookup is None or lookup.status == "unavailable":
            return side.model_copy(update={"warnings": ["source_unavailable"]})
        if lookup.status == "not_found":
            return side.model_copy(update={"status": "not_found", "warnings": ["source_not_found"]})
        if isinstance(value, OffInput):
            assert isinstance(lookup, FactsLookup)
            manifest, details, product = lookup.manifest, lookup.details, lookup.product
            assert manifest is not None and details is not None and product is not None
            if (
                manifest.snapshot_id != value.snapshot_id
                or manifest.source_sha256 != value.source_sha256
            ):
                return side.model_copy(
                    update={"status": "source_changed", "warnings": ["source_reference_changed"]}
                )
            sources = [
                item
                for item in details.nutrition.input_tables
                if item.table_id == value.selected_table_id
            ]
            if details.nutrition.availability != "direct_tables" or len(sources) != 1:
                return side.model_copy(update={"warnings": ["direct_source_table_unavailable"]})
            side = side.model_copy(
                update={
                    "identity": ComparisonIdentity(
                        barcode=product.barcode,
                        name=product.name,
                        brand=product.brands,
                        quantity=product.quantity_text,
                    ),
                    "source": OffSource(
                        source_id=f"off:{manifest.snapshot_id}",
                        manifest=manifest,
                        record_modified_at=details.last_modified_at,
                        provider_source=sources[0].provider_source,
                    ),
                    "warnings": lookup.warnings,
                }
            )
            blockers = [
                reason
                for reason in details.nutrition.warnings
                if reason == "provider_tables_disagree"
            ]
            return _select(side, details.nutrition.snapshot, warnings=blockers)
        assert isinstance(value, CommunityInput) and isinstance(lookup, CommunityLookup)
        revisions = [
            revision for revision in lookup.revisions if revision.revision_id == value.revision_id
        ]
        if not revisions:
            return side.model_copy(
                update={"status": "not_found", "warnings": ["active_public_revision_not_found"]}
            )
        revision = revisions[0]
        if revision.factual_sha256 != value.factual_sha256:
            return side.model_copy(
                update={"status": "source_changed", "warnings": ["source_reference_changed"]}
            )
        identity = revision.facts.identity
        side = side.model_copy(
            update={
                "identity": ComparisonIdentity(
                    barcode=revision.barcode,
                    name=identity.name,
                    brand=identity.brand,
                    quantity=identity.quantity,
                    variant=identity.variant,
                ),
                "source": CommunitySource(
                    source_id=f"community:{revision.revision_id}",
                    revision_id=revision.revision_id,
                    factual_sha256=revision.factual_sha256,
                    observed_on=revision.facts.observed_on,
                    submitted_at=revision.submitted_at,
                    reviewed_at=revision.reviewed_at,
                    review_state=revision.review_state,
                ),
                "warnings": lookup.warnings,
            }
        )
        return _select(
            side,
            revision.snapshot,
            warnings=[
                reason for reason in lookup.warnings if reason == "product_conflict_requires_review"
            ],
        )

    a, b = resolve(request.a), resolve(request.b)
    basis = None
    reason = None
    if a.status != "ready" or b.status != "ready":
        reason = "source_needs_attention"
    else:
        left, right = a.selected_table, b.selected_table
        assert left is not None and right is not None
        if left.preparation != right.preparation:
            reason = "preparation_mismatch"
        elif left.original_basis.amount is None or right.original_basis.amount is None:
            reason = "measured_quantity_basis_required"
        elif left.original_basis.unit != right.original_basis.unit:
            reason = "mass_volume_mismatch"
        else:
            basis = NutritionBasis(kind="quantity", amount=100.0, unit=left.original_basis.unit)

    def cell(side: ComparisonSide, nutrient: str):
        unit = "kcal" if nutrient == "energy" else "g"
        if side.snapshot is None or side.selected_table is None:
            return ComparisonCell(unit=unit, reason="source_unavailable"), None
        table = side.selected_table
        rows = [
            row
            for row in side.snapshot.original_rows
            if row.table_id == table.source_table_id and row.nutrient == nutrient
        ]
        ids = [row.row_id for row in rows]
        if side.status != "ready":
            return ComparisonCell(
                unit=unit, reason="source_needs_correction", source_row_ids=ids
            ), None
        if not rows or any(row.value is None for row in rows):
            return ComparisonCell(
                unit=unit, reason="unknown_value" if rows else "not_reported", source_row_ids=ids
            ), None
        if table.original_basis.amount is None:
            return ComparisonCell(
                unit=unit, reason="measured_quantity_basis_required", source_row_ids=ids
            ), None
        values = [_exact(row) for row in rows]
        if len(set(values)) != 1:
            return ComparisonCell(unit=unit, reason="conflicting_values", source_row_ids=ids), None
        value = values[0]
        output = _bounded_float(value)
        if output is None:
            return ComparisonCell(
                unit=unit, reason="conversion_out_of_bounds", source_row_ids=ids
            ), None
        return ComparisonCell(unit=unit, value=output, source_row_ids=ids), value

    nutrients = []
    for nutrient in NUTRIENT_NAMES:
        ac, av = cell(a, nutrient)
        bc, bv = cell(b, nutrient)
        delta = None
        lower = None
        missing = reason or ("nutrient_unknown" if av is None or bv is None else None)
        if missing is None:
            assert av is not None and bv is not None
            exact = bv - av
            delta = _bounded_float(exact)
            if delta is None:
                missing = "conversion_out_of_bounds"
            else:
                lower = "a" if exact > 0 else "b" if exact < 0 else "equal"
        nutrients.append(
            NutrientComparison(
                nutrient=nutrient, a=ac, b=bc, difference=delta, lower=lower, reason=missing
            )
        )
    available = sum(row.difference is not None for row in nutrients)
    return ComparisonResponse(
        backend_version=__version__,
        generated_at=generated_at or datetime.now(UTC),
        client_request_id=request.client_request_id,
        comparison_session_id=request.comparison_session_id,
        input_revision=request.input_revision,
        status="not_comparable" if basis is None else "ready" if available == 11 else "partial",
        comparison_basis=basis,
        preparation=a.selected_table.preparation if basis and a.selected_table is not None else None,
        a=a,
        b=b,
        nutrients=nutrients,
        warnings=[reason] if reason else [],
    )


def _exact(row: NutrientRow) -> Fraction:
    value = Fraction(str(row.value))
    value = (
        value / Fraction("4.184") if row.unit == "kJ" else value * Fraction(UNIT_FACTORS[row.unit])
    )
    return value * 100 / Fraction(str(row.basis.amount))


def _bounded_float(value: Fraction) -> float | None:
    if abs(value) > 1_000_000_000:
        return None
    number = float(value)
    return number if isfinite(number) and (not value or number != 0) else None
