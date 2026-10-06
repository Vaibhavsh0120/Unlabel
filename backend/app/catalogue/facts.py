"""Bounded rich facts from an acquired OFF export, separate from live API facts.

The image URL is constructed from selected-image metadata, never copied from an
arbitrary URL. Legacy aggregated nutriments are deliberately not interpreted as
direct label tables. Empty community tags never establish allergy safety.
"""

import re
from datetime import UTC, datetime
from typing import Literal, Self

from pydantic import AwareDatetime, Field, field_validator, model_validator

from app.catalogue.models import CatalogLookup, CatalogueModel, Manifest, validate_barcode
from app.schemas.nutrition import NUTRIENT_NAMES, NutritionSnapshot
from app.schemas.nutrition_products import InputTableSource
from app.schemas.products import Product
from app.services.parsing.off_nutrition import parse_direct_nutrition

LANGUAGE_PATTERN = r"^[a-z]{2,3}$"
MAX_SCHEMA_VERSION = 2_147_483_647


def _valid_text(value: object, limit: int) -> bool:
    return (
        isinstance(value, str)
        and len(value) <= limit
        and not any("\ud800" <= character <= "\udfff" for character in value)
    )


class AvailableTags(CatalogueModel):
    availability: Literal["available", "missing", "invalid"]
    values: list[str] = Field(default_factory=list, max_length=100)

    @field_validator("values")
    @classmethod
    def bounded_tags(cls, value: list[str]) -> list[str]:
        if any(not _valid_text(tag, 256) for tag in value):
            raise ValueError("Product facts tags exceed their valid bounds")
        return value

    @model_validator(mode="after")
    def check_availability(self) -> Self:
        if self.availability != "available" and self.values:
            raise ValueError("Unavailable tags cannot contain values")
        return self


def selected_front_url(barcode: str, language: str, revision: int) -> str:
    validate_barcode(barcode)
    if (
        not isinstance(language, str)
        or re.fullmatch(LANGUAGE_PATTERN, language) is None
        or not (type(revision) is int and 1 <= revision <= MAX_SCHEMA_VERSION)
    ):
        raise ValueError("Selected image metadata is invalid")
    # OFF split_code() normalizes its disk path separately from the catalogue key:
    # strip leading zeroes, pad to 13 digits, then split. The exact lookup barcode
    # remains untouched, including EAN8 and leading-zero variants.
    significant = barcode.lstrip("0")
    if len(significant) < 4:
        raise ValueError("Product has no supported official image path")
    image_code = significant.zfill(13)
    folder = "/".join([image_code[:3], image_code[3:6], image_code[6:9], image_code[9:]])
    return (
        f"https://images.openfoodfacts.org/images/products/{folder}/"
        f"front_{language}.{revision}.400.jpg"
    )


def _image_revision(value: object) -> int | None:
    # Raw JSONL selected-image revisions can be decimal strings even though the
    # public facts contract uses a strict integer. Do not coerce URLs or floats.
    if isinstance(value, str) and re.fullmatch(r"[1-9][0-9]{0,9}", value) is not None:
        value = int(value)
    return value if type(value) is int and 1 <= value <= MAX_SCHEMA_VERSION else None


class FrontImage(CatalogueModel):
    url: str = Field(min_length=1, max_length=512)
    language: str = Field(pattern=LANGUAGE_PATTERN, max_length=3)
    revision: int = Field(ge=1, le=MAX_SCHEMA_VERSION)
    size: Literal[400] = 400
    width: int | None = Field(default=None, ge=1, le=400)
    height: int | None = Field(default=None, ge=1, le=400)
    provider: Literal["open_food_facts"] = "open_food_facts"
    attribution: Literal["Product image from Open Food Facts contributors"] = (
        "Product image from Open Food Facts contributors"
    )
    license: Literal["CC-BY-SA-3.0"] = "CC-BY-SA-3.0"
    license_url: Literal["https://creativecommons.org/licenses/by-sa/3.0/"] = (
        "https://creativecommons.org/licenses/by-sa/3.0/"
    )

    @field_validator("url")
    @classmethod
    def official_image_url(cls, value: str) -> str:
        if (
            re.fullmatch(
                r"https://images\.openfoodfacts\.org/images/products/"
                r"[0-9]{3}/[0-9]{3}/[0-9]{3}/[0-9]{4,5}/"
                r"front_[a-z]{2,3}\.[1-9][0-9]{0,9}\.400\.jpg",
                value,
            )
            is None
        ):
            raise ValueError("Image must use the canonical official selected-image URL")
        return value


