"""Strict bounded private data: no passwords, tokens, photos, OCR or arbitrary metadata."""

import json
from datetime import datetime
from typing import Annotated, Literal, Self

from pydantic import AwareDatetime, BeforeValidator, Field, model_validator

from app.community.models import CommunityModel, SubmissionId, visible_text
from app.reports.models import LabelReport

MAX_SNAPSHOT_BYTES = 384 * 1024
MAX_BODY_BYTES = 512 * 1024
MAX_REVISION = 2_147_483_647


def timestamp(value: object) -> datetime:
    if isinstance(value, str):
        try:
            value = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            raise ValueError("An aware ISO timestamp is required") from None
    if not isinstance(value, datetime) or value.tzinfo is None or value.utcoffset() is None:
        raise ValueError("An aware ISO timestamp is required")
    return value


def report_from_json(value: object) -> LabelReport:
    if isinstance(value, LabelReport):
        return value
    # FastAPI decodes request JSON to Python first. Re-enter strict JSON validation
    # for the existing contract's ISO date fields without weakening that contract.
    try:
        return LabelReport.model_validate_json(json.dumps(value, allow_nan=False))
    except (TypeError, ValueError):
        raise ValueError("A valid label-report-v1 document is required") from None


Timestamp = Annotated[AwareDatetime, BeforeValidator(timestamp)]
Revision = Annotated[int, Field(strict=True, ge=0, le=MAX_REVISION)]


class ScannerProfile(CommunityModel):
    display_name: (
        Annotated[str, BeforeValidator(visible_text), Field(min_length=1, max_length=80)] | None
    ) = None


class PersonalEntry(CommunityModel):
    entry_id: SubmissionId
    recorded_at: Timestamp
    report: Annotated[LabelReport, BeforeValidator(report_from_json)]


class PersonalData(CommunityModel):
    profile: ScannerProfile = Field(default_factory=ScannerProfile)
    saved: list[PersonalEntry] = Field(default_factory=list, max_length=50)
    history: list[PersonalEntry] = Field(default_factory=list, max_length=100)

    @model_validator(mode="after")
    def bounded_unique_snapshot(self) -> Self:
        for entries in (self.saved, self.history):
            if len({entry.entry_id for entry in entries}) != len(entries):
                raise ValueError("Each library requires unique entry identifiers")
        if len(self.model_dump_json().encode("utf-8")) > MAX_SNAPSHOT_BYTES:
            raise ValueError("Private snapshot exceeds its byte budget")
        return self


class SyncRequest(CommunityModel):
    schema_version: Literal["1"] = "1"
    expected_revision: Revision
    mutation_id: SubmissionId
    data: PersonalData


class SyncSnapshot(CommunityModel):
    schema_version: Literal["1"] = "1"
    sync_version: Literal["personal-sync-v1"] = "personal-sync-v1"
    revision: Revision = 0
    updated_at: Timestamp | None = None
    data: PersonalData = Field(default_factory=PersonalData)

    @model_validator(mode="after")
    def revision_date(self) -> Self:
        if (self.revision == 0) != (self.updated_at is None):
            raise ValueError("Only an uncreated snapshot has no update time")
        return self


class SyncFailure(CommunityModel):
    schema_version: Literal["1"] = "1"
    status: Literal["unauthorized", "conflict", "rate_limited", "unavailable"]
    code: Literal[
        "account_authentication_required",
        "account_sync_unavailable",
        "account_revision_conflict",
        "account_sync_limit",
    ]
    current_revision: Revision | None = None
