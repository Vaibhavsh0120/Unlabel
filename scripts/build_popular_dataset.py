"""Build or verify an offline popular-India research supplement, without network work.

This dataset does not replace the bulk OFF acquisition or enter any served API.
Each independently dated observation has an immutable content hash. Conflicts are
recorded separately, and unknown identity, reuse rights or values remain unknown.
Only bounded public facts are retained; page HTML, images and contributor data are
not part of the acquired supplement. Run with --help for explicit input paths.
"""

import argparse
import gzip
import hashlib
import io
import json
import math
import os
import re
import stat
import tempfile
import unicodedata
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from pathlib import Path
from typing import Literal, overload
from urllib.parse import parse_qsl, urlsplit

ROOT = Path(__file__).resolve().parent.parent
MAX_INPUT_BYTES = 8 * 1024**2
MAX_DATASET_BYTES = 32 * 1024**2
MAX_RECORD_BYTES = 256 * 1024
MAX_MANIFEST_BYTES = 2 * 1024**2
MAX_OBSERVATIONS = 5000
MAX_INPUT_FILES = 100
DATA_FILE = "observations.jsonl.gz"
MANIFEST_FILE = "manifest.json"
SCHEMA = "popular-india-research-v1"
BARCODE = re.compile(r"(?:[0-9]{8}|[0-9]{12,14})\Z")
HASH = re.compile(r"[0-9a-f]{64}\Z")
OFF_HOSTS = {"world.openfoodfacts.org", "in.openfoodfacts.org", "en.openfoodfacts.org"}
PROVIDERS = {"open_food_facts", "manufacturer", "retailer"}
QUALIFIERS = {
    "exact",
    "less_than",
    "less_than_or_equal",
    "greater_than",
    "greater_than_or_equal",
    "approximate",
    "unknown",
}
OFF_FIELDS = {
    "code",
    "countries_tags",
    "product_name",
    "brands",
    "quantity",
    "ingredients_text",
    "allergens_tags",
    "traces_tags",
    "categories_tags",
    "labels_tags",
    "nutriscore_grade",
    "nova_group",
    "schema_version",
    "last_modified_t",
    "lc",
    "nutrition_legacy_present",
}
OFF_NUTRIENTS = {
    "energy-kcal": "energy",
    "energy-kj": "energy",
    "fat": "fat",
    "saturated-fat": "saturated_fat",
    "carbohydrates": "carbohydrates",
    "carbohydrates-total": "carbohydrates_total",
    "sugars": "sugars",
    "added-sugars": "added_sugars",
    "fiber": "fibre",
    "proteins": "protein",
    "sodium": "sodium",
    "salt": "salt",
}
METADATA_FIELDS = {
    "evidence",
    "conflicts",
    "unknowns",
    "quantity_variants",
    "notes",
    "candidate_id",
    "candidate_numeric_table",
    "candidate_numeric_table_alternatives",
    "identity_note",
}
PRIVATE_KEYS = {
    "creator",
    "editors",
    "uploader",
    "user_id",
    "uid",
    "email",
    "password",
    "token",
    "api_key",
    "raw_ocr",
    "photo",
    "image_bytes",
    "service_account",
    "private_key",
}


def _canonical(value):
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")


def _digest(data):
    return hashlib.sha256(data).hexdigest()


