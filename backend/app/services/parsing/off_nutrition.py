"""Parse reported OFF direct tables without API, acquisition, or legacy aggregation."""

from dataclasses import dataclass, field

from pydantic import ValidationError

from app.schemas.nutrition import (
    NUTRIENT_NAMES,
    NutrientCell,
    NutrientRow,
    NutritionBasis,
    NutritionSnapshot,
    NutritionTable,
)
from app.schemas.nutrition_products import InputTableSource
from app.services.parsing.nutrition import normalize_rows


@dataclass
class DirectNutritionResult:
    snapshot: NutritionSnapshot | None = None
    input_tables: list[InputTableSource] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


NUTRIENTS = {
    "energy-kcal": "energy",
    "energy-kj": "energy",
    "fat": "fat",
    "saturated-fat": "saturated_fat",
    "carbohydrates": "carbohydrates",
    "carbohydrates-total": "carbohydrates_total",
    "sugars": "sugars",
    "added-sugars": "added_sugars",
    "fiber": "fibre",
    "proteins": "protein",
    "sodium": "sodium",
    "salt": "salt",
}


def parse_direct_nutrition(nutrition: object) -> DirectNutritionResult:
    result = DirectNutritionResult()
    tables = nutrition.get("input_sets") if isinstance(nutrition, dict) else None
    rows = []
    empty_tables = []
    if tables is None:
        result.warnings.append("nutrition_input_sets_missing")
    elif not isinstance(tables, list) or len(tables) > 16:
        result.warnings.append("nutrition_input_sets_invalid")
    else:
        for index, table in enumerate(tables):
            _table(table, index, rows, empty_tables, result)
    result.snapshot = normalize_rows(rows, completeness="partial")
    result.snapshot.tables.extend(empty_tables)
    result.snapshot.tables.sort(key=lambda table: int(table.source_table_id.rsplit("-", 1)[1]))
    for index, first in enumerate(result.snapshot.tables):
        for second in result.snapshot.tables[index + 1 :]:
            if (
                first.preparation != second.preparation
                or first.normalized_basis.kind != "quantity"
                or first.normalized_basis != second.normalized_basis
            ):
                continue
            if any(
                first.nutrients[key].value is not None
                and second.nutrients[key].value is not None
                and first.nutrients[key].value != second.nutrients[key].value
                for key in NUTRIENT_NAMES
            ):
                result.snapshot.status = "needs_correction"
                result.warnings.append("provider_tables_disagree")
    result.warnings = list(dict.fromkeys(result.warnings))
    return result


def _table(table, index, rows, empty_tables, result):
    if not isinstance(table, dict):
        result.warnings.append("invalid_nutrition_table")
        return
    projected_count = table.get("source_nutrient_count")
    if table.get("invalid_source_nutrient_count") is True or (
        projected_count is not None
        and (type(projected_count) is not int or not 0 <= projected_count <= 200)
    ):
        result.warnings.append("invalid_table_nutrients")
        return
    source = table.get("source")
    if source not in ("packaging", "manufacturer"):
        result.warnings.append("unsupported_table_source")
        return
    preparation = {"as_sold": "as_sold", "prepared": "as_prepared"}.get(
        table.get("preparation") if isinstance(table.get("preparation"), str) else ""
    )
    if preparation is None:
        result.warnings.append("unsupported_table_preparation")
        return
    per = table.get("per")
    amount, unit = table.get("per_quantity"), table.get("per_unit")
    if per not in ("100g", "100ml", "serving"):
        result.warnings.append("invalid_table_basis")
        return
    if per in ("100g", "100ml") and (
        type(amount) not in (int, float)
        or amount != 100
        or unit != ("g" if per == "100g" else "ml")
    ):
        result.warnings.append("invalid_table_basis")
        return
    try:
        basis = NutritionBasis(
            kind="serving" if per == "serving" else "quantity",
            amount=amount,
            unit="mL" if unit == "ml" else unit,
        )
    except ValidationError:
        result.warnings.append("invalid_table_basis")
        return
    values = table.get("nutrients")
    if not isinstance(values, dict) or len(values) > 200:
        result.warnings.append("invalid_table_nutrients")
        return
    table_id = f"off-table-{index}"
    table_rows = []
    for key, nutrient in NUTRIENTS.items():
        value = values.get(key)
        if value is None:
            continue
        if not isinstance(value, dict):
            result.warnings.append("invalid_nutrient_value")
            continue
        if value.get("modifier") is not None:
            result.warnings.append("qualified_value_excluded")
            continue
        if "value" not in value:
            result.warnings.append("computed_or_missing_value_excluded")
            continue
        if key in ("energy-kcal", "energy-kj") and value.get("unit") != (
            "kcal" if key == "energy-kcal" else "kJ"
        ):
            result.warnings.append("invalid_nutrient_value")
            continue
        try:
            row = NutrientRow(
                row_id=f"{table_id}-{key}",
                table_id=table_id,
                nutrient=nutrient,
                value=value["value"],
                unit=value.get("unit"),
                basis=basis,
                preparation=preparation,
            )
        except ValidationError:
            result.warnings.append("invalid_nutrient_value")
            continue
        table_rows.append(row)
    if not table_rows:
        empty_tables.append(
            NutritionTable(
                source_table_id=table_id,
                preparation=preparation,
                original_basis=basis,
                normalized_basis=(
                    NutritionBasis(kind="quantity", amount=100, unit=basis.unit)
                    if basis.amount is not None
                    else basis
                ),
                nutrients={
                    key: NutrientCell(
                        value=None,
                        reason="not_reported",
                        unit="kcal" if key == "energy" else "g",
                    )
                    for key in NUTRIENT_NAMES
                },
            )
        )
    if len(rows) + len(table_rows) > 64:
        result.warnings.append("nutrition_row_budget_exceeded")
        return
    result.input_tables.append(InputTableSource(table_id=table_id, provider_source=source))
    rows.extend(table_rows)
