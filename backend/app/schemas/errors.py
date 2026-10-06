from typing import Literal

from pydantic import ConfigDict, Field

from app.schemas.products import ContractModel


class ValidationErrorDetail(ContractModel):
    model_config = ConfigDict(strict=True)

    loc: list[str | int]
    type: str
    msg: Literal["Invalid request data"]


class ValidationFailure(ContractModel):
    model_config = ConfigDict(strict=True)

    detail: list[ValidationErrorDetail] = Field(max_length=32)
    errors_truncated: bool
