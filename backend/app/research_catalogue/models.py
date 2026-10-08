"""Strict source observations and separate researched-product HTTP contracts."""

import hashlib
import json
import math
import re
import unicodedata
from datetime import UTC, datetime, timedelta
from typing import Annotated, Literal, Self
from urllib.parse import parse_qsl, urlsplit

from pydantic import BaseModel, ConfigDict, Field, JsonValue, field_validator, model_validator

SCHEMA = "popular-india-research-v1"
HASH_PATTERN = r"^[0-9a-f]{64}$"
BARCODE_PATTERN = r"^(?:[0-9]{8}|[0-9]{12,14})$"
PUBLIC_TEXT = Annotated[str, Field(min_length=1, max_length=2000)]
Sha256 = Annotated[str, Field(pattern=HASH_PATTERN)]
Provider = Literal["open_food_facts", "manufacturer", "retailer"]
Eligibility = Literal["exact_sku", "brand_family_only", "identity_unconfirmed"]
MAX_RECORD_BYTES = 256 * 1024


def canonical(value: object) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False
    ).encode("utf-8")


def public_url(value: str) -> str:
    try:
        parsed = urlsplit(value)
        if (
            len(value) > 2048
            or not value.isascii()
            or any(c.isspace() for c in value)
            or parsed.scheme != "https"
            or not parsed.hostname
            or parsed.username is not None
            or parsed.password is not None
            or parsed.port not in {None, 443}
            or parsed.fragment
            or any(
                re.search(r"token|password|secret|api.?key|authorization", key, re.I)
                for key, _ in parse_qsl(parsed.query)
            )
        ):
            raise ValueError("Research sources require public HTTPS URLs")
    except ValueError as error:
        raise ValueError("Research sources require public HTTPS URLs") from error
    return value


def aware_date(value: str | None) -> str | None:
    if value is None:
        return None
    try:
        if len(value) > 64 or "T" not in value:
            raise ValueError("Research timestamps require a timezone")
        date = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if date.utcoffset() is None or date > datetime.now(UTC) + timedelta(days=1):
            raise ValueError("Research timestamp is unaware or in the future")
    except (ValueError, OverflowError) as error:
        raise ValueError("Research timestamp is invalid") from error
    return value


def bounded_json(value: JsonValue, depth: int = 0) -> JsonValue:
    if depth > 8:
        raise ValueError("Research metadata depth bounds exceeded")
    if isinstance(value, str):
        if len(value) > 16000 or any(
            unicodedata.category(c) in {"Cc", "Cs"} and c not in "\n\r\t" for c in value
        ):
            raise ValueError("Research metadata text bounds exceeded")
    elif isinstance(value, (int, float)):
        if not math.isfinite(value) or abs(value) > 10**12:
            raise ValueError("Research metadata numeric bounds exceeded")
    elif isinstance(value, list):
        if len(value) > 200:
            raise ValueError("Research metadata list bounds exceeded")
        for item in value:
            bounded_json(item, depth + 1)
    elif isinstance(value, dict):
        if len(value) > 200:
            raise ValueError("Research metadata object bounds exceeded")
        for key, item in value.items():
            if (
                not key
                or len(key) > 128
                or key.casefold()
                in {
                    "creator",
                    "editors",
                    "uploader",
                    "user_id",
                    "uid",
                    "email",
                    "password",
                    "token",
                    "api_key",
                    "raw_ocr",
                    "photo",
                    "image_bytes",
                    "service_account",
                    "private_key",
                }
            ):
                raise ValueError("Research metadata cannot contain private source identities")
            bounded_json(item, depth + 1)
    return value


class ResearchModel(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True, strict=True, validate_default=True)


class ResearchLicense(ResearchModel):
    database: PUBLIC_TEXT | None
    contents: PUBLIC_TEXT | None
    images: PUBLIC_TEXT | None
    note: PUBLIC_TEXT | None
    reuse_status: Annotated[str, Field(min_length=1, max_length=128)]


class ResearchSource(ResearchModel):
    provider: Provider
    url: Annotated[str, Field(min_length=1, max_length=2048)]
    retrieved_at: Annotated[str, Field(min_length=1, max_length=64)]
    source_updated_at: Annotated[str, Field(min_length=1, max_length=64)] | None
    license: ResearchLicense

    _url = field_validator("url")(public_url)
    _dates = field_validator("retrieved_at", "source_updated_at")(aware_date)

    @model_validator(mode="after")
    def ordered_dates(self) -> Self:
        if self.source_updated_at is not None and datetime.fromisoformat(
            self.source_updated_at.replace("Z", "+00:00")
        ) > datetime.fromisoformat(self.retrieved_at.replace("Z", "+00:00")):
            raise ValueError("Research source modification cannot be after retrieval")
        if self.provider == "open_food_facts" and urlsplit(self.url).hostname not in {
            "world.openfoodfacts.org",
            "in.openfoodfacts.org",
            "en.openfoodfacts.org",
        }:
            raise ValueError("OFF research source must use an official product origin")
        return self


