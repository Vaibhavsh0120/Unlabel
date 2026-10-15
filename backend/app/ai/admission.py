"""Attach automatic readings only to a known, exact product identity."""

from dataclasses import dataclass, field
from decimal import Decimal

from app.ai.models import ExtractedLabel, ExtractionRequest
from app.ai.observations import (
    MachineContribution,
    compatible_identity,
    fold,
)
from app.community.store import StoreUnavailable


@dataclass
class Baseline:
    barcode: str
    identities: list[dict] = field(default_factory=list)
    source_ids: list[str] = field(default_factory=list)
    values: list[dict[str, set[str]]] = field(default_factory=list)
    tables: list[dict] = field(default_factory=list)


def _snapshot_tables(snapshot, source_id: str) -> list[dict]:
    return [{"source_id": source_id, "table_id": table.source_table_id,
             "preparation": table.preparation, "basis": table.original_basis.model_dump(),
             "rows": [{"nutrient": row.nutrient, "value": row.value,
                       "unit": row.unit, "qualifier": "exact" if row.value is not None else "unknown"}
                      for row in snapshot.original_rows if row.table_id == table.source_table_id]}
            for table in snapshot.tables]


def _snapshot_values(snapshot) -> dict[str, set[str]]:
    values = {}
    for table in snapshot.tables:
        basis = table.normalized_basis
        if basis.kind != "quantity" or basis.amount != 100 or table.preparation == "unknown":
            continue
        for nutrient, cell in table.nutrients.items():
            if cell.value is not None:
                key = f"nutrition.{table.preparation}.100{basis.unit}.{nutrient}.{cell.unit}"
                values.setdefault(key, set()).add(str(Decimal(str(cell.value)).normalize()))
    return values


def known_baseline(state, barcode: str) -> Baseline:
    result = Baseline(barcode=barcode)
    catalogue = getattr(state, "catalogue", None)
    if catalogue is not None:
        snapshot = catalogue.lookup_facts(barcode)
        if snapshot.status == "unavailable":
            raise StoreUnavailable()
        if snapshot.status == "found":
            product = snapshot.product
            result.identities.append({"barcode": barcode, "name": product.name,
                                      "brand": product.brands, "quantity": product.quantity_text,
                                      "variant": None})
            result.source_ids.append(f"off:{snapshot.manifest.source_sha256}:{barcode}")
            result.tables.extend(_snapshot_tables(snapshot.details.nutrition.snapshot, result.source_ids[-1]))
            values = _snapshot_values(snapshot.details.nutrition.snapshot)
            if product.ingredients_text:
                values["ingredients"] = {fold(product.ingredients_text)}
            result.values.append(values)
    research = getattr(state, "research_catalogue", None)
    if research is not None:
        matches = research.by_barcode(barcode)
        if matches.status == "unavailable":
            raise StoreUnavailable()
        for candidate in matches.candidates:
            found = research.lookup(candidate.entry_id)
            observation = found.observation
            if found.status != "found" or observation is None:
                raise StoreUnavailable()
            if observation is None or observation.identity.match != "exact_sku":
                continue
            identity = observation.identity
            result.identities.append({key: getattr(identity, key)
                                      for key in ("barcode", "name", "brand", "variant", "quantity")})
            result.source_ids.append(f"research:{found.dataset_sha256}:{candidate.entry_id}")
            result.tables.extend({"source_id": result.source_ids[-1], "table_id": f"direct-{index}",
                                  "preparation": table.preparation, "basis": table.basis,
                                  "rows": [row.model_dump() for row in table.rows]}
                                 for index, table in enumerate(observation.nutrition.direct_tables))
            values = {key: {fold(section.text)} for key in ("ingredients", "contains", "may_contain")
                      if (section := getattr(observation.sections, key)) is not None}
            # Research tables retain their direct basis and qualifier. Compare
            # only explicit exact values, never legacy aggregate estimates.
            for table in observation.nutrition.direct_tables:
                basis = table.basis
                # Existing research basis permits an omitted kind when amount
                # and unit are explicit; a stated serving is never reclassified.
                if (basis.get("kind") not in {None, "quantity"} or not basis.get("amount")
                        or basis.get("unit") not in {"g", "mL"} or table.preparation == "unknown"):
                    continue
                for row in table.rows:
                    units = {"kcal", "kJ"} if row.nutrient == "energy" else {"g", "mg", "ug"}
                    if row.qualifier != "exact" or row.value is None or row.unit not in units:
                        continue
                    value, unit = Decimal(str(row.value)), row.unit
                    if unit in {"g", "mg", "ug"}:
                        value *= {"g": Decimal(1), "mg": Decimal("0.001"), "ug": Decimal("0.000001")}[unit]
                        unit = "g"
                    value = value * 100 / Decimal(str(basis["amount"]))
                    key = f"nutrition.{table.preparation}.100{basis['unit']}.{row.nutrient}.{unit}"
                    values.setdefault(key, set()).add(str(value.normalize()))
            result.values.append(values)
    runtime = getattr(state, "community_runtime", None)
    if runtime is not None:
        community = runtime.store.lookup(barcode)
        if community.status == "unavailable":
            raise StoreUnavailable()
        for revision in community.revisions:
            facts = revision.facts
            result.identities.append({"barcode": barcode, **facts.identity.model_dump(exclude={"language"})})
            result.source_ids.append(f"community:{revision.revision_id}")
            result.tables.extend(_snapshot_tables(revision.snapshot, result.source_ids[-1]))
            values = _snapshot_values(revision.snapshot)
            for key in ("ingredients", "contains", "may_contain"):
                section = getattr(facts, key)
                if section.text:
                    values[key] = {fold(section.text)}
            result.values.append(values)
    return result


