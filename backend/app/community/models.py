"""Bounded community assertions and conservative multi-source response contracts."""

import re
import unicodedata
from datetime import UTC, date, datetime, timedelta
from typing import Annotated, Literal, Self
from uuid import UUID

from pydantic import (
    AwareDatetime,
    BaseModel,
    BeforeValidator,
    ConfigDict,
    Field,
    model_validator,
)

from app.catalogue.facts import FactsLookup
from app.catalogue.models import validate_barcode
from app.schemas.nutrition import (
    CanonicalValue,
    Completeness,
    NutrientRow,
    NutritionBasis,
    NutritionSnapshot,
    Preparation,
)


def visible_text(value: object) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError("Public text must be a nonempty string")
    if any(unicodedata.category(character) in {"Cc", "Cs"} for character in value):
        raise ValueError("Public text cannot contain control or surrogate characters")
    return value


def strict_uuid(value: object) -> UUID:
    if isinstance(value, UUID):
        return value
    if (
        not isinstance(value, str)
        or re.fullmatch(
            r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}",
            value,
        )
        is None
    ):
        raise ValueError("Submission identifier must be a UUID string")
    return UUID(value)


def observation_date(value: object) -> date:
    if isinstance(value, str) and re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", value):
        value = date.fromisoformat(value)
    if type(value) is not date:
        raise ValueError("Observation date must be an ISO calendar date")
    if value > datetime.now(UTC).date() + timedelta(days=1):
        raise ValueError("Observation date cannot be in the future")
    return value


PublicText = Annotated[str, BeforeValidator(visible_text), Field(min_length=1, max_length=256)]
ShortText = Annotated[str, BeforeValidator(visible_text), Field(min_length=1, max_length=128)]
LabelText = Annotated[str, BeforeValidator(visible_text), Field(min_length=1, max_length=16000)]
Sha256 = Annotated[str, Field(min_length=64, max_length=64, pattern=r"^[0-9a-f]{64}$")]
SubmissionId = Annotated[UUID, BeforeValidator(strict_uuid)]
Barcode = Annotated[str, BeforeValidator(validate_barcode), Field(min_length=8, max_length=14)]
ObservedOn = Annotated[date, BeforeValidator(observation_date)]
ContributionStatus = Literal[
    "provisional", "candidate", "pending", "approved", "rejected", "superseded"
]
ComparisonState = Literal["unknown", "single_source", "agreement", "conflict", "not_comparable"]
EvidenceState = Literal[
    "open_food_facts_community_data",
    "submitter_confirmed_not_moderator_reviewed",
    "moderator_accepted_community_assertion",
]
ReferenceField = Literal[
    "identity.name",
    "identity.brand",
    "identity.variant",
    "identity.quantity",
    "ingredients",
    "contains",
    "may_contain",
    "nutrition",
]


class CommunityModel(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True, frozen=True, validate_default=True)


class ProductIdentity(CommunityModel):
    name: PublicText
    brand: ShortText | None = None
    variant: ShortText | None = None
    quantity: ShortText | None = None
    language: str = Field(min_length=2, max_length=3, pattern=r"^[a-z]{2,3}$")


class LabelSection(CommunityModel):
    status: Literal["present", "not_observed", "not_captured"]
    text: LabelText | None
    completeness: Completeness
    origin: Literal["independently_transcribed_package"]

    @model_validator(mode="after")
    def consistent_observation(self) -> Self:
        if (self.status == "present") != (self.text is not None):
            raise ValueError("Only a present label section can contain text")
        if self.status == "not_captured" and self.completeness != "partial":
            raise ValueError("An uncaptured section cannot be complete")
        return self


class ProviderReference(CommunityModel):
    """Pointers to existing licensed data, never a copied CC0 assertion."""

    provider: Literal["off_snapshot"]
    source_id: PublicText
    barcode: Barcode
    fields: list[ReferenceField] = Field(min_length=1, max_length=8)

    @model_validator(mode="after")
    def unique_fields(self) -> Self:
        if len(self.fields) != len(set(self.fields)):
            raise ValueError("Provider reference fields must be unique")
        return self


