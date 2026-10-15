"""One transactional AI selection for all workers, users and operations.

Selection stores slot identifiers, cooldowns and bounded counters. Structured
unverified facts use a separate bounded private staging collection; images,
prompts, raw OCR, provider envelopes and API keys are never persisted.
"""

import hashlib
import re
from collections.abc import Callable
from datetime import UTC, datetime, timedelta
from typing import Any, Protocol

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.ai.models import ExtractedLabel
from app.ai.observations import (
    MachineContribution,
    MachineObservationLookup,
    lookup_observations,
    share_observation,
)
from app.ai.staging import StagingResult, stage_machine_facts
from app.community.store import FirestoreContributionStore, StoreQuotaExceeded, StoreUnavailable


class ActiveSelection(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True, frozen=True)
    schema_version: str = "1"
    credential_id: str = Field(pattern=r"^[a-z][a-z0-9-]{0,47}$")
    revision: int = Field(ge=1, le=2**53 - 1)
    # Digest detects different credential configurations across rolling workers.
    configuration: str = Field(pattern=r"^[0-9a-f]{64}$")
    blocked_until: dict[str, datetime] = Field(default_factory=dict, max_length=8)

    @field_validator("schema_version")
    @classmethod
    def schema(cls, value: str) -> str:
        if value != "1":
            raise ValueError("Unknown AI selection schema")
        return value

    @field_validator("blocked_until")
    @classmethod
    def valid_cooldowns(cls, values: dict[str, datetime]) -> dict[str, datetime]:
        for key, value in values.items():
            if not re.fullmatch(r"[a-z][a-z0-9-]{0,47}", key) or value.tzinfo is None:
                raise ValueError("Invalid AI cooldown")
        return values


class AiSelectionConflict(Exception):
    def __init__(self) -> None:
        super().__init__("AI selection changed; read the current revision")


class AiSelectionStore(Protocol):
    def read(self, initial: str, configuration: str) -> ActiveSelection: ...
    def activate(
        self, credential_id: str, expected_revision: int,
        initial: str, configuration: str,
    ) -> ActiveSelection: ...
    def failed(
        self, observed: ActiveSelection, candidates: tuple[str, ...], cooldown_seconds: int,
    ) -> ActiveSelection: ...
    def admit(self, actor: str, *, daily_limit: int, actor_limit: int) -> None: ...
    def stage(self, actor: str, label: ExtractedLabel) -> StagingResult: ...
    def share_machine_observation(self, **kwargs) -> MachineContribution: ...
    def machine_observations(self, barcode: str) -> MachineObservationLookup: ...