class DirectNutrition(CatalogueModel):
    availability: Literal["direct_tables", "missing", "legacy_unsupported", "invalid"]
    nutrition_adapter_version: Literal["1"] = "1"
    assessment_basis: Literal["open_food_facts_community_data"] = "open_food_facts_community_data"
    input_tables: list[InputTableSource] = Field(default_factory=list, max_length=16)
    snapshot: NutritionSnapshot
    warnings: list[str] = Field(default_factory=list, max_length=100)

    @field_validator("snapshot", mode="before")
    @classmethod
    def strict_snapshot(cls, value):
        if isinstance(value, NutritionSnapshot):
            value = value.model_dump()
        return NutritionSnapshot.model_validate(value, strict=True)

    @field_validator("input_tables", mode="before")
    @classmethod
    def strict_sources(cls, value):
        if not isinstance(value, list):
            raise ValueError("Input table sources must be a list")
        return [
            InputTableSource.model_validate(
                item.model_dump() if isinstance(item, InputTableSource) else item, strict=True
            )
            for item in value
        ]

    @field_validator("warnings")
    @classmethod
    def bounded_warnings(cls, values: list[str]) -> list[str]:
        return CatalogLookup.bounded_warnings(values)

    @model_validator(mode="after")
    def check_direct_tables(self) -> Self:
        CatalogLookup.bounded_warnings(self.snapshot.warnings)
        if len(self.snapshot.warnings) > 100 or len(self.snapshot.tables) > 16:
            raise ValueError("Nutrition snapshot exceeds its fact bounds")
        table_ids = [item.table_id for item in self.input_tables]
        snapshot_ids = [table.source_table_id for table in self.snapshot.tables]
        if (
            len(table_ids) != len(set(table_ids))
            or len(snapshot_ids) != len(set(snapshot_ids))
            or set(table_ids) != set(snapshot_ids)
            or any(row.table_id not in table_ids for row in self.snapshot.original_rows)
            or any(set(table.nutrients) != set(NUTRIENT_NAMES) for table in self.snapshot.tables)
        ):
            raise ValueError("Direct nutrition provenance must match its tables")
        if self.availability != "direct_tables" and (table_ids or self.snapshot.original_rows):
            raise ValueError("Unavailable direct nutrition cannot contain reported facts")
        if self.availability == "direct_tables" and not table_ids:
            raise ValueError("Available direct nutrition requires at least one reported table")
        return self


class ProductFacts(CatalogueModel):
    schema_version: Literal["1"] = "1"
    provider_schema_version: int | None = Field(default=None, ge=0, le=MAX_SCHEMA_VERSION)
    last_modified_at: AwareDatetime | None = None
    categories: AvailableTags
    labels: AvailableTags
    allergens: AvailableTags
    traces: AvailableTags
    image: FrontImage | None = None
    nutrition: DirectNutrition


class FactsLookup(CatalogueModel):
    schema_version: Literal["1"] = "1"
    requested_barcode: str = Field(pattern=r"^(?:[0-9]{8}|[0-9]{12,14})$")
    status: Literal["found", "not_found", "unavailable"]
    manifest: Manifest | None = None
    product: Product | None = None
    details: ProductFacts | None = None
    warnings: list[str] = Field(default_factory=list, max_length=100)

    @field_validator("product")
    @classmethod
    def bounded_product(cls, value: Product | None) -> Product | None:
        return CatalogLookup.bounded_product(value)

    @field_validator("warnings")
    @classmethod
    def bounded_warnings(cls, values: list[str]) -> list[str]:
        return CatalogLookup.bounded_warnings(values)

    @model_validator(mode="after")
    def check_result(self) -> Self:
        if self.status == "found":
            if (
                self.manifest is None
                or self.product is None
                or self.details is None
                or self.product.barcode != self.requested_barcode
            ):
                raise ValueError("Found facts require the exact identity, details and manifest")
            if self.details.image is not None:
                image = self.details.image
                if image.url != selected_front_url(
                    self.product.barcode, image.language, image.revision
                ):
                    raise ValueError("Selected image does not match the exact product identity")
            if (
                self.details.allergens.values != self.product.allergen_tags
                or self.details.traces.values != self.product.trace_tags
            ):
                raise ValueError("Fact tag values do not match the identity product")
        elif self.product is not None or self.details is not None:
            raise ValueError("Unsuccessful fact lookups cannot contain product details")
        if self.status == "not_found" and self.manifest is None:
            raise ValueError("Not-found facts require the checked manifest")
        return self


