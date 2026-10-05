from datetime import UTC, datetime

from pydantic import ValidationError

from app.providers.products.open_food_facts import OpenFoodFactsProvider
from app.schemas.nutrition import (
    NUTRIENT_NAMES,
    NutrientCell,
    NutrientRow,
    NutritionBasis,
    NutritionTable,
)
from app.schemas.nutrition_products import InputTableSource, NutritionLookup
from app.services.parsing.nutrition import normalize_rows

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


class NutritionProvider:
    def __init__(self, products: OpenFoodFactsProvider):
        self.products = products

    async def lookup(self, barcode: str) -> NutritionLookup:
        lookup, product = await self.products.read_product(
            barcode, "code,nutrition,last_modified_t,schema_version"
        )
        result = NutritionLookup(
            requested_barcode=barcode, status=lookup.status, source=lookup.source
        )
        if product is None:
            return result
        result.product_barcode = product["code"]
        modified = product.get("last_modified_t")
        if type(modified) is int:
            try:
                result.source.provider_modified_at = datetime.fromtimestamp(modified, UTC)
            except (OverflowError, OSError, ValueError):
                result.warnings.append("provider_modified_at_invalid")
        schema = product.get("schema_version")
        result.source.provider_schema_version = (
            schema if type(schema) is int and schema >= 0 else None
        )
        result.warnings.append("community_record_not_package_verified")
        nutrition = product.get("nutrition")
        tables = nutrition.get("input_sets") if isinstance(nutrition, dict) else None
        rows = []
        empty_tables = []
        if tables is None:
            result.warnings.append("nutrition_input_sets_missing")
        elif not isinstance(tables, list) or len(tables) > 16:
            result.warnings.append("nutrition_input_sets_invalid")
        else:
            for index, table in enumerate(tables):
                self._table(table, index, rows, empty_tables, result)
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

    def _table(self, table, index, rows, empty_tables, result):
        if not isinstance(table, dict):
            result.warnings.append("invalid_nutrition_table")
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
