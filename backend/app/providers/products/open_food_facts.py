import asyncio
import json
import re
from datetime import UTC, datetime

import httpx

from app.core.config import Settings
from app.core.json_numbers import checked_float, reject_constant
from app.schemas.products import Product, ProductLookup, ProviderInsights, Source

BARCODE_PATTERN = r"^(?:[0-9]{8}|[0-9]{12,14})$"
FIELDS = ",".join(
    [
        "code",
        "product_name",
        "brands",
        "quantity",
        "ingredients_text",
        "allergens_tags",
        "traces_tags",
        "nutriscore_grade",
        "nova_group",
        "last_modified_t",
        "schema_version",
    ]
)


class OpenFoodFactsProvider:
    def __init__(self, client: httpx.AsyncClient, settings: Settings):
        self.client = client
        self.settings = settings

    async def read_product(
        self, barcode: str, fields: str = FIELDS
    ) -> tuple[ProductLookup, dict | None]:
        """Bounded identity-checked transport, shared by separate public adapters."""
        if not re.fullmatch(BARCODE_PATTERN, barcode):
            raise ValueError("Unsupported barcode format")
        source = Source(
            product_url=f"https://world.openfoodfacts.org/product/{barcode}",
            retrieved_at=datetime.now(UTC),
        )
        result = ProductLookup(requested_barcode=barcode, status="unavailable", source=source)
        if not self.settings.off_enabled:
            return result, None
        try:
            async with asyncio.timeout(self.settings.off_timeout_seconds):
                async with self.client.stream(
                    "GET",
                    f"https://world.openfoodfacts.org/api/v3.6/product/{barcode}.json",
                    params={"fields": fields},
                    headers={
                        "User-Agent": self.settings.off_user_agent,
                        "Accept": "application/json",
                    },
                    follow_redirects=False,
                ) as response:
                    if response.status_code == 404:
                        result.status = "not_found"
                        return result, None
                    if response.status_code == 429:
                        result.status = "rate_limited"
                        return result, None
                    if response.status_code != 200:
                        return result, None
                    body = bytearray()
                    async for chunk in response.aiter_bytes():
                        body.extend(chunk)
                        if len(body) > self.settings.off_max_response_bytes:
                            result.status = "incompatible_response"
                            return result, None
                    data = json.loads(
                        body, parse_float=checked_float, parse_constant=reject_constant
                    )
        except (httpx.HTTPError, TimeoutError):
            return result, None
        except (ValueError, UnicodeDecodeError, RecursionError):
            result.status = "incompatible_response"
            return result, None

        if not isinstance(data, dict):
            result.status = "incompatible_response"
            return result, None
        if isinstance(data.get("result"), dict) and data["result"].get("id") == "product_not_found":
            result.status = "not_found"
            return result, None
        product = data.get("product")
        if data.get("status") != "success" or not isinstance(product, dict):
            result.status = "incompatible_response"
            return result, None
        code = product.get("code")
        if (
            not isinstance(code, str)
            or not re.fullmatch(BARCODE_PATTERN, code)
            or code.lstrip("0") != barcode.lstrip("0")
        ):
            result.status = "incompatible_response"
            return result, None

        result.status = "found"
        result.source.product_url = f"https://world.openfoodfacts.org/product/{code}"
        return result, product

    async def lookup(self, barcode: str) -> ProductLookup:
        result, product = await self.read_product(barcode)
        if product is None:
            return result
        source = result.source
        code = product["code"]

        warnings = ["community_record_not_package_verified", "allergen_safety_not_assessed"]

        def valid_text(value: object, limit: int) -> bool:
            return (
                isinstance(value, str)
                and len(value) <= limit
                and not any("\ud800" <= character <= "\udfff" for character in value)
            )

        def text(field: str, limit: int = 2000) -> str | None:
            value = product.get(field)
            if value is None or value == "":
                return None
            if not valid_text(value, limit):
                warnings.append(f"{field}_invalid")
                return None
            return value.strip() or None

        def tags(field: str) -> list[str]:
            value = product.get(field)
            if value is None:
                warnings.append(f"{field}_missing")
                return []
            if (
                not isinstance(value, list)
                or len(value) > 100
                or any(not valid_text(tag, 256) for tag in value)
            ):
                warnings.append(f"{field}_invalid")
                return []
            return value

        ingredients = text("ingredients_text", 16_000)
        if ingredients is None:
            warnings.append("ingredients_missing")
        grade = product.get("nutriscore_grade")
        grade = grade if isinstance(grade, str) and grade in {"a", "b", "c", "d", "e"} else None
        nova = product.get("nova_group")
        nova = nova if type(nova) is int and 1 <= nova <= 4 else None
        modified = product.get("last_modified_t")
        if type(modified) is int:
            try:
                source.provider_modified_at = datetime.fromtimestamp(modified, UTC)
            except (OverflowError, OSError, ValueError):
                warnings.append("provider_modified_at_invalid")
        schema = product.get("schema_version")
        source.provider_schema_version = schema if type(schema) is int and schema >= 0 else None
        source.product_url = f"https://world.openfoodfacts.org/product/{code}"
        result.status = "found"
        result.product = Product(
            barcode=code,
            name=text("product_name"),
            brands=text("brands"),
            quantity_text=text("quantity"),
            ingredients_text=ingredients,
            allergen_tags=tags("allergens_tags"),
            trace_tags=tags("traces_tags"),
            insights=ProviderInsights.model_validate(
                {"nutri_score_grade": grade, "nova_group": nova}
            ),
        )
        result.warnings = warnings
        return result