def _name_match(state, label: ExtractedLabel) -> str | None:
    identity = label.identity.model_dump()
    name = identity["name"]
    if not name or not 2 <= len(name) <= 128 or not identity["brand"] or not identity["quantity"]:
        return None
    matches: set[str] = set()
    for kind, store in (("catalogue", getattr(state, "catalogue", None)),
                        ("research", getattr(state, "research_catalogue", None))):
        if store is None:
            continue
        found = store.search(name, limit=20)
        # A truncated candidate page cannot establish a unique exact identity.
        if found.status in {"refine_query", "unavailable"} or found.next_cursor is not None:
            return None
        for candidate in found.candidates:
            known = candidate.identity.model_dump()
            if kind == "catalogue":
                known["brand"] = known.pop("brands")
                known["quantity"] = known.pop("quantity_text")
            elif known.get("match") != "exact_sku":
                continue
            if known.get("barcode") and compatible_identity(identity, known):
                matches.add(known["barcode"])
    return next(iter(matches)) if len(matches) == 1 else None


def automatic_contribution(state, store, request: ExtractionRequest, label: ExtractedLabel,
                           *, provider: str, model: str, revision: int) -> MachineContribution:
    if request.catalogue_contribution is None:
        return MachineContribution(status="not_shared", reason="not_requested")
    if "back" not in {image.slot for image in request.images}:
        return MachineContribution(status="not_shared", reason="back_photo_required")
    if not any((label.ingredients, label.contains, label.may_contain, label.nutrition_tables)):
        return MachineContribution(status="not_shared", reason="no_back_facts")
    try:
        barcode = label.identity.barcode or _name_match(state, label)
        if barcode is None:
            return MachineContribution(status="not_shared", reason="identity_unmatched")
        baseline = known_baseline(state, barcode)
        if not baseline.identities or len(baseline.source_ids) > 32:
            return MachineContribution(status="not_shared", reason="identity_unmatched")
        identity = label.identity.model_dump()
        # All established sources must agree with the supplied identity. An
        # unavailable or disagreeing source is not a license to guess a match.
        if not all(compatible_identity(identity, known) for known in baseline.identities):
            return MachineContribution(status="not_shared", reason="identity_conflict")
        return store.share_machine_observation(
            label=label, barcode=barcode, source_ids=baseline.source_ids,
            baseline_values=baseline.values, provider=provider, model=model, revision=revision,
        )
    except (OSError, ValueError, StoreUnavailable):
        return MachineContribution(status="not_shared", reason="unavailable")
