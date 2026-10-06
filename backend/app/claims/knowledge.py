import json
from collections.abc import Sequence
from datetime import date
from pathlib import Path
from types import MappingProxyType
from typing import Literal, Mapping

from app.claims.models import (
    KNOWLEDGE_VERSION,
    ClaimRule,
    EvidenceRegistry,
    EvidenceSource,
    RuleSet,
)
from app.core.json_numbers import checked_float, reject_constant

MAX_KNOWLEDGE_BYTES = 262_144
UNSUPPORTED_CLAIMS = ("high_protein", "source_of_protein", "no_added_sugar", "multigrain")
SOURCE_URLS = {
    "fssai-ac-2022-schedule-i": (
        "https://fssai.gov.in/docs/food-law/regulations/amendments/advertising-claims/"
        "Gazette_Notification_Amendment_14_12_2022.pdf"
    ),
    "fssai-ac-2018-general": (
        "https://fssai.gov.in/docs/food-law/regulations/"
        "Gazette_Notification_Advertising_Claims_27_11_2018.pdf"
    ),
    "fssai-ac-compendium-v4": (
        "https://www.fssai.gov.in/upload/uploadfiles/files/"
        "Compendium_Advertising_Claims_Regulations_14_12_2022.pdf"
    ),
}
INDEX_URL = "https://fssai.gov.in/food-law/regulations/amendments/advertising-claims"
EXPECTED_CRITERIA = {
    "source_of_fibre": ("fibre", "gte", (3.0, 1.5, 1.5)),
    "high_fibre": ("fibre", "gte", (6.0, 3.0, 3.0)),
    "low_sugar": ("sugars", "lte", (5.0, 2.5)),
    "sugar_free": ("sugars", "lte", (0.5, 0.5)),
    "low_sodium": ("sodium", "lte", (0.120, 0.120)),
    "very_low_sodium": ("sodium", "lte", (0.040, 0.040)),
    "sodium_free": ("sodium", "lte", (0.005, 0.005)),
}


def _unique_object(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate knowledge field")
        result[key] = value
    return result


def _read_json(path: Path) -> dict:
    for component in (path, *path.parents):
        if component.is_symlink() or component.is_junction():
            raise ValueError("Knowledge links are not accepted")
    if not path.is_file():
        raise ValueError("Knowledge file is missing")
    with path.open("rb") as handle:
        payload = handle.read(MAX_KNOWLEDGE_BYTES + 1)
    if len(payload) > MAX_KNOWLEDGE_BYTES:
        raise ValueError("Knowledge exceeds its byte limit")
    try:
        value = json.loads(
            payload,
            object_pairs_hook=_unique_object,
            parse_float=checked_float,
            parse_constant=reject_constant,
        )
    except (UnicodeDecodeError, RecursionError) as exc:
        raise ValueError("Invalid knowledge data") from exc
    if not isinstance(value, dict):
        raise ValueError("Knowledge must be an object")
    return value


class KnowledgeStore:
    """Load a bounded, approved metadata projection; never fetch arbitrary source URLs."""

    def __init__(self, directory: Path):
        rules = RuleSet.model_validate(_read_json(directory / "rules/claims/reviewed-v1.json"))
        registry = EvidenceRegistry.model_validate(
            _read_json(directory / "sources/registry/fssai-claims-v1.json")
        )
        if rules.reviewed_on != registry.reviewed_on:
            raise ValueError("Knowledge review dates disagree")
        if registry.amendment_index_url != INDEX_URL:
            raise ValueError("Unknown amendment index")
        source_map = {source.source_id: source for source in registry.sources}
        if len(source_map) != 3 or set(source_map) != set(SOURCE_URLS):
            raise ValueError("Knowledge source identifiers must be unique and approved")
        for source_id, source in source_map.items():
            if source.url != SOURCE_URLS[source_id]:
                raise ValueError("Unknown evidence URL")
            if source.verified_on != registry.reviewed_on:
                raise ValueError("Evidence and registry review dates disagree")
        rule_map = {rule.claim: rule for rule in rules.rules}
        if len(rule_map) != 7 or set(rule_map) != set(EXPECTED_CRITERIA):
            raise ValueError("Reviewed claim identifiers must be unique and approved")
        if len({rule.rule_id for rule in rules.rules}) != 7:
            raise ValueError("Rule identifiers must be unique")
        for claim, rule in rule_map.items():
            if len(set(rule.source_ids)) != len(rule.source_ids):
                raise ValueError("Duplicate rule evidence")
            if not {"fssai-ac-2022-schedule-i", "fssai-ac-2018-general"}.issubset(rule.source_ids):
                raise ValueError("Rules require threshold and general-applicability evidence")
            nutrient, operator, thresholds = EXPECTED_CRITERIA[claim]
            expected = {
                ("per_100_g", "solid", nutrient, operator, thresholds[0]),
                ("per_100_mL", "liquid", nutrient, operator, thresholds[1]),
            }
            if len(thresholds) == 3:
                expected.add(("per_100_kcal", "either", nutrient, operator, thresholds[2]))
            actual = {
                (item.basis, item.applicable_form, item.nutrient, item.operator, item.threshold)
                for item in rule.criteria
            }
            if actual != expected or len(rule.criteria) != len(expected):
                raise ValueError("Rule criteria differ from the reviewed knowledge version")
            if len({item.criterion_id for item in rule.criteria}) != len(rule.criteria):
                raise ValueError("Criterion identifiers must be unique")
        self.knowledge_version: Literal["claims-2026-10-06.1"] = KNOWLEDGE_VERSION
        self.reviewed_on = registry.reviewed_on
        self.rules: Mapping[str, ClaimRule] = MappingProxyType(rule_map)
        self.sources: Mapping[str, EvidenceSource] = MappingProxyType(source_map)

    def evidence_current(self, source_ids: Sequence[str], *, today: date) -> bool:
        # This is an application review status, not a statutory expiry date.
        if self.reviewed_on > today:
            return False
        for source_id in source_ids:
            source = self.sources.get(source_id)
            if source is None or source.verification_status != "reviewed_current":
                return False
            if source.verified_on > today:
                return False
            if source.publication_date is not None and source.publication_date > today:
                return False
            if source.effective_date is not None and source.effective_date > today:
                return False
        return True
