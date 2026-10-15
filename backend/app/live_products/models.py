"""Display-only vendor facts. These models are not report or admission inputs."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class LiveField(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    section: Literal["ingredients", "allergens", "nutrition"]
    label: str
    value: str
    sources: tuple[str, ...] = ()


class LiveProduct(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    barcode: str
    name: str | None = None
    brand: str | None = None
    evidence: Literal["external_provider_unverified"] = "external_provider_unverified"
    fields: tuple[LiveField, ...] = ()
    sources: tuple[str, ...] = ()
    retrieved_at: datetime
    expires_at: datetime
    attribution: Literal["Data by NutriGraphAPI"] = "Data by NutriGraphAPI"
    attribution_url: Literal["https://nutrigraphapi.com"] = "https://nutrigraphapi.com"


class LiveLookup(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    status: Literal[
        "found", "disabled", "unsupported_barcode", "not_found", "rate_limited", "unavailable"
    ]
    requested_barcode: str
    product: LiveProduct | None = None
    retry_after: int | None = Field(default=None, ge=0)
