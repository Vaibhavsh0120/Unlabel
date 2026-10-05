from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import Field

from app.schemas.nutrition import NutritionSnapshot
from app.schemas.products import ContractModel, LookupStatus, Source


class InputTableSource(ContractModel):
    table_id: str
    provider_source: Literal["packaging", "manufacturer"]


class NutritionLookup(ContractModel):
    schema_version: Literal["1"] = "1"
    nutrition_adapter_version: Literal["1"] = "1"
    requested_barcode: str
    product_barcode: str | None = None
    status: LookupStatus
    source: Source
    assessment_basis: Literal["open_food_facts_community_data"] = "open_food_facts_community_data"
    input_tables: list[InputTableSource] = Field(default_factory=list)
    snapshot: NutritionSnapshot | None = None
    warnings: list[str] = Field(default_factory=list)


class NormalizeResponse(ContractModel):
    schema_version: Literal["1"] = "1"
    client_request_id: UUID
    capture_session_id: UUID
    input_revision: int
    normalized_at: datetime
    assessment_basis: Literal["user_confirmed_label"] = "user_confirmed_label"
    snapshot: NutritionSnapshot