class ContributionFacts(CommunityModel):
    """Public factual assertion; permission/ownership/request IDs are not exposed."""

    schema_version: Literal["1"] = "1"
    barcode: Barcode | None = None
    identity: ProductIdentity
    ingredients: LabelSection
    contains: LabelSection
    may_contain: LabelSection
    front_claims: list[PublicText] = Field(default_factory=list, max_length=16)
    rows: list[NutrientRow] = Field(default_factory=list, max_length=64)
    nutrition_completeness: Completeness
    nutrition_origin: Literal["independently_transcribed_package"]
    provider_references: list[ProviderReference] = Field(default_factory=list, max_length=8)
    revision_context: PublicText | None = None
    observed_on: ObservedOn
    capture_method: Literal["manual", "ocr_corrected", "ocr_unconfirmed"]
    share_license: Literal["CC0-1.0"]
    market: Literal["india"]

    @model_validator(mode="after")
    def captured_back_facts(self) -> Self:
        identifiers = [row.row_id for row in self.rows]
        if len(identifiers) != len(set(identifiers)):
            raise ValueError("Nutrient row identifiers must be unique")
        if any(reference.barcode != self.barcode for reference in self.provider_references):
            raise ValueError("Provider references must use the exact linked barcode")
        return self


class ContributionRequest(ContributionFacts):
    submission_id: SubmissionId
    observation_state: Literal["provisional", "confirmed"] = "confirmed"
    confirmed: bool = False
    front_confirmed: bool = False
    back_confirmed: bool = False
    same_product_confirmed: bool = False

    @model_validator(mode="after")
    def confirmed_evidence(self) -> Self:
        if self.observation_state == "confirmed":
            if not self.confirmed or self.capture_method == "ocr_unconfirmed":
                raise ValueError("Confirmed observations require corrected field confirmation")
            if not self.rows and all(
                section.status == "not_captured"
                for section in (self.ingredients, self.contains, self.may_contain)
            ):
                raise ValueError("At least one back-package field must be captured")
        return self


class PreparedContribution(CommunityModel):
    request: ContributionRequest
    content_sha256: Sha256
    factual_sha256: Sha256
    snapshot: NutritionSnapshot
    auto_eligible: bool


class ContributionReceipt(CommunityModel):
    schema_version: Literal["1"] = "1"
    submission_id: SubmissionId
    revision_id: Sha256
    barcode: Barcode | None
    content_sha256: Sha256
    factual_sha256: Sha256
    status: ContributionStatus
    submitted_at: AwareDatetime
    reviewed_at: AwareDatetime | None = None
    expires_at: AwareDatetime | None = None
    deduplicated: bool = False
    warnings: list[PublicText] = Field(default_factory=list, max_length=100)

    @model_validator(mode="after")
    def review_date(self) -> Self:
        decided = self.status in {"approved", "rejected", "superseded"}
        if not decided and self.reviewed_at is not None:
            raise ValueError("Unreviewed assertions cannot have a review date")
        if decided and self.reviewed_at is None:
            raise ValueError("Decided assertions require a review date")
        if (
            self.reviewed_at is not None
            and self.reviewed_at < self.submitted_at
            and not self.deduplicated
        ):
            raise ValueError("Review cannot precede submission")
        if self.expires_at is not None and (
            self.status != "provisional" or self.expires_at <= self.submitted_at
        ):
            raise ValueError("Only provisional assertions have a later staging expiry")
        return self


class CommunityRevision(CommunityModel):
    revision_id: Sha256
    content_sha256: Sha256
    factual_sha256: Sha256
    barcode: Barcode
    submitted_at: AwareDatetime
    reviewed_at: AwareDatetime | None
    facts: ContributionFacts
    snapshot: NutritionSnapshot
    origin: Literal["unlabel_community"] = "unlabel_community"
    license: Literal["CC0-1.0"] = "CC0-1.0"
    review_state: Literal[
        "moderator_accepted_community_assertion", "submitter_confirmed_not_moderator_reviewed"
    ] = "moderator_accepted_community_assertion"

    @model_validator(mode="after")
    def matching_assertion(self) -> Self:
        if self.barcode != self.facts.barcode:
            raise ValueError("Accepted revision barcode must match its public facts")
        if (self.review_state == "moderator_accepted_community_assertion") != (
            self.reviewed_at is not None
        ):
            raise ValueError("Public review state must match the actual review date")
        if self.reviewed_at is not None and self.reviewed_at < self.submitted_at:
            raise ValueError("Review cannot precede submission")
        if self.snapshot.status == "needs_correction":
            raise ValueError("Accepted nutrition cannot need correction")
        if self.snapshot.original_rows != self.facts.rows:
            raise ValueError("Accepted nutrition must retain the asserted rows")
        return self


