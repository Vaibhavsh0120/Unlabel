from collections import defaultdict
from decimal import Decimal

from app.schemas.nutrition import (
    NUTRIENT_NAMES,
    Completeness,
    NutrientCell,
    NutrientRow,
    NutritionBasis,
    NutritionSnapshot,
    NutritionTable,
)

UNIT_FACTORS = {
    "g": Decimal(1),
    "mg": Decimal("0.001"),
    "ug": Decimal("0.000001"),
    "kcal": Decimal(1),
}
MAX_CANONICAL_VALUE = Decimal("1000000000")


def canonical_value(row: NutrientRow) -> Decimal | None:
    """Convert units and scale only within a supplied mass or volume basis."""
    if row.value is None:
        return None
    value = Decimal(str(row.value))
    if row.unit == "kJ":
        value /= Decimal("4.184")
    else:
        value *= UNIT_FACTORS[row.unit]
    if row.basis.amount is not None:
        value *= Decimal(100) / Decimal(str(row.basis.amount))
    return value


def conversion_description(rows: list[NutrientRow]) -> str:
    descriptions = []
    for row in rows:
        canonical_unit = "kcal" if row.nutrient == "energy" else "g"
        unit_conversion = (
            f"{row.unit} to {canonical_unit}"
            if row.unit != canonical_unit
            else f"{canonical_unit} unchanged"
        )
        if unit_conversion not in descriptions:
            descriptions.append(unit_conversion)
    basis = rows[0].basis
    if basis.amount is None:
        descriptions.append("retained per serving; serving mass or volume not supplied")
    else:
        descriptions.append(f"scaled from {basis.amount:g} {basis.unit} to 100 {basis.unit}")
    return "; ".join(descriptions)


def normalize_rows(
    rows: list[NutrientRow], *, completeness: Completeness = "partial"
) -> NutritionSnapshot:
    """Normalize submitted facts without nutritional, allergy or legal judgments.

    Separate table contexts remain separate. A complete result means submitted
    values converted successfully, never that every nutrient was reported.
    """
    identifiers = [row.row_id for row in rows]
    if len(identifiers) != len(set(identifiers)):
        raise ValueError("row_id values must be unique")

    warnings: list[str] = []
    needs_correction = False
    partial = completeness == "partial" or not rows
    if completeness == "partial":
        warnings.append("partial_capture")
    if not rows:
        warnings.append("nutrition_not_reported")

    groups: dict[tuple, list[NutrientRow]] = defaultdict(list)
    contexts: dict[str, set[tuple]] = defaultdict(set)
    for row in rows:
        context = (row.preparation, row.basis.kind, row.basis.amount, row.basis.unit)
        contexts[row.table_id].add(context)
        groups[(row.table_id, *context)].append(row)
    if any(len(table_contexts) > 1 for table_contexts in contexts.values()):
        needs_correction = True
        warnings.append("inconsistent_table_context")

    tables = []
    for grouped_rows in groups.values():
        first = grouped_rows[0]
        basis_known = first.basis.amount is not None
        normalized_basis = (
            NutritionBasis(kind="quantity", amount=100, unit=first.basis.unit)
            if basis_known
            else NutritionBasis(kind="serving", amount=None, unit=None)
        )
        if not basis_known:
            partial = True
            warnings.append("conversion_missing_basis")
        nutrient_rows: dict[str, list[NutrientRow]] = defaultdict(list)
        for row in grouped_rows:
            nutrient_rows[row.nutrient].append(row)
        cells = {}
        for nutrient in NUTRIENT_NAMES:
            relevant = nutrient_rows[nutrient]
            unit = "kcal" if nutrient == "energy" else "g"
            if not relevant:
                cells[nutrient] = NutrientCell(value=None, unit=unit, reason="not_reported")
                continue
            converted = [canonical_value(row) for row in relevant]
            known = [value for value in converted if value is not None]
            if len(known) != len(converted):
                partial = True
                warnings.append("unknown_nutrient_values")
            cell_arguments = {
                "unit": unit,
                "source_row_ids": [row.row_id for row in relevant],
                "conversion": conversion_description(relevant),
            }
            if any(
                value > MAX_CANONICAL_VALUE or (value != 0 and float(value) == 0) for value in known
            ):
                needs_correction = True
                warnings.append("conversion_out_of_bounds")
                cell = NutrientCell(value=None, reason="conversion_out_of_bounds", **cell_arguments)
            elif len(set(known)) > 1:
                needs_correction = True
                warnings.append("conflicting_nutrient_values")
                cell = NutrientCell(value=None, reason="conflicting_values", **cell_arguments)
            elif not known:
                cell = NutrientCell(value=None, reason="unknown_value", **cell_arguments)
            else:
                cell = NutrientCell(
                    value=float(known[0]),
                    reason=None if basis_known else "conversion_missing_basis",
                    **cell_arguments,
                )
            cells[nutrient] = cell
        tables.append(
            NutritionTable(
                source_table_id=first.table_id,
                preparation=first.preparation,
                original_basis=first.basis.model_copy(deep=True),
                normalized_basis=normalized_basis,
                nutrients=cells,
            )
        )
    return NutritionSnapshot(
        status="needs_correction" if needs_correction else "partial" if partial else "complete",
        tables=tables,
        original_rows=[row.model_copy(deep=True) for row in rows],
        warnings=list(dict.fromkeys(warnings)),
    )
