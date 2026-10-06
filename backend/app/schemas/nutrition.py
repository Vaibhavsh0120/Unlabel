from typing import Annotated, Literal, Self, get_args
from uuid import UUID

from pydantic import BeforeValidator, Field, model_validator

from app.schemas.products import ContractModel

NutrientName = Literal[
    "energy",
    "fat",
    "saturated_fat",
    "carbohydrates",
    "carbohydrates_total",
    "sugars",
    "added_sugars",
    "fibre",
    "protein",
    "sodium",
    "salt",
]
NUTRIENT_NAMES: tuple[NutrientName, ...] = get_args(NutrientName)
Preparation = Literal["as_sold", "as_prepared"]
Completeness = Literal["complete", "partial"]
NormalizationStatus = Literal["complete", "partial", "needs_correction"]
CellReason = Literal[
    "not_reported",
    "unknown_value",
    "conflicting_values",
    "conversion_missing_basis",
    "conversion_out_of_bounds",
]
RowId = Annotated[str, Field(min_length=1, max_length=64, pattern=r"^[A-Za-z0-9][A-Za-z0-9._:-]*$")]
InputValue = Annotated[float, Field(strict=True, ge=0, le=1_000_000, allow_inf_nan=False)]
BasisAmount = Annotated[float, Field(strict=True, gt=0, le=100_000, allow_inf_nan=False)]
CanonicalValue = Annotated[float, Field(strict=True, ge=0, le=1_000_000_000, allow_inf_nan=False)]


def require_confirmation(value: object) -> bool:
    if value is not True:
        raise ValueError("confirmed must be the boolean true")
    return True


class NutritionBasis(ContractModel):
    kind: Literal["quantity", "serving"]
    amount: BasisAmount | None = None
    unit: Literal["g", "mL"] | None = None

    @model_validator(mode="after")
    def validate_measurement(self) -> Self:
        if (self.amount is None) != (self.unit is None):
            raise ValueError("basis amount and unit must both be present or both be null")
        if self.kind == "quantity" and self.amount is None:
            raise ValueError("quantity basis requires an amount and a unit")
        return self


class NutrientRow(ContractModel):
    row_id: RowId
    table_id: RowId
    nutrient: NutrientName
    value: InputValue | None
    unit: Literal["g", "mg", "ug", "kcal", "kJ"]
    basis: NutritionBasis
    preparation: Preparation

    @model_validator(mode="after")
    def validate_unit(self) -> Self:
        energy_unit = self.unit in ("kcal", "kJ")
        if energy_unit != (self.nutrient == "energy"):
            raise ValueError("energy requires kcal or kJ; other nutrients require g, mg or ug")
        return self


class NormalizeRequest(ContractModel):
    schema_version: Literal["1"] = "1"
    client_request_id: UUID
    capture_session_id: UUID
    input_revision: Annotated[int, Field(strict=True, ge=0, le=2_147_483_647)]
    confirmed: Annotated[Literal[True], BeforeValidator(require_confirmation)]
    completeness: Completeness
    rows: list[NutrientRow] = Field(min_length=1, max_length=64)

    @model_validator(mode="after")
    def validate_unique_rows(self) -> Self:
        identifiers = [row.row_id for row in self.rows]
        if len(identifiers) != len(set(identifiers)):
            raise ValueError("row_id values must be unique within the request")
        return self


class NutrientCell(ContractModel):
    value: CanonicalValue | None
    unit: Literal["g", "kcal"]
    reason: CellReason | None = None
    source_row_ids: list[RowId] = Field(default_factory=list, max_length=64)
    conversion: str | None = Field(default=None, max_length=512)


class NutritionTable(ContractModel):
    source_table_id: RowId
    preparation: Preparation
    original_basis: NutritionBasis
    normalized_basis: NutritionBasis
    nutrients: dict[NutrientName, NutrientCell]


class NutritionSnapshot(ContractModel):
    normalization_version: Literal["1"] = "1"
    status: NormalizationStatus
    tables: list[NutritionTable] = Field(default_factory=list, max_length=64)
    original_rows: list[NutrientRow] = Field(default_factory=list, max_length=64)
    warnings: list[str] = Field(default_factory=list)