class ResearchIdentity(ResearchModel):
    barcode: Annotated[str, Field(pattern=BARCODE_PATTERN)] | None
    name: PUBLIC_TEXT | None
    brand: Annotated[str, Field(min_length=1, max_length=256)] | None
    variant: Annotated[str, Field(min_length=1, max_length=256)] | None
    quantity: Annotated[str, Field(min_length=1, max_length=256)] | None
    market: Literal["india", "unknown"]
    match: Eligibility
    barcode_evidence_url: Annotated[str, Field(min_length=1, max_length=2048)] | None

    @field_validator("barcode_evidence_url")
    @classmethod
    def evidence_url(cls, value: str | None) -> str | None:
        return public_url(value) if value is not None else None

    @model_validator(mode="after")
    def exact_identity(self) -> Self:
        if self.match == "exact_sku" and (
            self.barcode is None
            or self.barcode_evidence_url is None
            or self.market != "india"
            or self.name is None
            or self.brand is None
            or self.quantity is None
        ):
            raise ValueError("Exact researched SKU requires barcode and declared identity evidence")
        return self


class ResearchSection(ResearchModel):
    text: Annotated[str, Field(min_length=1, max_length=16000)]
    completeness: Literal["complete", "partial", "unknown"]
    source_url: Annotated[str, Field(min_length=1, max_length=2048)]
    provenance: ResearchSource

    _url = field_validator("source_url")(public_url)


class ResearchSections(ResearchModel):
    ingredients: ResearchSection | None
    contains: ResearchSection | None
    may_contain: ResearchSection | None


class ResearchNutrient(ResearchModel):
    nutrient: Annotated[str, Field(min_length=1, max_length=128)]
    value: Annotated[int | float, Field(ge=0, le=1000000, allow_inf_nan=False)] | None
    unit: Annotated[str, Field(min_length=1, max_length=32)] | None
    qualifier: Literal[
        "exact",
        "less_than",
        "less_than_or_equal",
        "greater_than",
        "greater_than_or_equal",
        "approximate",
        "unknown",
    ]
    raw_label: PUBLIC_TEXT | None

    @model_validator(mode="after")
    def unknown_stays_unknown(self) -> Self:
        if self.value is None and self.qualifier != "unknown":
            raise ValueError("Unknown researched nutrient cannot have an exact qualifier")
        return self


class ResearchTable(ResearchModel):
    source: Literal["packaging", "manufacturer", "retailer_transcription"]
    basis: dict[str, JsonValue]
    preparation: Literal["as_sold", "as_prepared", "unknown"]
    rows: list[ResearchNutrient] = Field(min_length=1, max_length=200)
    source_url: Annotated[str, Field(min_length=1, max_length=2048)]
    retrieved_at: Annotated[str, Field(min_length=1, max_length=64)]
    source_updated_at: Annotated[str, Field(min_length=1, max_length=64)] | None
    provenance: ResearchSource

    _url = field_validator("source_url")(public_url)
    _dates = field_validator("retrieved_at", "source_updated_at")(aware_date)

    @field_validator("basis")
    @classmethod
    def valid_basis(cls, value: dict[str, JsonValue]) -> dict[str, JsonValue]:
        if set(value) - {"amount", "unit", "kind", "description"}:
            raise ValueError("Research basis fields are invalid")
        amount, unit = value.get("amount"), value.get("unit")
        if amount is not None and (
            not isinstance(amount, (int, float))
            or isinstance(amount, bool)
            or not 0 < amount <= 1000000
            or unit is None
        ):
            raise ValueError("Research basis cannot invent a missing quantity or unit")
        bounded_json(value)
        return value


class ResearchNutrition(ResearchModel):
    availability: Literal["direct_reported", "legacy_aggregate_only", "missing"]
    direct_tables: list[ResearchTable] = Field(max_length=16)
    legacy_present: bool
    legacy_aggregates: JsonValue

    @model_validator(mode="after")
    def honest_availability(self) -> Self:
        expected = (
            "direct_reported"
            if self.direct_tables
            else ("legacy_aggregate_only" if self.legacy_present else "missing")
        )
        if self.availability != expected or (
            self.legacy_aggregates is not None and not self.legacy_present
        ):
            raise ValueError("Legacy aggregates cannot become direct researched tables")
        bounded_json(self.legacy_aggregates)
        return self


