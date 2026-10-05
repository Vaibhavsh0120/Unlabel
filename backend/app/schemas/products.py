from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

LookupStatus = Literal["found", "not_found", "rate_limited", "unavailable", "incompatible_response"]


class ContractModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class ProviderInsights(ContractModel):
    provider: Literal["open_food_facts"] = "open_food_facts"
    nutri_score_grade: Literal["a", "b", "c", "d", "e"] | None = None
    nova_group: int | None = Field(default=None, ge=1, le=4)


class Product(ContractModel):
    barcode: str
    name: str | None = None
    brands: str | None = None
    quantity_text: str | None = None
    ingredients_text: str | None = None
    allergen_tags: list[str] = Field(default_factory=list)
    trace_tags: list[str] = Field(default_factory=list)
    insights: ProviderInsights = Field(default_factory=ProviderInsights)


class Source(ContractModel):
    provider: Literal["open_food_facts"] = "open_food_facts"
    upstream_api_version: Literal["3.6"] = "3.6"
    adapter_version: Literal["1"] = "1"
    product_url: str
    retrieved_at: datetime
    provider_modified_at: datetime | None = None
    provider_schema_version: int | None = None
    attribution: str = "Product data from Open Food Facts"
    database_license: Literal["ODbL-1.0"] = "ODbL-1.0"
    contents_license: Literal["DbCL-1.0"] = "DbCL-1.0"
    license_url: str = "https://openfoodfacts.org/terms-of-use"


class ProductLookup(ContractModel):
    schema_version: Literal["1"] = "1"
    requested_barcode: str
    status: LookupStatus
    source: Source
    product: Product | None = None
    warnings: list[str] = Field(default_factory=list)
