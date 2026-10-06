from datetime import date
from typing import Annotated, Literal, Self
from uuid import UUID

from pydantic import AwareDatetime, Field, model_validator

from app.schemas.nutrition import CanonicalValue, NormalizeRequest, NutritionSnapshot, RowId
from app.schemas.products import ContractModel

ClaimName = Literal[
    "source_of_fibre",
    "high_fibre",
    "low_sugar",
    "sugar_free",
    "low_sodium",
    "very_low_sodium",
    "sodium_free",
    "high_protein",
    "source_of_protein",
    "no_added_sugar",
    "multigrain",
]
ReviewedClaimName = Literal[
    "source_of_fibre",
    "high_fibre",
    "low_sugar",
    "sugar_free",
    "low_sodium",
    "very_low_sodium",
    "sodium_free",
]
SourceId = Literal["fssai-ac-2022-schedule-i", "fssai-ac-2018-general", "fssai-ac-compendium-v4"]
KNOWLEDGE_VERSION: Literal["claims-2026-10-06.1"] = "claims-2026-10-06.1"
BoundedText = Annotated[str, Field(strict=True, min_length=1, max_length=1024)]
ReasonId = Annotated[
    str, Field(strict=True, min_length=1, max_length=80, pattern=r"^[a-z][a-z0-9_]*$")
]


class IdentifiedClaim(ContractModel):
    claim_id: RowId
    claim: ClaimName
    region_id: RowId | None


class ClaimContext(ContractModel):
    food_category: Literal["ordinary_general_food", "special_food", "unknown"]
    form: Literal["solid", "liquid", "unknown"]
    preparation: Literal["as_sold", "as_prepared", "unknown"]


class ClaimsRequest(NormalizeRequest):
    claims: list[IdentifiedClaim] = Field(min_length=1, max_length=16)
    selected_table_id: RowId
    context: ClaimContext

    @model_validator(mode="after")
    def unique_claim_ids(self) -> Self:
        identifiers = [claim.claim_id for claim in self.claims]
        if len(identifiers) != len(set(identifiers)):
            raise ValueError("claim_id values must be unique")
        return self


class EvidenceSource(ContractModel):
    source_id: SourceId
    title: BoundedText
    url: Annotated[str, Field(strict=True, min_length=1, max_length=1024)]
    source_kind: Literal["gazette", "compendium"]
    pdf_sha256: Annotated[str, Field(strict=True, pattern=r"^[0-9a-f]{64}$")]
    pdf_bytes: Annotated[int, Field(strict=True, gt=0, le=10_000_000)]
    pdf_pages: list[Annotated[int, Field(strict=True, ge=1, le=100)]] = Field(
        min_length=1, max_length=16
    )
    publication_date: date | None
    effective_date: date | None
    verified_on: date
    verification_status: Literal["reviewed_current", "needs_review", "superseded"]
    qualification: BoundedText


class EvidenceRegistry(ContractModel):
    schema_version: Literal["1"]
    knowledge_version: Literal["claims-2026-10-06.1"]
    reviewed_on: date
    amendment_index_url: Annotated[str, Field(strict=True, max_length=1024)]
    sources: list[EvidenceSource] = Field(min_length=3, max_length=3)


class RuleCriterion(ContractModel):
    criterion_id: RowId
    nutrient: Literal["fibre", "sugars", "sodium"]
    basis: Literal["per_100_g", "per_100_mL", "per_100_kcal"]
    operator: Literal["gte", "lte"]
    threshold: CanonicalValue
    unit: Literal["g"]
    applicable_form: Literal["solid", "liquid", "either"]


class ClaimRule(ContractModel):
    rule_id: RowId
    claim: ReviewedClaimName
    combination: Literal["any"]
    criteria: list[RuleCriterion] = Field(min_length=2, max_length=3)
    source_ids: list[SourceId] = Field(min_length=2, max_length=3)
    evidence_locator: BoundedText
    supported_wording: BoundedText
    contradicted_wording: BoundedText
    scope: Literal["numeric_criterion_only"]
    preparation_policy: Literal["confirmed_matching_table"]
    food_category_policy: Literal["ordinary_general_food_only"]


