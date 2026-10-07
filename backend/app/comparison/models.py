"""Independent comparison v1; released LabelReport and private sync stay unchanged."""

from typing import Annotated, Literal, Self

from pydantic import AwareDatetime, Field, model_validator

from app.catalogue.models import Manifest
from app.community.models import (
    Barcode,
    CommunityModel,
    ContributionRequest,
    ObservedOn,
    PublicText,
    Sha256,
    SubmissionId,
)
from app.schemas.nutrition import (
    NUTRIENT_NAMES,
    CanonicalValue,
    NutrientName,
    NutritionBasis,
    NutritionSnapshot,
    NutritionTable,
    Preparation,
    RowId,
)


class CurrentInput(CommunityModel):
    kind: Literal["current_confirmed_label"]
    observation: ContributionRequest
    selected_table_id: RowId

    @model_validator(mode="after")
    def confirmed_current(self) -> Self:
        if self.observation.observation_state != "confirmed" or not self.observation.confirmed:
            raise ValueError("Comparison requires confirmed corrected package facts")
        return self


class OffInput(CommunityModel):
    kind: Literal["off_snapshot"]
    barcode: Barcode
    snapshot_id: Annotated[str, Field(min_length=1, max_length=128, pattern=r"^[A-Za-z0-9._:-]+$")]
    source_sha256: Sha256
    selected_table_id: RowId


class CommunityInput(CommunityModel):
    kind: Literal["community_revision"]
    barcode: Barcode
    revision_id: Sha256
    factual_sha256: Sha256
    selected_table_id: RowId


ComparisonInput = Annotated[CurrentInput | OffInput | CommunityInput, Field(discriminator="kind")]


class ComparisonRequest(CommunityModel):
    schema_version: Literal["1"] = "1"
    client_request_id: SubmissionId
    comparison_session_id: SubmissionId
    input_revision: Annotated[int, Field(strict=True, ge=0, le=2_147_483_647)]
    a: ComparisonInput
    b: ComparisonInput


class ComparisonIdentity(CommunityModel):
    barcode: Barcode | None = None
    name: Annotated[str, Field(max_length=2000)] | None = None
    brand: Annotated[str, Field(max_length=2000)] | None = None
    quantity: Annotated[str, Field(max_length=2000)] | None = None
    variant: Annotated[str, Field(max_length=128)] | None = None


class CurrentSource(CommunityModel):
    kind: Literal["current_confirmed_label"] = "current_confirmed_label"
    source_id: Literal["confirmed-label"] = "confirmed-label"
    submission_id: SubmissionId
    observed_on: ObservedOn
    capture_method: Literal["manual", "ocr_corrected"]
    qualification: Literal["user_confirmed_not_independently_verified"] = (
        "user_confirmed_not_independently_verified"
    )


class OffSource(CommunityModel):
    kind: Literal["off_snapshot"] = "off_snapshot"
    source_id: PublicText
    manifest: Manifest
    record_modified_at: AwareDatetime | None = None
    provider_source: Literal["packaging", "manufacturer"]
    qualification: Literal["historical_community_data_not_current_package_proof"] = (
        "historical_community_data_not_current_package_proof"
    )


class CommunitySource(CommunityModel):
    kind: Literal["community_revision"] = "community_revision"
    source_id: PublicText
    revision_id: Sha256
    factual_sha256: Sha256
    observed_on: ObservedOn
    submitted_at: AwareDatetime
    reviewed_at: AwareDatetime | None
    review_state: Literal[
        "moderator_accepted_community_assertion", "submitter_confirmed_not_moderator_reviewed"
    ]
    license: Literal["CC0-1.0"] = "CC0-1.0"
    qualification: Literal["historical_assertion_not_current_package_proof"] = (
        "historical_assertion_not_current_package_proof"
    )


SourceReference = Annotated[
    CurrentSource | OffSource | CommunitySource, Field(discriminator="kind")
]


class ComparisonSide(CommunityModel):
    status: Literal["ready", "needs_correction", "not_found", "source_changed", "unavailable"]
    assessment_basis: Literal["user_confirmed_label", "catalogue_historical"]
    requested_kind: Literal["current_confirmed_label", "off_snapshot", "community_revision"]
    requested_reference: OffInput | CommunityInput | None = None
    selected_table_id: RowId
    identity: ComparisonIdentity | None = None
    source: SourceReference | None = None
    snapshot: NutritionSnapshot | None = None
    selected_table: NutritionTable | None = None
    warnings: list[PublicText] = Field(default_factory=list, max_length=100)

    @model_validator(mode="after")
    def usable_provenance(self) -> Self:
        if self.status == "ready" and (
            self.source is None or self.snapshot is None or self.selected_table is None
        ):
            raise ValueError("Usable sides retain source, original rows and selected table")
        if (
            self.selected_table is not None
            and self.selected_table.source_table_id != self.selected_table_id
        ):
            raise ValueError("Selected table identity must agree")
        return self


class ComparisonCell(CommunityModel):
    value: CanonicalValue | None = None
    unit: Literal["g", "kcal"]
    reason: PublicText | None = None
    source_row_ids: list[RowId] = Field(default_factory=list, max_length=64)


class NutrientComparison(CommunityModel):
    nutrient: NutrientName
    a: ComparisonCell
    b: ComparisonCell
    difference: (
        Annotated[float, Field(strict=True, ge=-1e9, le=1e9, allow_inf_nan=False)] | None
    ) = None
    lower: Literal["a", "b", "equal"] | None = None
    reason: PublicText | None = None

    @model_validator(mode="after")
    def difference_evidence(self) -> Self:
        if (self.difference is None) != (self.lower is None):
            raise ValueError("Only known differences have a direction")
        if self.difference is not None:
            if self.a.value is None or self.b.value is None or self.reason is not None:
                raise ValueError("Differences require both known source values")
            expected = "a" if self.difference > 0 else "b" if self.difference < 0 else "equal"
            if self.lower != expected:
                raise ValueError("Direction must match b minus a")
        return self


class ComparisonResponse(CommunityModel):
    schema_version: Literal["1"] = "1"
    comparison_version: Literal["sourced-nutrient-comparison-v1"] = "sourced-nutrient-comparison-v1"
    backend_version: PublicText
    generated_at: AwareDatetime
    client_request_id: SubmissionId
    comparison_session_id: SubmissionId
    input_revision: Annotated[int, Field(strict=True, ge=0, le=2_147_483_647)]
    status: Literal["ready", "partial", "not_comparable"]
    comparison_basis: NutritionBasis | None = None
    preparation: Preparation | None = None
    a: ComparisonSide
    b: ComparisonSide
    nutrients: list[NutrientComparison] = Field(min_length=11, max_length=11)
    normalization_version: Literal["1"] = "1"
    energy_conversion: Literal["nutrition-comparison-4.184-v1"] = "nutrition-comparison-4.184-v1"
    difference_definition: Literal["b_minus_a"] = "b_minus_a"
    storage: Literal["read_only"] = "read_only"
    warnings: list[PublicText] = Field(default_factory=list, max_length=100)

    @model_validator(mode="after")
    def stable_nutrients(self) -> Self:
        if tuple(row.nutrient for row in self.nutrients) != NUTRIENT_NAMES:
            raise ValueError("Comparison must retain all eleven distinct nutrient names")
        if self.status == "not_comparable" and any(
            row.difference is not None for row in self.nutrients
        ):
            raise ValueError("Incompatible tables cannot have differences")
        return self
