"""Immutable machine observations, separate from human-confirmed catalogue facts.

Only server-produced, exact-identity-compatible back-label readings enter this
stream. No endpoint accepts caller-written facts. Machine observations never
replace original catalogue/community records or acquire human confirmation.
"""

import hashlib
import json
import re
import unicodedata
from datetime import UTC, datetime
from decimal import Decimal
from typing import Annotated, Literal

from pydantic import AwareDatetime, Field, model_validator

from app.ai.models import (
    AiModel,
    ExtractedIdentity,
    ExtractedLabel,
    ExtractedNutritionTable,
    LabelText,
    ShortText,
)
from app.community.store import FirestoreContributionStore, StoreUnavailable

POLICY = "machine-unverified-v1"
MAX_OBSERVATIONS = 8
MAX_LIFETIME = 4000
MAX_FACT_BYTES = 32768
_HASH = r"^[0-9a-f]{64}$"
_CODE = r"^(?:[0-9]{8}|[0-9]{12,14})$"
FieldName = Annotated[str, Field(min_length=1, max_length=128)]
SourceId = Annotated[str, Field(min_length=1, max_length=256)]


def fold(value: str) -> str:
    return " ".join(unicodedata.normalize("NFKC", value).casefold().split())


def quantity(value: str) -> str:
    text = fold(value)
    match = re.fullmatch(r"([0-9]+(?:\.[0-9]+)?)\s*(mg|g|kg|ml|l)", text)
    if match is None:
        return text
    amount, unit = match.groups()
    factor, base = {"mg": (Decimal("0.001"), "g"), "g": (Decimal(1), "g"),
                    "kg": (Decimal(1000), "g"), "ml": (Decimal(1), "ml"),
                    "l": (Decimal(1000), "ml")}[unit]
    return f"{(Decimal(amount) * factor).normalize()} {base}"


def compatible_identity(observed: dict, known: dict) -> bool:
    # Barcode alone and name-only fuzzy matches cannot attach ingredients to a
    # different size or variant. Unknown required fields do not count as matches.
    for key in ("name", "brand", "quantity"):
        left, right = observed.get(key), known.get(key)
        if not left or not right:
            return False
        normalize = quantity if key == "quantity" else fold
        if normalize(left) != normalize(right):
            return False
    if known.get("variant") and (
        not observed.get("variant") or fold(observed["variant"]) != fold(known["variant"])
    ):
        return False
    return not (observed.get("barcode") and known.get("barcode") and
                observed["barcode"] != known["barcode"])


class MachineFacts(AiModel):
    identity: ExtractedIdentity
    ingredients: LabelText | None
    contains: LabelText | None
    may_contain: LabelText | None
    front_claims: list[ShortText] = Field(max_length=16)
    nutrition_tables: list[ExtractedNutritionTable] = Field(max_length=3)

    @classmethod
    def from_label(cls, label: ExtractedLabel) -> "MachineFacts":
        return cls.model_validate(label.model_dump(exclude={"schema_version", "evidence", "regions"}))


class MachineContribution(AiModel):
    schema_version: Literal["machine-label-contribution-v1"] = "machine-label-contribution-v1"
    evidence: Literal["machine_extracted_unverified"] = "machine_extracted_unverified"
    status: Literal["shared_unverified", "not_shared"]
    observation_id: str | None = Field(default=None, pattern=_HASH)
    barcode: str | None = Field(default=None, pattern=_CODE)
    reason: Literal["not_requested", "back_photo_required", "no_back_facts", "identity_unmatched",
                    "identity_conflict", "unavailable", "too_large", "capacity"] | None = None
    deduplicated: bool = False
    conflict_fields: list[FieldName] = Field(default_factory=list, max_length=128)

    @model_validator(mode="after")
    def valid_receipt(self):
        shared = self.status == "shared_unverified"
        if (shared != (self.observation_id is not None and self.barcode is not None)
                or shared == (self.reason is not None)
                or not shared and (self.deduplicated or self.conflict_fields
                                   or self.observation_id is not None or self.barcode is not None)):
            raise ValueError("Machine contribution receipt is inconsistent")
        return self


