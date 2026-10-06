import re
from datetime import UTC, datetime, timedelta
from typing import Literal, Self
from urllib.parse import urlsplit

from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, field_validator, model_validator

from app.schemas.products import Product

BARCODE_PATTERN = r"(?:[0-9]{8}|[0-9]{12,14})"
SourceFormat = Literal["off_jsonl", "off_csv_projection"]
Coverage = Literal["sample", "unverified"]
SOURCE_HOSTS = frozenset({"static.openfoodfacts.org", "world.openfoodfacts.org"})


def validate_source_url(value: str) -> str:
    """Validate attribution provenance only; this module never fetches the URL."""
    if (
        not isinstance(value, str)
        or not value.isascii()
        or len(value) > 2048
        or any(c.isspace() for c in value)
    ):
        raise ValueError("Source URL must be a bounded official HTTPS URL")
    try:
        parsed = urlsplit(value)
        valid = (
            parsed.scheme == "https"
            and parsed.hostname in SOURCE_HOSTS
            and parsed.port in {None, 443}
            and "@" not in parsed.netloc
            and "#" not in value
            and not any(ord(character) < 32 for character in value)
        )
    except ValueError:
        valid = False
    if not valid:
        raise ValueError("Source URL must use an official Open Food Facts HTTPS origin")
    return value


def validate_barcode(value: str) -> str:
    if not isinstance(value, str) or re.fullmatch(BARCODE_PATTERN, value) is None:
        raise ValueError("Unsupported barcode format")
    return value


class CatalogueModel(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True, strict=True, validate_default=True)


class Manifest(CatalogueModel):
    """Source SHA-256 covers every decoded byte of the local import input, through EOF.

    ``unverified`` does not assert independent completeness of products sold in India.
    A CSV projection has separate upstream acquisition proof outside this contract.
    """

    schema_version: Literal["1"] = "1"
    snapshot_id: str = Field(min_length=1, max_length=128, pattern=r"^[A-Za-z0-9._:-]+$")
    source_url: str = Field(min_length=1, max_length=2048)
    source_sha256: str = Field(pattern=r"^[0-9a-f]{64}$")
    source_format: SourceFormat = "off_jsonl"
    coverage: Coverage = "sample"
    exported_at: AwareDatetime
    indexed_at: AwareDatetime
    market_tag: Literal["en:india"] = "en:india"
    rows_read: int = Field(ge=0)
    india_rows: int = Field(ge=0)
    indexed_products: int = Field(ge=1)
    duplicate_barcodes: int = Field(default=0, ge=0)
    unsupported_barcodes: int = Field(ge=0)
    missing_name: int = Field(ge=0)
    missing_ingredients: int = Field(ge=0)
    database_license: Literal["ODbL-1.0"] = "ODbL-1.0"
    contents_license: Literal["DbCL-1.0"] = "DbCL-1.0"
    attribution: Literal["Product data from Open Food Facts"] = "Product data from Open Food Facts"
    license_url: Literal["https://openfoodfacts.org/terms-of-use"] = (
        "https://openfoodfacts.org/terms-of-use"
    )

    _official_source = field_validator("source_url")(validate_source_url)

    @field_validator("indexed_at")
    @classmethod
    def require_utc(cls, value: datetime) -> datetime:
        if value.utcoffset() != timedelta(0):
            raise ValueError("indexed_at must be UTC")
        return value.astimezone(UTC)

    @model_validator(mode="after")
    def check_counts(self) -> Self:
        if (
            self.rows_read < self.india_rows
            or self.india_rows != self.indexed_products + self.unsupported_barcodes
            or self.duplicate_barcodes != 0
            or self.missing_name > self.indexed_products
            or self.missing_ingredients > self.indexed_products
        ):
            raise ValueError("Catalogue manifest counts are inconsistent")
        return self


class CatalogLookup(CatalogueModel):
    schema_version: Literal["1"] = "1"
    requested_barcode: str = Field(pattern=r"^(?:[0-9]{8}|[0-9]{12,14})$")
    status: Literal["found", "not_found", "unavailable"]
    manifest: Manifest | None = None
    product: Product | None = None
    warnings: list[str] = Field(default_factory=list, max_length=100)

    @field_validator("product")
    @classmethod
    def bounded_product(cls, value: Product | None) -> Product | None:
        if value is None:
            return None

        def valid_text(text: str, limit: int) -> bool:
            return len(text) <= limit and not any("\ud800" <= c <= "\udfff" for c in text)

        for field, limit in (
            ("name", 2000),
            ("brands", 2000),
            ("quantity_text", 2000),
            ("ingredients_text", 16000),
        ):
            text = getattr(value, field)
            if text is not None and not valid_text(text, limit):
                raise ValueError("Catalogue product text exceeds its valid bounds")
        for tags in (value.allergen_tags, value.trace_tags):
            if len(tags) > 100 or any(not valid_text(tag, 256) for tag in tags):
                raise ValueError("Catalogue product tags exceed their valid bounds")
        return value

    @field_validator("warnings")
    @classmethod
    def bounded_warnings(cls, values: list[str]) -> list[str]:
        if any(
            len(value) > 256 or any("\ud800" <= c <= "\udfff" for c in value) for value in values
        ):
            raise ValueError("Catalogue warnings must be bounded")
        return values

    @model_validator(mode="after")
    def check_result(self) -> Self:
        if self.status == "found":
            if (
                self.manifest is None
                or self.product is None
                or self.product.barcode != self.requested_barcode
            ):
                raise ValueError("Found catalogue records require an exact product and manifest")
        elif self.product is not None:
            raise ValueError("Unsuccessful catalogue lookups cannot contain a product")
        if self.status == "not_found" and self.manifest is None:
            raise ValueError("Not-found catalogue lookups require the checked manifest")
        return self