def project_facts(raw: dict, barcode: str) -> tuple[ProductFacts, list[str]]:
    """Project optional source fields; malformed optional information stays unknown."""
    validate_barcode(barcode)
    warnings: list[str] = []

    def tags(field: str) -> AvailableTags:
        value = raw.get(field)
        if value is None:
            warnings.append(f"{field}_missing")
            return AvailableTags(availability="missing")
        if (
            not isinstance(value, list)
            or len(value) > 100
            or any(not _valid_text(tag, 256) for tag in value)
        ):
            warnings.append(f"{field}_invalid")
            return AvailableTags(availability="invalid")
        return AvailableTags(availability="available", values=value)

    modified = raw.get("last_modified_t")
    last_modified_at = None
    if type(modified) is int and modified >= 0:
        try:
            last_modified_at = datetime.fromtimestamp(modified, UTC)
        except (OverflowError, OSError, ValueError):
            warnings.append("provider_modified_at_invalid")
    elif modified is not None:
        warnings.append("provider_modified_at_invalid")
    else:
        warnings.append("provider_modified_at_missing")
    schema = raw.get("schema_version")
    provider_schema = schema if type(schema) is int and 0 <= schema <= MAX_SCHEMA_VERSION else None
    if schema is not None and provider_schema is None:
        warnings.append("provider_schema_version_invalid")

    nutrition = raw.get("nutrition")
    direct = parse_direct_nutrition(nutrition)
    input_sets = nutrition.get("input_sets") if isinstance(nutrition, dict) else None
    if direct.input_tables:
        nutrition_availability = "direct_tables"
    elif (nutrition is not None and not isinstance(nutrition, dict)) or (
        input_sets is not None and input_sets != []
    ):
        nutrition_availability = "invalid"
    elif (
        "nutriments" in raw
        or "nutrition_data" in raw
        or raw.get("nutrition_legacy_present") is True
    ):
        nutrition_availability = "legacy_unsupported"
        direct.warnings.append("legacy_aggregated_nutrition_not_used")
    else:
        nutrition_availability = "missing"
    image = _selected_front(raw, barcode, warnings)
    assert direct.snapshot is not None  # The direct-table parser always normalizes its rows.
    return ProductFacts(
        provider_schema_version=provider_schema,
        last_modified_at=last_modified_at,
        categories=tags("categories_tags"),
        labels=tags("labels_tags"),
        allergens=tags("allergens_tags"),
        traces=tags("traces_tags"),
        image=image,
        nutrition=DirectNutrition(
            availability=nutrition_availability,
            input_tables=direct.input_tables,
            snapshot=direct.snapshot,
            warnings=list(dict.fromkeys(direct.warnings)),
        ),
    ), list(dict.fromkeys(warnings))


def _selected_front(raw: dict, barcode: str, warnings: list[str]) -> FrontImage | None:
    if len(barcode.lstrip("0")) < 4:
        warnings.append("selected_front_image_invalid")
        return None
    images = raw.get("images")
    if not isinstance(images, dict):
        warnings.append("selected_front_image_missing")
        return None
    languages = ["en", "hi"]
    lc = raw.get("lc")
    if (
        isinstance(lc, str)
        and re.fullmatch(LANGUAGE_PATTERN, lc) is not None
        and lc not in languages
    ):
        languages.append(lc)
    selected = images.get("selected")
    front = selected.get("front") if isinstance(selected, dict) else None
    for language in languages:
        candidate = front.get(language) if isinstance(front, dict) else None
        if candidate is None:
            candidate = images.get(f"front_{language}")
        if candidate is None:
            continue
        if not isinstance(candidate, dict):
            warnings.append("selected_front_image_invalid")
            continue
        revision = _image_revision(candidate.get("rev"))
        sizes = candidate.get("sizes")
        size = sizes.get("400") if isinstance(sizes, dict) else None
        if revision is None or not isinstance(size, dict):
            warnings.append("selected_front_image_invalid")
            continue
        dimensions = {}
        for dimension in ("w", "h"):
            value = size.get(dimension)
            if value is not None and not (type(value) is int and 1 <= value <= 400):
                break
            dimensions["width" if dimension == "w" else "height"] = value
        else:
            return FrontImage(
                url=selected_front_url(barcode, language, revision),
                language=language,
                revision=revision,
                **dimensions,
            )
        warnings.append("selected_front_image_invalid")
    warnings.append("selected_front_image_missing")
    return None