def _object(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError("Research input contains duplicate JSON fields")
        value[key] = item
    return value


def _number(token):
    value = float(token)
    if not math.isfinite(value) or Decimal(token) != Decimal(str(value)):
        raise ValueError("Research input contains an unrepresentable JSON number")
    return value


def _constant(_token):
    raise ValueError("Research input contains nonfinite JSON numbers")


def _json(data):
    try:
        return json.loads(
            data.decode("utf-8"),
            object_pairs_hook=_object,
            parse_float=_number,
            parse_constant=_constant,
        )
    except (UnicodeError, RecursionError, OverflowError) as error:
        raise ValueError("Research input is not bounded UTF-8 JSON") from error


def _path(path):
    path = Path(path).absolute()
    if any(p.is_symlink() or p.is_junction() for p in (path, *path.parents)):
        raise ValueError("Research dataset paths cannot contain links or junctions")
    return path


def _read(path, limit):
    path = _path(path)
    if not stat.S_ISREG(path.stat().st_mode) or not 0 < path.stat().st_size <= limit:
        raise ValueError("Research artifact exceeds its regular-file byte bounds")
    with path.open("rb") as stream:
        data = stream.read(limit + 1)
    if len(data) > limit:
        raise ValueError("Research artifact exceeds its byte bounds")
    return data


def _keys(value, allowed, label):
    if not isinstance(value, dict) or set(value) - allowed:
        raise ValueError(f"Invalid {label} fields")


@overload
def _text(value, limit, *, nullable: Literal[False] = False, allow_lines=False) -> str: ...


@overload
def _text(value, limit, *, nullable: Literal[True], allow_lines=False) -> str | None: ...


def _text(value, limit, *, nullable=False, allow_lines=False) -> str | None:
    if value is None and nullable:
        return None
    if (
        not isinstance(value, str)
        or not value.strip()
        or len(value) > limit
        or any(
            unicodedata.category(c) in {"Cc", "Cs"} and not (allow_lines and c in "\n\r\t")
            for c in value
        )
    ):
        raise ValueError("Research public text exceeds its bounds")
    return value.strip()


def _url(value):
    value = _text(value, 2048)
    try:
        parsed = urlsplit(value)
        if (
            not value.isascii()
            or any(c.isspace() for c in value)
            or parsed.scheme != "https"
            or not parsed.hostname
            or parsed.username is not None
            or parsed.password is not None
            or parsed.port not in {None, 443}
            or parsed.fragment
            or any(
                re.search(r"token|password|secret|api.?key|authorization", key, re.IGNORECASE)
                for key, _ in parse_qsl(parsed.query)
            )
        ):
            raise ValueError("Research source URL must be public HTTPS without credentials")
    except ValueError as error:
        raise ValueError("Research source URL must be public HTTPS without credentials") from error
    return value


@overload
def _date(value, *, nullable: Literal[False] = False) -> str: ...


@overload
def _date(value, *, nullable: Literal[True]) -> str | None: ...


def _date(value, *, nullable=False) -> str | None:
    if value is None and nullable:
        return None
    if not isinstance(value, str) or len(value) > 64 or "T" not in value:
        raise ValueError("Research dates require an aware ISO timestamp")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if parsed.utcoffset() is None or parsed > datetime.now(UTC) + timedelta(days=1):
            raise ValueError("Research date is unaware or in the future")
        return parsed.astimezone(UTC).isoformat().replace("+00:00", "Z")
    except (ValueError, OverflowError) as error:
        raise ValueError("Research dates require a bounded aware timestamp") from error


def _metadata(value, depth=0, text_limit=2000):
    if depth > 8:
        raise ValueError("Research metadata exceeds depth bounds")
    if value is None or type(value) is bool:
        return value
    if isinstance(value, str):
        if len(value) > text_limit or any(
            unicodedata.category(c) in {"Cc", "Cs"} and c not in "\n\r\t" for c in value
        ):
            raise ValueError("Research metadata public text exceeds its bounds")
        return value
    if type(value) in {int, float}:
        if not math.isfinite(value) or abs(value) > 10**12:
            raise ValueError("Research metadata exceeds numeric bounds")
        return value
    if isinstance(value, list) and len(value) <= 100:
        return [_metadata(item, depth + 1, text_limit) for item in value]
    if isinstance(value, dict) and len(value) <= 50:
        result = {}
        for key, item in value.items():
            key = _text(key, 128)
            if key.casefold() in PRIVATE_KEYS:
                raise ValueError("Research metadata cannot contain private identity or image data")
            result[key] = _metadata(item, depth + 1, text_limit)
        return result
    raise ValueError("Research metadata exceeds collection bounds")


def _source(raw):
    _keys(
        raw,
        {
            "provider",
            "url",
            "retrieved_at",
            "source_updated_at",
            "license",
            "reuse_status",
        },
        "source",
    )
    provider = raw.get("provider")
    if provider not in PROVIDERS:
        raise ValueError("Unknown research source provider")
    url = _url(raw.get("url"))
    if provider == "open_food_facts" and urlsplit(url).hostname not in OFF_HOSTS:
        raise ValueError("OFF observations require an official exact-product source URL")
    license_data = raw.get("license")
    if isinstance(license_data, str):
        license_data = {
            "database": None,
            "contents": None,
            "images": None,
            "reuse_status": raw.get("reuse_status", "review_required"),
            "note": _text(license_data, 256),
        }
    _keys(
        license_data,
        {"database", "contents", "images", "reuse_status", "note"},
        "license",
    )
    license_data = {
        key: _text(license_data.get(key), 256, nullable=True)
        for key in ("database", "contents", "images", "note")
    } | {
        "reuse_status": _text(license_data.get("reuse_status"), 128),
    }
    if provider != "open_food_facts" and any(
        license_data[key] in {"ODbL-1.0", "DbCL-1.0"} for key in ("database", "contents")
    ):
        raise ValueError("Non-OFF research cannot inherit OFF reuse licenses")
    retrieved_at = _date(raw.get("retrieved_at"))
    updated_at = _date(raw.get("source_updated_at"), nullable=True)
    if updated_at is not None and updated_at > retrieved_at:
        raise ValueError("Source modification cannot be after source retrieval")
    return {
        "provider": provider,
        "url": url,
        "retrieved_at": retrieved_at,
        "source_updated_at": updated_at,
        "license": license_data,
    }


def _provenance(raw, source):
    result = dict(source)
    result["url"] = _url(raw.get("source_url") or source["url"])
    if urlsplit(result["url"]).hostname != urlsplit(source["url"]).hostname:
        raise ValueError("A separately hosted fact requires its own source observation")
    result["retrieved_at"] = _date(raw.get("retrieved_at") or source["retrieved_at"])
    result["source_updated_at"] = _date(
        raw.get("source_updated_at", source["source_updated_at"]), nullable=True
    )
    if result["source_updated_at"] is not None and datetime.fromisoformat(
        result["source_updated_at"]
    ) > datetime.fromisoformat(result["retrieved_at"]):
        raise ValueError("Fact modification cannot be after retrieval")
    if raw.get("provenance") is not None and raw["provenance"] != result:
        raise ValueError("Section provenance differs from its source/date reference")
    return result


def _identity(raw, source):
    _keys(
        raw,
        {
            "barcode",
            "name",
            "brand",
            "variant",
            "quantity",
            "market",
            "match",
            "barcode_evidence_url",
        },
        "identity",
    )
    code = raw.get("barcode")
    if code is not None and (not isinstance(code, str) or BARCODE.fullmatch(code) is None):
        raise ValueError("Research barcode format is invalid")
    result = {
        "barcode": code,
        **{
            field: _text(raw.get(field), 2000 if field == "name" else 256, nullable=True)
            for field in ("name", "brand", "variant", "quantity")
        },
    }
    if raw.get("market") not in {"india", "unknown"}:
        raise ValueError("Research identity market must remain explicit")
    match = raw.get("match")
    if match not in {"exact_sku", "brand_family_only", "identity_unconfirmed"}:
        raise ValueError("Research identity match must remain explicit")
    evidence_url = raw.get("barcode_evidence_url")
    if evidence_url is not None:
        evidence_url = _url(evidence_url)
    if match == "exact_sku" and (
        code is None
        or evidence_url is None
        or raw["market"] != "india"
        or any(result[field] is None for field in ("name", "brand", "quantity"))
    ):
        raise ValueError("Exact research barcode identity requires declared SKU/pack evidence")
    if source["provider"] == "open_food_facts":
        product_path = re.search(
            r"/(?:api/v[0-9.]+/product|product)/([0-9]{8,14})(?:\.json|/|$)",
            urlsplit(source["url"]).path,
        )
        if product_path is None or product_path[1] != code:
            raise ValueError("OFF requested and response barcode identities disagree")
    return result | {
        "market": raw["market"],
        "match": match,
        "barcode_evidence_url": evidence_url,
    }


def _sections(raw, source):
    _keys(raw, {"ingredients", "contains", "may_contain"}, "section")
    result = {}
    for key in ("ingredients", "contains", "may_contain"):
        section = raw.get(key)
        if section is None:
            result[key] = None
            continue
        _keys(
            section,
            {
                "text",
                "completeness",
                "source_url",
                "retrieved_at",
                "source_updated_at",
                "provenance",
            },
            "section",
        )
        if section.get("completeness") not in {"complete", "partial", "unknown"}:
            raise ValueError("Section completeness must be explicit")
        result[key] = {
            "text": _text(section.get("text"), 16000, allow_lines=True),
            "completeness": section["completeness"],
            "source_url": _url(section.get("source_url") or source["url"]),
            "provenance": _provenance(section, source),
        }
    return result


def _nutrition(raw, source):
    _keys(
        raw,
        {"direct_tables", "legacy_aggregates", "legacy_present", "availability"},
        "nutrition",
    )
    tables = raw.get("direct_tables", [])
    if not isinstance(tables, list) or len(tables) > 16:
        raise ValueError("Research nutrition table bounds exceeded")
    result = []
    for table in tables:
        _keys(
            table,
            {
                "source",
                "basis",
                "preparation",
                "rows",
                "source_url",
                "retrieved_at",
                "source_updated_at",
                "provenance",
                "table_id",
            },
            "nutrition table",
        )
        allowed = (
            {"packaging", "manufacturer"}
            if source["provider"] == "open_food_facts"
            else (
                {"manufacturer"}
                if source["provider"] == "manufacturer"
                else {"retailer_transcription"}
            )
        )
        if table.get("source") not in allowed:
            raise ValueError("Research nutrition source cannot impersonate another provider")
        basis = table.get("basis")
        _keys(basis, {"amount", "unit", "kind", "description"}, "nutrition basis")
        amount = basis.get("amount")
        if amount is not None and (
            type(amount) not in {int, float}
            or not math.isfinite(amount)
            or not 0 < amount <= 1000000
        ):
            raise ValueError("Research nutrition basis amount is invalid")
        unit = _text(basis.get("unit"), 32, nullable=True)
        if unit is None and amount is not None:
            raise ValueError("Research nutrition quantity requires an explicit unit")
        if table.get("preparation") not in {"as_sold", "as_prepared", "unknown"}:
            raise ValueError("Research nutrition preparation is invalid")
        rows = table.get("rows")
        if not isinstance(rows, list) or not 1 <= len(rows) <= 200:
            raise ValueError("Research nutrient row bounds exceeded")
        normal_rows = []
        for row in rows:
            _keys(
                row,
                {"nutrient", "value", "unit", "raw_label", "qualifier", "row_id"},
                "nutrient row",
            )
            value = row.get("value")
            if value is not None and (
                type(value) not in {int, float}
                or not math.isfinite(value)
                or not 0 <= value <= 1000000
            ):
                raise ValueError("Research nutrient value is invalid")
            qualifier = row.get("qualifier", "unknown" if value is None else "exact")
            qualifier = {
                "lt": "less_than",
                "lte": "less_than_or_equal",
                "gt": "greater_than",
                "gte": "greater_than_or_equal",
            }.get(qualifier, qualifier)
            if qualifier not in QUALIFIERS or (value is None and qualifier != "unknown"):
                raise ValueError("Research nutrient qualification is invalid")
            normal_rows.append(
                {
                    "nutrient": _text(row.get("nutrient"), 128),
                    "value": value,
                    "unit": _text(row.get("unit"), 32, nullable=True),
                    "qualifier": qualifier,
                    "raw_label": _text(row.get("raw_label"), 2000, nullable=True),
                }
            )
        result.append(
            {
                "source": table["source"],
                "basis": _metadata(basis),
                "preparation": table["preparation"],
                "rows": normal_rows,
                "source_url": _url(table.get("source_url") or source["url"]),
                "retrieved_at": _date(table.get("retrieved_at") or source["retrieved_at"]),
                "source_updated_at": _date(
                    table.get("source_updated_at", source["source_updated_at"]),
                    nullable=True,
                ),
                "provenance": _provenance(table, source),
            }
        )
    legacy = _metadata(raw.get("legacy_aggregates"))
    present = raw.get("legacy_present", legacy is not None)
    if type(present) is not bool or (legacy is not None and not present):
        raise ValueError("Research legacy nutrition presence is inconsistent")
    availability = (
        "direct_reported" if result else "legacy_aggregate_only" if present else "missing"
    )
    if raw.get("availability", availability) != availability:
        raise ValueError("Research nutrition availability cannot invent direct tables")
    return {
        "availability": availability,
        "direct_tables": result,
        "legacy_present": present,
        "legacy_aggregates": legacy,
    }


def _normalise(raw):
    _keys(
        raw,
        {
            "source",
            "identity",
            "sections",
            "nutrition",
            "metadata",
            "observation_id",
            "schema_version",
            "eligibility",
            "raw_projection",
        }
        | METADATA_FIELDS,
        "observation",
    )
    source = _source(raw.get("source"))
    identity = _identity(raw.get("identity"), source)
    metadata = raw.get("metadata", {})
    _keys(metadata, METADATA_FIELDS, "research metadata")
    metadata = dict(metadata)
    for key in METADATA_FIELDS:
        if key in raw:
            metadata[key] = raw[key]
    _keys(metadata, METADATA_FIELDS, "research metadata")
    result = {
        "schema_version": SCHEMA,
        "source": source,
        "identity": identity,
        "eligibility": identity["match"],
        "sections": _sections(raw.get("sections", {}), source),
        "nutrition": _nutrition(raw.get("nutrition", {}), source),
        "metadata": _metadata(metadata),
    }
    if raw.get("raw_projection") is not None:
        projection = raw["raw_projection"]
        _keys(
            projection,
            OFF_FIELDS | {"nutrition", "nutriments"},
            "OFF public projection",
        )
        if source["provider"] != "open_food_facts" or projection.get("code") != identity["barcode"]:
            raise ValueError("Raw OFF projection must retain the exact OFF barcode identity")
        result["raw_projection"] = _metadata(projection, text_limit=16000)
    if (
        raw.get("schema_version", SCHEMA) != SCHEMA
        or raw.get("eligibility", identity["match"]) != identity["match"]
    ):
        raise ValueError("Research observation schema/eligibility is inconsistent")
    identifier = _digest(_canonical(result))
    if raw.get("observation_id", identifier) != identifier:
        raise ValueError("Research observation differs from its immutable content hash")
    result["observation_id"] = identifier
    if len(_canonical(result)) > MAX_RECORD_BYTES:
        raise ValueError("Research observation exceeds its byte bounds")
    return result


def _off(raw):
    _keys(raw, {"source", "product", "research_category"}, "OFF wrapper")
    _text(raw.get("research_category"), 256, nullable=True)
    product = raw.get("product")
    if not isinstance(product, dict):
        raise ValueError("OFF research wrapper requires a public product projection")  # noqa: TRY004
    countries = product.get("countries_tags", [])
    if (
        not isinstance(countries, list)
        or len(countries) > 100
        or any(not isinstance(tag, str) or len(tag) > 256 for tag in countries)
    ):
        raise ValueError("OFF countries tags cannot establish an unknown market")
    source = _source(raw.get("source"))
    if source["provider"] != "open_food_facts":
        raise ValueError("OFF input cannot impersonate another source")
    projection = {key: product[key] for key in OFF_FIELDS if key in product}
    if source["source_updated_at"] is None and type(product.get("last_modified_t")) is int:
        try:
            source["source_updated_at"] = _date(
                datetime.fromtimestamp(product["last_modified_t"], UTC).isoformat()
            )
        except (OSError, OverflowError) as error:
            raise ValueError("OFF modification date is invalid") from error
    tables = []
    untrusted_numbers = False
    nutrition = product.get("nutrition")
    if isinstance(nutrition, dict):
        raw_tables = nutrition.get("input_sets", [])
        if not isinstance(raw_tables, list) or len(raw_tables) > 16:
            raise ValueError("OFF nutrition input set bounds exceeded")
        selected_tables = []
        for table in raw_tables:
            if not isinstance(table, dict):
                raise ValueError("OFF direct table is invalid")  # noqa: TRY004
            selected = {
                key: table[key]
                for key in (
                    "source",
                    "preparation",
                    "per",
                    "per_quantity",
                    "per_unit",
                    "source_nutrient_count",
                    "invalid_source_nutrient_count",
                )
                if key in table
            }
            values = table.get("nutrients")
            if not isinstance(values, dict) or len(values) > 200:
                raise ValueError("OFF nutrient bounds exceeded")
            selected["nutrients"] = {}
            rows = []
            for key, item in values.items():
                if key not in OFF_NUTRIENTS or not isinstance(item, dict):
                    continue
                public = {
                    field: item[field] for field in ("value", "unit", "modifier") if field in item
                }
                selected["nutrients"][key] = public
                if "value" in item and table.get("source") in {
                    "packaging",
                    "manufacturer",
                }:
                    qualifier = (
                        "exact"
                        if item.get("modifier") is None and type(item["value"]) in {int, float}
                        else "unknown"
                    )
                    untrusted_numbers |= qualifier == "unknown"
                    rows.append(
                        {
                            "nutrient": OFF_NUTRIENTS[key],
                            "value": item["value"] if qualifier == "exact" else None,
                            "unit": item.get("unit"),
                            "qualifier": qualifier,
                            "raw_label": key,
                        }
                    )
            selected_tables.append(selected)
            if rows:
                per = table.get("per")
                amount, unit = (
                    table.get("per_quantity"),
                    table.get("per_unit"),
                )
                if type(amount) not in {int, float}:
                    untrusted_numbers |= amount is not None
                    amount = None
                if per not in {"100g", "100ml", "serving"} or (
                    per in {"100g", "100ml"}
                    and (amount != 100 or unit != ("g" if per == "100g" else "ml"))
                ):
                    continue
                tables.append(
                    {
                        "source": table["source"],
                        "basis": {
                            "amount": amount,
                            "unit": "mL" if unit == "ml" else unit,
                            "kind": "serving" if per == "serving" else "quantity",
                        },
                        "preparation": "as_sold"
                        if table.get("preparation") == "as_sold"
                        else "as_prepared"
                        if table.get("preparation") == "prepared"
                        else "unknown",
                        "rows": rows,
                    }
                )
        projection["nutrition"] = {"input_sets": selected_tables}
    legacy = product.get("nutriments")
    if legacy is not None:
        if not isinstance(legacy, dict) or len(legacy) > 200:
            raise ValueError("OFF legacy aggregate bounds exceeded")
        legacy = {
            key: _metadata(value)
            for key, value in legacy.items()
            if re.fullmatch(r"[a-z][a-z0-9_-]{0,127}", key)
        }
        projection["nutriments"] = legacy
    ingredients = product.get("ingredients_text")
    market = "india" if "en:india" in countries else "unknown"
    identity = {
        "barcode": product.get("code"),
        "name": product.get("product_name"),
        "brand": product.get("brands"),
        "variant": None,
        "quantity": product.get("quantity"),
        "market": market,
        "barcode_evidence_url": source["url"],
    }
    for key in ("name", "brand", "quantity"):
        if identity[key] == "":
            identity[key] = None
    identity["match"] = (
        "exact_sku"
        if market == "india"
        and all(identity[key] is not None for key in ("barcode", "name", "brand", "quantity"))
        and re.search(
            r"\d+(?:[.,]\d+)?\s*(?:g|kg|ml|cl|l|oz)\b",
            identity["quantity"],
            re.IGNORECASE,
        )
        else "identity_unconfirmed"
    )
    return _normalise(
        {
            "source": source,
            "identity": identity,
            "sections": {"ingredients": {"text": ingredients, "completeness": "unknown"}}
            if ingredients
            else {},
            "nutrition": {
                "direct_tables": tables,
                "legacy_aggregates": legacy,
                "legacy_present": legacy is not None
                or product.get("nutrition_legacy_present") is True,
            },
            "raw_projection": projection,
            "metadata": {
                "unknowns": [
                    "Numeric strings or modified values in a maintenance checkpoint are not trusted exact nutrient declarations. Original projection is retained; affected values or table bases remain unavailable until independently verified."
                ]
            }
            if untrusted_numbers
            else {},
        }
    )


def _records(data, kind):
    if kind == "off" and not data.lstrip().startswith((b"[", b'{"observations"')):
        try:
            document = _json(data)
        except json.JSONDecodeError:
            document = [_json(line) for line in data.splitlines() if line.strip()]
    else:
        document = _json(data)
    if isinstance(document, dict) and "observations" in document:
        _keys(
            document,
            {
                "observations",
                "schema_version",
                "acquired_at",
                "purpose",
                "notes",
                "scope",
                "coverage",
                "limitations",
                "rejected_sources",
                "retrieval_failures",
                "methodology",
                "failures",
                "attempted",
                "targets_count",
            },
            "input document",
        )
        if "acquired_at" in document:
            _date(document["acquired_at"])
        document = document["observations"]
    elif isinstance(document, dict):
        document = [document]
    if not isinstance(document, list) or not 1 <= len(document) <= MAX_OBSERVATIONS:
        raise ValueError("Research input observation count is invalid")
    return document


def _fold(value):
    return " ".join(unicodedata.normalize("NFKC", value).casefold().split())


def _groups(observations):
    by_barcode = {}
    for observation in observations:
        code = observation["identity"]["barcode"]
        if code is not None:
            by_barcode.setdefault(code, []).append(observation)
    groups = {}
    for code, entries in sorted(by_barcode.items()):
        conflicts = []
        for field in ("name", "brand", "variant", "quantity"):
            if (
                len({_fold(item["identity"][field]) for item in entries if item["identity"][field]})
                > 1
            ):
                conflicts.append("identity." + field)
        for field in ("ingredients", "contains", "may_contain"):
            if (
                len(
                    {
                        _fold(item["sections"][field]["text"])
                        for item in entries
                        if item["sections"][field] is not None
                    }
                )
                > 1
            ):
                conflicts.append(field)
        nutrition = {}
        for item in entries:
            for table in item["nutrition"]["direct_tables"]:
                context = (_canonical(table["basis"]), table["preparation"])
                for row in table["rows"]:
                    if row["value"] is not None:
                        key = (*context, row["nutrient"], row["unit"], row["qualifier"])
                        nutrition.setdefault(key, set()).add(row["value"])
        if any(len(values) > 1 for values in nutrition.values()):
            conflicts.append("nutrition")
        groups[code] = {
            "observation_ids": sorted(item["observation_id"] for item in entries),
            "eligibility": "conflicting"
            if conflicts
            else "exact_sku"
            if all(item["eligibility"] == "exact_sku" for item in entries)
            else "identity_unconfirmed",
            "conflict_fields": conflicts,
        }
    return groups


def _manifest(observations, inputs, compressed, decoded):
    providers, eligibility = {}, {}
    for item in observations:
        provider = item["source"]["provider"]
        providers[provider] = providers.get(provider, 0) + 1
        eligibility[item["eligibility"]] = eligibility.get(item["eligibility"], 0) + 1
    return {
        "schema_version": SCHEMA,
        "dataset_file": DATA_FILE,
        "runtime_promotion": "none",
        "coverage": "unverified_targeted_popular_products",
        "observation_count": len(observations),
        "compressed_sha256": _digest(compressed),
        "compressed_bytes": len(compressed),
        "decoded_sha256": _digest(decoded),
        "decoded_bytes": len(decoded),
        "provider_counts": providers,
        "identity_eligibility_counts": eligibility,
        "ingredients_available": sum(
            item["sections"]["ingredients"] is not None for item in observations
        ),
        "direct_nutrition_observations": sum(
            bool(item["nutrition"]["direct_tables"]) for item in observations
        ),
        "packaging_or_manufacturer_nutrition_observations": sum(
            any(
                table["source"] in {"packaging", "manufacturer"}
                for table in item["nutrition"]["direct_tables"]
            )
            for item in observations
        ),
        "retailer_nutrition_observations": sum(
            any(
                table["source"] == "retailer_transcription"
                for table in item["nutrition"]["direct_tables"]
            )
            for item in observations
        ),
        "legacy_only_observations": sum(
            item["nutrition"]["availability"] == "legacy_aggregate_only" for item in observations
        ),
        "barcode_groups": _groups(observations),
        "input_artifacts": inputs,
    }


def _candidate_ids(observations):
    identifiers = {}
    for item in observations:
        candidate_id = item["metadata"].get("candidate_id")
        if candidate_id is not None:
            candidate_id = _text(candidate_id, 256)
            previous = identifiers.setdefault(candidate_id, item["observation_id"])
            if previous != item["observation_id"]:
                raise ValueError(
                    "A research candidate ID cannot identify contradictory observations"
                )


def verify_dataset(directory):
    """Verify byte hashes, semantic bounds, immutable observations and conflict counts."""
    directory = _path(directory)
    manifest = _json(_read(directory / MANIFEST_FILE, MAX_MANIFEST_BYTES))
    if not isinstance(manifest, dict) or manifest.get("dataset_file") != DATA_FILE:
        raise ValueError("Research manifest cannot select another dataset file")
    compressed = _read(directory / DATA_FILE, MAX_DATASET_BYTES)
    if (len(compressed), _digest(compressed)) != (
        manifest.get("compressed_bytes"),
        manifest.get("compressed_sha256"),
    ):
        raise ValueError("Compressed research dataset differs from its manifest")
    try:
        with gzip.GzipFile(fileobj=io.BytesIO(compressed)) as stream:
            decoded = stream.read(MAX_DATASET_BYTES + 1)
            if len(decoded) > MAX_DATASET_BYTES or stream.read(1):
                raise ValueError("Decoded research dataset exceeds byte bounds")
    except (OSError, EOFError) as error:
        raise ValueError("Research dataset gzip is invalid or incomplete") from error
    observations = []
    for line in decoded.splitlines():
        if not line or len(line) > MAX_RECORD_BYTES or len(observations) >= MAX_OBSERVATIONS:
            raise ValueError("Research dataset record/count bounds exceeded")
        raw = _json(line)
        observation = _normalise(raw)
        if _canonical(observation) != line:
            raise ValueError("Research observation must retain its canonical immutable bytes")
        observations.append(observation)
    if not observations or decoded != b"".join(_canonical(item) + b"\n" for item in observations):
        raise ValueError("Research dataset must retain complete canonical records")
    if [item["observation_id"] for item in observations] != sorted(
        {item["observation_id"] for item in observations}
    ):
        raise ValueError("Research observations must be distinct and deterministically ordered")
    _candidate_ids(observations)
    inputs = manifest.get("input_artifacts")
    if not isinstance(inputs, list) or not 1 <= len(inputs) <= MAX_INPUT_FILES:
        raise ValueError("Research manifest input artifact bounds exceeded")
    for item in inputs:
        _keys(item, {"file", "kind", "sha256", "bytes"}, "input artifact")
        if (
            not isinstance(item.get("file"), str)
            or Path(item["file"]).name != item["file"]
            or item.get("kind") not in {"web", "off"}
            or not isinstance(item.get("sha256"), str)
            or HASH.fullmatch(item["sha256"]) is None
            or type(item.get("bytes")) is not int
            or not 0 < item["bytes"] <= MAX_INPUT_BYTES
        ):
            raise ValueError("Research input provenance is invalid")
    expected = _manifest(observations, inputs, compressed, decoded)
    if manifest != expected:
        raise ValueError("Research manifest differs from verified facts/counts/conflicts")
    return manifest


def build_dataset(web_inputs, off_inputs, output_directory):
    """Build from explicit public local inputs; never acquire or replace the bulk OFF source."""
    paths = [(Path(path), "web") for path in web_inputs] + [
        (Path(path), "off") for path in off_inputs
    ]
    if not 1 <= len(paths) <= MAX_INPUT_FILES or len({path.name for path, _ in paths}) != len(
        paths
    ):
        raise ValueError("Research inputs require distinct bounded artifact names")
    inputs, observations = [], {}
    decoded_size = 0
    for path, kind in sorted(paths, key=lambda item: item[0].name):
        data = _read(path, MAX_INPUT_BYTES)
        inputs.append(
            {
                "file": path.name,
                "kind": kind,
                "sha256": _digest(data),
                "bytes": len(data),
            }
        )
        for raw in _records(data, kind):
            item = _off(raw) if kind == "off" else _normalise(raw)
            if item["observation_id"] not in observations:
                decoded_size += len(_canonical(item)) + 1
                if decoded_size > MAX_DATASET_BYTES:
                    raise ValueError("Research decoded work exceeds its byte budget")
            observations[item["observation_id"]] = item
            if len(observations) > MAX_OBSERVATIONS:
                raise ValueError("Research observation count bounds exceeded")
    observations = [observations[key] for key in sorted(observations)]
    _candidate_ids(observations)
    decoded = b"".join(_canonical(item) + b"\n" for item in observations)
    if not 0 < len(decoded) <= MAX_DATASET_BYTES:
        raise ValueError("Research decoded dataset exceeds byte bounds")
    compressed = gzip.compress(decoded, compresslevel=9, mtime=0)
    manifest = _manifest(observations, inputs, compressed, decoded)
    if len(_canonical(manifest)) > MAX_MANIFEST_BYTES:
        raise ValueError("Research manifest exceeds byte bounds")
    output = _path(output_directory)
    # Never publish into the existing bulk source directory, even on an explicit override.
    if any(
        (output / filename).exists()
        for filename in ("india-products.jsonl.gz", "bundle.json", "acquisition.json")
    ):
        raise ValueError(
            "Research supplement must not overwrite or share the bulk acquisition directory"
        )
    output.mkdir(parents=True, exist_ok=True)
    destinations = [output / DATA_FILE, output / MANIFEST_FILE]
    if any(path.exists() for path in destinations):
        if all(path.exists() for path in destinations) and verify_dataset(output) == manifest:
            return manifest
        raise ValueError("Existing acquired research is preserved; use a new output directory")
    lock = output / ".popular-dataset.lock"
    descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    identity = os.fstat(descriptor)
    os.close(descriptor)
    try:
        with tempfile.TemporaryDirectory(prefix=".popular-dataset-", dir=output) as name:
            staging = Path(name)
            (staging / DATA_FILE).write_bytes(compressed)
            (staging / MANIFEST_FILE).write_bytes(_canonical(manifest) + b"\n")
            verify_dataset(staging)
            for (path, _), artifact in zip(
                sorted(paths, key=lambda item: item[0].name), inputs, strict=True
            ):
                if _digest(_read(path, MAX_INPUT_BYTES)) != artifact["sha256"]:
                    raise ValueError("Research input changed during build")
            if any(path.exists() for path in destinations):
                raise ValueError("Research output changed during build")
            for path in destinations:
                _path(path)
                os.replace(staging / path.name, path)
    finally:
        if lock.exists():
            current = lock.lstat()
            if (current.st_dev, current.st_ino) == (
                identity.st_dev,
                identity.st_ino,
            ) and not lock.is_symlink():
                lock.unlink()
    return verify_dataset(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--web-input",
        action="append",
        type=Path,
        default=[],
        help="Normalized public candidate JSON",
    )
    parser.add_argument(
        "--off-input",
        action="append",
        type=Path,
        default=[],
        help="Exact OFF source/product JSON or JSONL wrappers",
    )
    parser.add_argument("--output-dir", type=Path, default=ROOT / "data/catalogue/popular-india-v1")
    parser.add_argument(
        "--verify", type=Path, help="Verify an existing supplement without modifying it"
    )
    args = parser.parse_args()
    try:
        if args.verify is not None:
            if args.web_input or args.off_input:
                raise ValueError("Verification cannot acquire or rebuild inputs")
            manifest = verify_dataset(args.verify)
        else:
            manifest = build_dataset(args.web_input, args.off_input, args.output_dir)
    except (ValueError, OSError, TypeError, KeyError, json.JSONDecodeError):
        parser.exit(
            1,
            "Popular research dataset failed validation; no runtime data was promoted.\n",
        )
    print(
        json.dumps(
            {
                "schema_version": manifest["schema_version"],
                "observation_count": manifest["observation_count"],
                "decoded_sha256": manifest["decoded_sha256"],
                "runtime_promotion": "none",
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