class FirestoreAiSelectionStore:
    def __init__(self, database: Any, clock: Callable[[], datetime] | None = None) -> None:
        self._transactions = FirestoreContributionStore(database)
        self._clock = clock or (lambda: datetime.now(UTC))

    def stage(self, actor: str, label: ExtractedLabel) -> StagingResult:
        return stage_machine_facts(self._transactions, actor, label, now=self._now())

    def share_machine_observation(self, **kwargs) -> MachineContribution:
        return share_observation(self._transactions, **kwargs, now=self._now())

    def machine_observations(self, barcode: str) -> MachineObservationLookup:
        return lookup_observations(self._transactions, barcode)

    @property
    def _reference(self):
        # Auth initialization does not perform or require a database operation.
        return self._transactions._ref("unlabel_service_configuration", "ai-active")

    def _now(self) -> datetime:
        value = self._clock()
        if value.tzinfo is None:
            raise StoreUnavailable()
        return value.astimezone(UTC)

    @staticmethod
    def _load(record: Any, initial: str, configuration: str) -> ActiveSelection:
        if record is None:
            return ActiveSelection(credential_id=initial, revision=1, configuration=configuration)
        try:
            result = ActiveSelection.model_validate(record)
            return result
        except (TypeError, ValueError):
            raise StoreUnavailable() from None

    def read(self, initial: str, configuration: str) -> ActiveSelection:
        def apply(transaction):
            records = self._transactions._batch([self._reference], transaction)
            record = records[self._reference.path]
            current = self._load(record, initial, configuration)
            if record is None:
                transaction.set(self._reference, current.model_dump())
            return current
        return self._transactions._run(apply)

    def activate(
        self, credential_id: str, expected_revision: int,
        initial: str, configuration: str,
    ) -> ActiveSelection:
        def apply(transaction):
            records = self._transactions._batch([self._reference], transaction)
            previous = self._load(records[self._reference.path], initial, configuration)
            if previous.revision != expected_revision:
                # The shared transaction wrapper preserves StoreConflict subclasses.
                from app.community.store import StoreConflict
                raise StoreConflict()
            cooldowns = dict(previous.blocked_until)
            cooldowns.pop(credential_id, None)
            result = ActiveSelection(
                credential_id=credential_id, revision=previous.revision + 1,
                configuration=configuration, blocked_until=cooldowns,
            )
            transaction.set(self._reference, result.model_dump())
            return result
        from app.community.store import StoreConflict
        try:
            return self._transactions._run(apply)
        except StoreConflict:
            raise AiSelectionConflict() from None

    def failed(
        self, observed: ActiveSelection, candidates: tuple[str, ...], cooldown_seconds: int,
    ) -> ActiveSelection:
        if not 1 <= cooldown_seconds <= 86400 or len(candidates) > 8:
            raise StoreUnavailable()
        now = self._now()

        def apply(transaction):
            records = self._transactions._batch([self._reference], transaction)
            current = self._load(
                records[self._reference.path], observed.credential_id, observed.configuration
            )
            if current.configuration != observed.configuration:
                return current
            # An old in-flight failure cannot undo a manual or another worker's switch.
            if current.revision != observed.revision or current.credential_id != observed.credential_id:
                return current
            valid_slots = {*candidates, observed.credential_id}
            blocked = {
                key: until for key, until in current.blocked_until.items()
                if until > now and key in valid_slots
            }
            blocked[observed.credential_id] = max(
                blocked.get(observed.credential_id, now),
                now + timedelta(seconds=cooldown_seconds),
            )
            selected = next(
                (key for key in candidates if key != observed.credential_id and key not in blocked),
                observed.credential_id,
            )
            result = ActiveSelection(
                credential_id=selected, revision=current.revision + 1,
                configuration=current.configuration, blocked_until=blocked,
            )
            transaction.set(self._reference, result.model_dump())
            return result
        return self._transactions._run(apply)

    def admit(self, actor: str, *, daily_limit: int, actor_limit: int) -> None:
        if (
            not re.fullmatch(r"[0-9a-f]{64}", actor)
            or not 1 <= daily_limit <= 200 or not 1 <= actor_limit <= 20
        ):
            raise StoreUnavailable()
        now = self._now()
        day = now.strftime("%Y-%m-%d")
        # Fixed document IDs prevent unbounded per-day history. Actor buckets bound
        # storage to 256 documents; collisions share a conservative allowance.
        bucket = hashlib.sha256(actor.encode()).hexdigest()[:2]
        global_ref = self._transactions._ref("unlabel_ai_limits", "global")
        actor_ref = self._transactions._ref("unlabel_ai_limits", "actor-" + bucket)

        def count(record: Any, maximum: int) -> int:
            if record is None:
                return 0
            if (
                not isinstance(record, dict) or set(record) != {"day", "count"}
                or not isinstance(record["day"], str)
                or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", record["day"])
                or type(record["count"]) is not int or not 0 <= record["count"] <= maximum
            ):
                raise StoreUnavailable()
            return record["count"] if record["day"] == day else 0

        def apply(transaction):
            records = self._transactions._batch([global_ref, actor_ref], transaction)
            global_count = count(records[global_ref.path], 200)
            actor_count = count(records[actor_ref.path], 20)
            if global_count >= daily_limit or actor_count >= actor_limit:
                raise StoreQuotaExceeded()
            transaction.set(global_ref, {"day": day, "count": global_count + 1})
            transaction.set(actor_ref, {"day": day, "count": actor_count + 1})
        self._transactions._run(apply)
