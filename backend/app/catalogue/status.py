"""Snapshot age and status describe maintenance policy, never food suitability."""

from calendar import monthrange
from datetime import UTC, datetime
from typing import Literal, Self

from pydantic import AwareDatetime, Field, model_validator

from app.catalogue.models import CatalogueModel, Manifest

REFRESH_INTERVAL_MONTHS = 9


class SnapshotFreshness(CatalogueModel):
    status: Literal["within_refresh_window", "refresh_due", "source_date_in_future"]
    evaluated_at: AwareDatetime
    age_seconds: int | None = Field(ge=0)
    refresh_due_at: AwareDatetime
    refresh_interval_months: Literal[9] = REFRESH_INTERVAL_MONTHS


def snapshot_freshness(exported_at: datetime, *, now: datetime | None = None) -> SnapshotFreshness:
    now = now if now is not None else datetime.now(UTC)
    if exported_at.utcoffset() is None or now.utcoffset() is None:
        raise ValueError("Snapshot dates must include a timezone")
    try:
        source = exported_at.astimezone(UTC)
        now = now.astimezone(UTC)
        months = source.year * 12 + source.month - 1 + REFRESH_INTERVAL_MONTHS
        year, month = divmod(months, 12)
        month += 1
        due = source.replace(
            year=year, month=month, day=min(source.day, monthrange(year, month)[1])
        )
    except (OverflowError, ValueError):
        raise ValueError("Snapshot date exceeds the supported UTC/refresh date range") from None
    future = source > now
    return SnapshotFreshness(
        status="source_date_in_future"
        if future
        else ("refresh_due" if now >= due else "within_refresh_window"),
        evaluated_at=now,
        age_seconds=None if future else int((now - source).total_seconds()),
        refresh_due_at=due,
    )


class CatalogueArtifact(CatalogueModel):
    database_sha256: str = Field(pattern=r"^[0-9a-f]{64}$")
    database_bytes: int = Field(gt=0, le=100 * 1024**2)
    source_sha256: str = Field(pattern=r"^[0-9a-f]{64}$")
    snapshot_id: str = Field(min_length=1, max_length=128)


class CatalogueStatus(CatalogueModel):
    schema_version: Literal["1"] = "1"
    status: Literal["ready", "not_configured", "unavailable"]
    manifest: Manifest | None = None
    freshness: SnapshotFreshness | None = None
    artifact: CatalogueArtifact | None = None
    data_kind: Literal["product_identity"] = "product_identity"
    field_limits: list[str] = Field(
        default_factory=lambda: [
            "nutrition_tables_not_included",
            "images_not_included",
            "per_product_modified_at_not_included",
            "missing_allergen_tags_do_not_mean_allergen_free",
        ]
    )

    @model_validator(mode="after")
    def coherent_status(self) -> Self:
        if self.status == "ready":
            if self.manifest is None or self.freshness is None:
                raise ValueError("Ready catalogue status requires its manifest and source age")
            if self.artifact is not None and (
                self.artifact.snapshot_id != self.manifest.snapshot_id
                or self.artifact.source_sha256 != self.manifest.source_sha256
            ):
                raise ValueError("Catalogue artifact and manifest must describe the same snapshot")
        elif any(value is not None for value in (self.manifest, self.freshness, self.artifact)):
            raise ValueError("Unavailable status cannot claim a verified snapshot")
        return self