class MachineObservation(AiModel):
    schema_version: Literal["machine-label-observation-v1"] = "machine-label-observation-v1"
    observation_id: str = Field(pattern=_HASH)
    content_sha256: str = Field(pattern=_HASH)
    evidence: Literal["machine_extracted_unverified"] = "machine_extracted_unverified"
    contribution_policy: Literal["machine-unverified-v1"] = POLICY
    observed_at: AwareDatetime
    provider: Literal["gemini", "openai"]
    model: str = Field(min_length=1, max_length=128)
    provider_revision: int = Field(ge=1, le=2**53 - 1)
    barcode: str = Field(pattern=_CODE)
    identity_source_ids: list[SourceId] = Field(min_length=1, max_length=32)
    facts: MachineFacts
    conflict_fields: list[FieldName] = Field(default_factory=list, max_length=128)

    @model_validator(mode="after")
    def check_integrity(self):
        if len(canonical(self.facts.model_dump(mode="json"))) > MAX_FACT_BYTES:
            raise ValueError("Machine facts exceed the storage bounds")
        if self.content_sha256 != hashlib.sha256(canonical(self.facts.model_dump(mode="json"))).hexdigest():
            raise ValueError("Machine observation content changed")
        if self.observation_id != semantic_hash(self.barcode, self.facts):
            raise ValueError("Machine observation identity changed")
        if self.facts.identity.barcode not in {None, self.barcode}:
            raise ValueError("Machine observation barcode changed")
        if len(set(self.identity_source_ids)) != len(self.identity_source_ids):
            raise ValueError("Machine observation source IDs must be unique")
        return self


class MachineObservationLookup(AiModel):
    schema_version: Literal["machine-label-lookup-v1"] = "machine-label-lookup-v1"
    status: Literal["found", "not_found"]
    barcode: str = Field(pattern=_CODE)
    evidence: Literal["machine_extracted_unverified"] = "machine_extracted_unverified"
    observations: list[MachineObservation] = Field(default_factory=list, max_length=MAX_OBSERVATIONS)
    # Computed on every read, so an old compatible observation cannot hide a
    # newer disagreement. Nothing is silently selected from conflicting facts.
    conflict_fields: list[FieldName] = Field(default_factory=list, max_length=128)
    warnings: list[FieldName] = Field(default_factory=lambda: [
        "machine_readings_not_human_confirmed", "original_catalogue_facts_unchanged",
        "missing_allergen_text_does_not_mean_allergen_free",
    ])

    @model_validator(mode="after")
    def matching_observations(self):
        if ((self.status == "found") != bool(self.observations)
                or any(item.barcode != self.barcode for item in self.observations)
                or len({item.observation_id for item in self.observations}) != len(self.observations)):
            raise ValueError("Machine observations must match the exact requested product")
        return self


def canonical(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":"),
                      allow_nan=False).encode("utf-8")


def semantic_hash(barcode: str, facts: MachineFacts) -> str:
    value = facts.model_dump(mode="json")
    identity = value["identity"]
    identity["barcode"] = barcode
    for field in ("name", "brand", "variant", "quantity"):
        if identity[field] is not None:
            identity[field] = quantity(identity[field]) if field == "quantity" else fold(identity[field])
    for field in ("ingredients", "contains", "may_contain"):
        if value[field] is not None:
            value[field] = fold(value[field])
    value["front_claims"] = sorted({fold(text) for text in value["front_claims"]})
    tables = []
    for table in value["nutrition_tables"]:
        table.pop("table_id")
        table["basis"].pop("printed_text")
        for row in table["rows"]:
            row.pop("printed_text")
        table["rows"] = sorted(table["rows"], key=canonical)
        tables.append(table)
    value["nutrition_tables"] = sorted(tables, key=canonical)
    return hashlib.sha256(canonical([POLICY, value])).hexdigest()


def comparison_values(facts: MachineFacts) -> dict[str, set[str]]:
    values = {key: {fold(text)} for key in ("ingredients", "contains", "may_contain")
              if (text := getattr(facts, key)) is not None}
    for table in facts.nutrition_tables:
        basis = table.basis
        if basis.kind != "quantity" or basis.amount is None or table.preparation == "unknown":
            continue
        for row in table.rows:
            if row.value is None or row.qualifier != "exact":
                continue
            unit, value = row.unit, Decimal(str(row.value))
            if unit in {"g", "mg", "ug"}:
                value *= {"g": Decimal(1), "mg": Decimal("0.001"), "ug": Decimal("0.000001")}[unit]
                unit = "g"
            value = value * 100 / Decimal(str(basis.amount))
            key = f"nutrition.{table.preparation}.100{basis.unit}.{row.nutrient}.{unit}"
            values.setdefault(key, set()).add(str(value.normalize()))
    return values


def conflict_fields(values: list[dict[str, set[str]]]) -> list[str]:
    merged: dict[str, set[str]] = {}
    for source in values:
        for field, entries in source.items():
            merged.setdefault(field, set()).update(entries)
    return sorted(key for key, entries in merged.items() if len(entries) > 1)[:128]


def _pointer(raw: object, barcode: str) -> list[str]:
    if raw is None:
        return []
    if (not isinstance(raw, dict) or set(raw) != {"schema_version", "barcode", "observations"}
            or raw["schema_version"] != "1" or raw["barcode"] != barcode
            or not isinstance(raw["observations"], list) or len(raw["observations"]) > MAX_OBSERVATIONS
            or any(not isinstance(key, str) or re.fullmatch(_HASH, key) is None
                   for key in raw["observations"])
            or len(set(raw["observations"])) != len(raw["observations"])):
        raise StoreUnavailable()
    return raw["observations"]