class CommunityLookup(CommunityModel):
    schema_version: Literal["1"] = "1"
    requested_barcode: Barcode
    status: Literal["found", "not_found", "unavailable"]
    revisions: list[CommunityRevision] = Field(default_factory=list, max_length=8)
    warnings: list[PublicText] = Field(default_factory=list, max_length=100)

    @model_validator(mode="after")
    def matching_revisions(self) -> Self:
        if (self.status == "found") != bool(self.revisions):
            raise ValueError("Only a found lookup may contain accepted revisions")
        identifiers = [revision.revision_id for revision in self.revisions]
        if len(identifiers) != len(set(identifiers)) or any(
            revision.barcode != self.requested_barcode for revision in self.revisions
        ):
            raise ValueError("Lookup revisions require unique exact product identities")
        return self


class ReviewItem(CommunityModel):
    revision_id: Sha256
    content_sha256: Sha256
    factual_sha256: Sha256
    status: ContributionStatus
    submitted_at: AwareDatetime
    reviewed_at: AwareDatetime | None = None
    expires_at: AwareDatetime | None = None
    request: ContributionRequest
    snapshot: NutritionSnapshot
    warnings: list[PublicText] = Field(default_factory=list, max_length=100)


class FieldComparison(CommunityModel):
    field: PublicText
    state: ComparisonState
    source_ids: list[PublicText] = Field(default_factory=list, max_length=9)


class FieldAlternative(CommunityModel):
    source_id: PublicText
    value: Annotated[str, Field(max_length=16000)] | CanonicalValue
    evidence_state: EvidenceState
    observed_on: ObservedOn | None = None
    source_updated_at: AwareDatetime | None = None
    completeness: Completeness | None = None
    source_table_id: Annotated[str, Field(max_length=64)] | None = None
    source_row_ids: list[Annotated[str, Field(max_length=64)]] = Field(
        default_factory=list, max_length=64
    )
    basis: NutritionBasis | None = None
    preparation: Preparation | None = None
    unit: Literal["g", "kcal"] | None = None


class ResolvedField(CommunityModel):
    field: PublicText
    state: ComparisonState
    value: Annotated[str, Field(max_length=16000)] | CanonicalValue | None = None
    unit: Literal["g", "kcal"] | None = None
    basis: NutritionBasis | None = None
    preparation: Preparation | None = None
    source_ids: list[PublicText] = Field(default_factory=list, max_length=9)
    evidence_state: EvidenceState | None = None
    observed_on: ObservedOn | None = None
    source_updated_at: AwareDatetime | None = None
    completeness: Completeness | None = None
    selection_reason: PublicText
    alternatives: list[FieldAlternative] = Field(default_factory=list, max_length=144)

    @model_validator(mode="after")
    def honest_selection(self) -> Self:
        if self.value is not None and (
            self.state not in {"single_source", "agreement"}
            or not self.source_ids
            or self.evidence_state is None
        ):
            raise ValueError("Selected values require compatible identified evidence")
        return self


class CommunityFailure(CommunityModel):
    schema_version: Literal["1"] = "1"
    status: Literal["unavailable", "unauthorized", "conflict", "rate_limited", "not_found"]
    code: Annotated[str, Field(min_length=1, max_length=64, pattern=r"^[a-z][a-z0-9_]*$")]
    warnings: list[PublicText] = Field(default_factory=list, max_length=100)


class ResolvedProduct(CommunityModel):
    schema_version: Literal["1"] = "1"
    requested_barcode: Barcode
    off_snapshot: FactsLookup | None
    community: CommunityLookup
    knowledge_version: PublicText | None = None
    comparisons: list[FieldComparison] = Field(default_factory=list, max_length=128)
    fields: list[ResolvedField] = Field(default_factory=list, max_length=128)
    warnings: list[PublicText] = Field(default_factory=list, max_length=100)

    @model_validator(mode="after")
    def exact_sources(self) -> Self:
        if self.community.requested_barcode != self.requested_barcode or (
            self.off_snapshot is not None
            and self.off_snapshot.requested_barcode != self.requested_barcode
        ):
            raise ValueError("Resolved sources must share the exact requested barcode")
        return self
