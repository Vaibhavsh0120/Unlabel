from datetime import UTC, datetime

from app.providers.products.open_food_facts import OpenFoodFactsProvider
from app.schemas.nutrition_products import NutritionLookup
from app.services.parsing.off_nutrition import parse_direct_nutrition


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
        direct = parse_direct_nutrition(product.get("nutrition"))
        result.snapshot = direct.snapshot
        result.input_tables = direct.input_tables
        result.warnings = list(dict.fromkeys([*result.warnings, *direct.warnings]))
        return result