class ResearchObservation(ResearchModel):
    schema_version: Literal["popular-india-research-v1"]
    observation_id: Sha256
    source: ResearchSource
    identity: ResearchIdentity
    eligibility: Eligibility
    sections: ResearchSections
    nutrition: ResearchNutrition
    metadata: dict[str, JsonValue]
    raw_projection: dict[str, JsonValue] | None = None

    @model_validator(mode="before")
    @classmethod
    def immutable_hash(cls, value: object) -> object:
        if not isinstance(value, dict):
            raise ValueError("Research observation must be a public JSON object")
        content = {key: item for key, item in value.items() if key != "observation_id"}
        data = canonical(content)
        if len(data) > MAX_RECORD_BYTES or hashlib.sha256(data).hexdigest() != value.get(
            "observation_id"
        ):
            raise ValueError("Research observation differs from its immutable content hash")
        bounded_json(content)
        return value

    @model_validator(mode="after")
    def provenance_matches(self) -> Self:
        if self.eligibility != self.identity.match:
            raise ValueError("Research identity eligibility disagrees with its source observation")
        sections = (self.sections.ingredients, self.sections.contains, self.sections.may_contain)
        for section in sections:
            if section is not None and (
                section.source_url != section.provenance.url
                or section.provenance.provider != self.source.provider
                or section.provenance.license != self.source.license
            ):
                raise ValueError("Research section provenance cannot impersonate another source")
        for table in self.nutrition.direct_tables:
            allowed = (
                {"packaging", "manufacturer"}
                if self.source.provider == "open_food_facts"
                else (
                    {"manufacturer"}
                    if self.source.provider == "manufacturer"
                    else {"retailer_transcription"}
                )
            )
            if (
                table.source not in allowed
                or table.source_url != table.provenance.url
                or table.provenance.provider != self.source.provider
                or table.provenance.license != self.source.license
                or table.retrieved_at != table.provenance.retrieved_at
                or table.source_updated_at != table.provenance.source_updated_at
            ):
                raise ValueError("Research nutrition provenance cannot impersonate another source")
        if self.raw_projection is not None and (
            self.source.provider != "open_food_facts"
            or self.raw_projection.get("code") != self.identity.barcode
        ):
            raise ValueError("Original OFF research projection must retain its exact barcode")
        return self


class ResearchCandidate(ResearchModel):
    entry_id: Sha256
    identity: ResearchIdentity
    provider: Provider
    source: ResearchSource
    eligibility: Literal["exact_sku", "brand_family_only", "identity_unconfirmed", "conflicting"]
    conflict_fields: list[PUBLIC_TEXT] = Field(default_factory=list, max_length=16)
    ingredients_available: bool
    nutrition_available: bool


class ResearchSearchResult(ResearchModel):
    schema_version: Literal["1"] = "1"
    search_version: Literal["research-search-v1"] = "research-search-v1"
    status: Literal["ready", "not_found", "unavailable", "refine_query"]
    dataset_sha256: Sha256 | None
    query: Annotated[str, Field(min_length=1, max_length=128)]
    normalized_query: Annotated[str, Field(min_length=1, max_length=519)]
    candidates: list[ResearchCandidate] = Field(default_factory=list, max_length=20)
    matched_count: int | None = Field(default=None, ge=0, le=1000)
    next_cursor: Annotated[str, Field(min_length=1, max_length=256)] | None = None
    warnings: list[PUBLIC_TEXT] = Field(default_factory=list, max_length=100)


class ResearchLookup(ResearchModel):
    schema_version: Literal["1"] = "1"
    status: Literal["found", "not_found", "unavailable"]
    entry_id: Sha256
    dataset_sha256: Sha256 | None
    observation: ResearchObservation | None = None
    conflict_fields: list[PUBLIC_TEXT] = Field(default_factory=list, max_length=16)
    warnings: list[PUBLIC_TEXT] = Field(default_factory=list, max_length=100)


class ResearchBarcodeLookup(ResearchModel):
    schema_version: Literal["1"] = "1"
    status: Literal["found", "not_found", "unavailable"]
    barcode: Annotated[str, Field(pattern=BARCODE_PATTERN)]
    dataset_sha256: Sha256 | None
    candidates: list[ResearchCandidate] = Field(default_factory=list, max_length=20)
    warnings: list[PUBLIC_TEXT] = Field(default_factory=list, max_length=100)
