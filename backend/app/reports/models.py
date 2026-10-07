"""Bounded report contracts; private analysis and public storage have separate outcomes."""

from typing import Annotated, Literal, Self

from pydantic import AwareDatetime, Field, model_validator

from app.claims.models import ClaimAssessment, ClaimContext, ClaimName, ReasonId
from app.community.models import (
    CommunityModel,
    ContributionFacts,
    ContributionReceipt,
    ContributionRequest,
    EvidenceState,
    ProductIdentity,
    PublicText,
    ResolvedField,
    ResolvedProduct,
)
from app.reports.glossary import GlossaryArtifact, GlossaryMatch, GlossarySource
from app.schemas.nutrition import (
    CanonicalValue,
    Completeness,
    NutritionBasis,
    NutritionSnapshot,
    Preparation,
    RowId,
)

ReportBasis = Literal["user_confirmed_label", "catalogue_historical"]
SectionEvidence = EvidenceState | Literal["user_confirmed_label"]


class ReportCheckRequest(CommunityModel):
    schema_version: Literal["1"] = "1"
    observation: ContributionRequest
    selected_table_id: RowId | None = None
    context: ClaimContext | None = None

    @model_validator(mode="after")
    def current_confirmed_observation(self) -> Self:
        if self.observation.observation_state != "confirmed" or not self.observation.confirmed:
            raise ValueError("A current report requires a confirmed corrected observation")
        return self


class ReportFailure(CommunityModel):
    schema_version: Literal["1"] = "1"
    status: Literal["not_found", "unavailable"]
    code: ReasonId
    warnings: list[PublicText] = Field(default_factory=list, max_length=100)


class StorageOutcome(CommunityModel):
    status: Literal[
        "saved",
        "authentication_required",
        "unavailable",
        "rate_limited",
        "conflict",
        "needs_correction",
        "read_only",
    ]
    receipt: ContributionReceipt | None = None
    warnings: list[PublicText] = Field(default_factory=list, max_length=100)

    @model_validator(mode="after")
    def actual_receipt(self) -> Self:
        if (self.status == "saved") != (self.receipt is not None):
            raise ValueError("Only a completed save has a contribution receipt")
        return self


class ReportSection(CommunityModel):
    status: Literal[
        "present", "not_observed", "not_captured", "unknown", "conflict", "not_comparable"
    ]
    text: Annotated[str, Field(max_length=16000)] | None = None
    completeness: Completeness | None = None
    source_ids: list[PublicText] = Field(default_factory=list, max_length=9)
    evidence_state: SectionEvidence | None = None

    @model_validator(mode="after")
    def observed_text(self) -> Self:
        if (self.status == "present") != (self.text is not None):
            raise ValueError("Only a present section can contain selected text")
        if self.text is not None and not self.text.strip():
            raise ValueError("Blank text is unknown, not a selected ingredient section")
        return self


class SugarApproximation(CommunityModel):
    approximation_version: Literal["sugar-cubes-4g-v1"] = "sugar-cubes-4g-v1"
    sugars_g: CanonicalValue
    cubes: CanonicalValue
    grams_per_cube: Annotated[float, Field(strict=True, ge=4, le=4)] = 4.0
    basis: NutritionBasis
    preparation: Preparation
    assessment_basis: ReportBasis
    source_table_id: RowId
    source_row_ids: list[RowId] = Field(min_length=1, max_length=64)
    source_ids: list[PublicText] = Field(min_length=1, max_length=9)
    approximation: Literal[True] = True


class ReportClaim(CommunityModel):
    claim_id: RowId
    printed_text: PublicText
    claim: ClaimName | None = None
    assessment: ClaimAssessment | None = None
    source_ids: list[PublicText] = Field(default_factory=list, max_length=9)
    missing_inputs: list[ReasonId] = Field(default_factory=list, max_length=32)

    @model_validator(mode="after")
    def matching_assessment(self) -> Self:
        if self.assessment is not None and (
            self.claim is None
            or self.claim != self.assessment.claim
            or self.claim_id != self.assessment.claim_id
        ):
            raise ValueError("An assessment must refer to this identified printed claim")
        return self


class LabelReport(CommunityModel):
    schema_version: Literal["1"] = "1"
    report_version: Literal["label-report-v1"] = "label-report-v1"
    backend_version: PublicText
    generated_at: AwareDatetime
    assessment_basis: ReportBasis
    status: Literal["ready", "partial", "not_found", "unavailable"]
    identity: ProductIdentity | None = None
    observation: ContributionFacts | None = None
    resolved: ResolvedProduct | None = None
    nutrition: NutritionSnapshot | None = None
    resolved_nutrients: list[ResolvedField] = Field(default_factory=list, max_length=128)
    selected_table_id: RowId | None = None
    context: ClaimContext | None = None
    sugar: SugarApproximation | None = None
    claims: list[ReportClaim] = Field(default_factory=list, max_length=16)
    ingredients: ReportSection
    contains: ReportSection
    may_contain: ReportSection
    ingredient_insights: list[GlossaryMatch] = Field(default_factory=list, max_length=64)
    glossary_version: PublicText | None = None
    glossary_artifact: GlossaryArtifact | None = None
    glossary_sources: list[GlossarySource] = Field(default_factory=list, max_length=8)
    knowledge_version: PublicText | None = None
    missing_inputs: list[ReasonId] = Field(default_factory=list, max_length=100)
    warnings: list[PublicText] = Field(default_factory=list, max_length=100)
    storage: StorageOutcome

    @model_validator(mode="after")
    def source_boundaries(self) -> Self:
        current = self.assessment_basis == "user_confirmed_label"
        if current:
            if self.observation is None or self.nutrition is None or self.resolved is not None:
                raise ValueError("Current reports require their own observed label facts")
        elif self.resolved is None or self.observation is not None or self.nutrition is not None:
            raise ValueError(
                "Historical reports retain resolved sources without current observations"
            )
        if not current and any(claim.assessment is not None for claim in self.claims):
            raise ValueError("Historical catalogue values cannot establish current-label claims")
        if self.sugar is not None and self.sugar.assessment_basis != self.assessment_basis:
            raise ValueError("Sugar approximation must retain its report evidence basis")
        return self