def _observations(transactions: FirestoreContributionStore, ids: list[str], barcode: str,
                  transaction=None) -> list[MachineObservation]:
    refs = [transactions._ref("unlabel_machine_observations", key) for key in ids]
    records = transactions._batch(refs, transaction)
    result = []
    try:
        for ref in refs:
            record = records[ref.path]
            if (not isinstance(record, dict) or set(record) != {"payload_json", "record_sha256"}
                    or not isinstance(record["payload_json"], str)
                    or len(record["payload_json"].encode("utf-8")) > MAX_FACT_BYTES + 16384
                    or hashlib.sha256(record["payload_json"].encode("utf-8")).hexdigest() != record["record_sha256"]):
                raise ValueError("Machine observation record changed")
            value = MachineObservation.model_validate_json(record["payload_json"])
            if value.observation_id != ref.id or value.barcode != barcode:
                raise ValueError("Machine observation pointer changed")
            result.append(value)
    except (TypeError, ValueError, KeyError):
        raise StoreUnavailable() from None
    return result


def share_observation(transactions: FirestoreContributionStore, *, label: ExtractedLabel,
                      barcode: str, source_ids: list[str], baseline_values: list[dict[str, set[str]]],
                      provider: str, model: str, revision: int,
                      now: datetime | None = None) -> MachineContribution:
    if not isinstance(barcode, str) or re.fullmatch(_CODE, barcode) is None:
        raise StoreUnavailable()
    facts = MachineFacts.from_label(label)
    content = canonical(facts.model_dump(mode="json"))
    if len(content) > MAX_FACT_BYTES:
        return MachineContribution(status="not_shared", reason="too_large")
    digest = semantic_hash(barcode, facts)
    index = transactions._ref("unlabel_machine_products", barcode)
    lifetime = transactions._ref("unlabel_machine_limits", "lifetime")
    target = transactions._ref("unlabel_machine_observations", digest)

    def apply(transaction):
        records = transactions._batch([index, lifetime], transaction)
        ids = _pointer(records[index.path], barcode)
        previous = _observations(transactions, ids, barcode, transaction)
        conflicts = conflict_fields(baseline_values + [comparison_values(item.facts) for item in previous]
                                    + [comparison_values(facts)])
        if digest in ids:
            return MachineContribution(status="shared_unverified", observation_id=digest,
                                       barcode=barcode, deduplicated=True, conflict_fields=conflicts)
        raw = records[lifetime.path]
        count = 0 if raw is None else raw.get("count") if isinstance(raw, dict) else None
        if raw is not None and (not isinstance(raw, dict) or set(raw) != {"count"}
                                or type(count) is not int or not 0 <= count <= MAX_LIFETIME):
            raise StoreUnavailable()
        if len(ids) >= MAX_OBSERVATIONS or count >= MAX_LIFETIME:
            return MachineContribution(status="not_shared", reason="capacity")
        observation = MachineObservation(
            observation_id=digest, content_sha256=hashlib.sha256(content).hexdigest(),
            observed_at=now or datetime.now(UTC), provider=provider, model=model,
            provider_revision=revision, barcode=barcode, identity_source_ids=sorted(set(source_ids)),
            facts=facts, conflict_fields=conflicts,
        )
        payload = observation.model_dump_json()
        transaction.create(target, {"payload_json": payload,
                                    "record_sha256": hashlib.sha256(payload.encode("utf-8")).hexdigest()})
        transaction.set(index, {"schema_version": "1", "barcode": barcode, "observations": ids + [digest]})
        transaction.set(lifetime, {"count": count + 1})
        return MachineContribution(status="shared_unverified", observation_id=digest,
                                   barcode=barcode, conflict_fields=conflicts)

    return transactions._run(apply)


def lookup_observations(transactions: FirestoreContributionStore, barcode: str) -> MachineObservationLookup:
    if not isinstance(barcode, str) or re.fullmatch(_CODE, barcode) is None:
        raise StoreUnavailable()
    reference = transactions._ref("unlabel_machine_products", barcode)
    def read(transaction):
        ids = _pointer(transactions._batch([reference], transaction)[reference.path], barcode)
        items = _observations(transactions, ids, barcode, transaction)
        conflicts = set(conflict_fields([comparison_values(item.facts) for item in items]))
        conflicts.update(field for item in items for field in item.conflict_fields)
        return MachineObservationLookup(status="found" if items else "not_found", barcode=barcode,
                                        observations=items, conflict_fields=sorted(conflicts)[:128])
    return transactions._run(read)