class RuleSet(ContractModel):
    schema_version: Literal["1"]
    knowledge_version: Literal["claims-2026-10-06.1"]
    reviewed_on: date
    rules: list[ClaimRule] = Field(min_length=7, max_length=7)


class CriterionAssessment(ContractModel):
    criterion_id: RowId
    nutrient: Literal["fibre", "sugars", "sodium"]
    basis: Literal["per_100_g", "per_100_mL", "per_100_kcal"]
    operator: Literal["gte", "lte"]
    threshold: CanonicalValue
    unit: Literal["g"]
    alternative: Literal[True] = True
    applicable: bool
    outcome: Literal["pass", "fail", "unknown", "not_applicable"]
    value: CanonicalValue | None
    row_ids: list[RowId] = Field(max_length=64)
    reason: ReasonId | None


class ClaimAssessment(ContractModel):
    claim_id: RowId
    claim: ClaimName
    region_id: RowId | None
    status: Literal["supported", "contradicted", "insufficient_information"]
    applicability: Literal["applicable", "not_established", "not_reviewed"]
    scope: Literal["numeric_criterion_only"] = "numeric_criterion_only"
    reasons: list[ReasonId] = Field(max_length=32)
    missing_inputs: list[ReasonId] = Field(max_length=32)
    row_ids: list[RowId] = Field(max_length=64)
    criteria: list[CriterionAssessment] = Field(max_length=3)
    combination: Literal["any"] = "any"
    rule_id: RowId | None
    source_ids: list[SourceId] = Field(max_length=3)
    explanation: BoundedText


class ClaimEnergyConversion(ContractModel):
    version: Literal["fssai-schedule-i-note2-v1"] = "fssai-schedule-i-note2-v1"
    kj_per_kcal: float = Field(default=4.2, strict=True, ge=4.2, le=4.2, allow_inf_nan=False)
    source_id: Literal["fssai-ac-2022-schedule-i"] = "fssai-ac-2022-schedule-i"
    evidence_locator: Literal["Schedule I Note 2, Gazette PDF page 13"] = (
        "Schedule I Note 2, Gazette PDF page 13"
    )


class ClaimsResponse(ContractModel):
    schema_version: Literal["1"] = "1"
    client_request_id: UUID
    capture_session_id: UUID
    input_revision: Annotated[int, Field(strict=True, ge=0, le=2_147_483_647)]
    selected_table_id: RowId
    context: ClaimContext
    knowledge_version: Literal["claims-2026-10-06.1"]
    assessed_at: AwareDatetime
    assessment_basis: Literal["user_confirmed_label"] = "user_confirmed_label"
    energy_conversion: ClaimEnergyConversion = Field(default_factory=ClaimEnergyConversion)
    snapshot: NutritionSnapshot
    assessments: list[ClaimAssessment] = Field(min_length=1, max_length=16)
    warnings: list[ReasonId] = Field(max_length=16)


class ClaimsRulesResponse(ContractModel):
    schema_version: Literal["1"] = "1"
    status: Literal["ready", "unavailable"]
    knowledge_version: Literal["claims-2026-10-06.1"] | None
    reviewed_on: date | None
    energy_conversion: ClaimEnergyConversion = Field(default_factory=ClaimEnergyConversion)
    rules: list[ClaimRule] = Field(max_length=7)
    unsupported_claims: list[ClaimName] = Field(max_length=4)
    warnings: list[ReasonId] = Field(max_length=16)


class EvidenceResponse(ContractModel):
    schema_version: Literal["1"] = "1"
    status: Literal["found", "not_found", "unavailable"]
    requested_source_id: RowId
    knowledge_version: Literal["claims-2026-10-06.1"] | None
    source: EvidenceSource | None
    warnings: list[ReasonId] = Field(max_length=16)


class ClaimsUnavailable(ContractModel):
    schema_version: Literal["1"] = "1"
    status: Literal["unavailable"] = "unavailable"
    warnings: list[ReasonId] = Field(max_length=16)
