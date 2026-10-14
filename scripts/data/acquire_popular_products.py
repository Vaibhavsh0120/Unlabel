"""Acquire bounded exact OFF barcode observations for a researched supplement.

This explicit maintenance command performs no writes to the active bulk catalogue,
cloud database or provider. Returned public facts retain their own source/date.
"""

import argparse
import json
import os
import re
import tempfile
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from urllib.parse import urlencode

import httpx
from acquire_india_jsonl import (
    IDENTITY_FIELDS,
    NumberToken,
    _constant,
    _object,
    _selected,
    project_record,
)

ORIGIN = "https://world.openfoodfacts.org"
BARCODE = re.compile(r"(?:[0-9]{8}|[0-9]{12,14})\Z")
MAX_RESPONSE_BYTES = 2 * 1024 * 1024
MAX_TARGET_BYTES = 2 * 1024 * 1024
MAX_OUTPUT_BYTES = 16 * 1024 * 1024
FIELDS = ",".join((*IDENTITY_FIELDS, "nutrition", "nutriments", "images"))
USER_AGENT = "Unlabel - dataset-maintenance - 0.10.0 - https://github.com/Vaibhavsh0120/Unlabel - read-only"


def strict_json(data):
    return json.loads(
        data,
        parse_float=NumberToken,
        parse_constant=_constant,
        object_pairs_hook=_object,
    )


def load_targets(path, limit):
    if path.stat().st_size > MAX_TARGET_BYTES:
        raise ValueError("Target file exceeds budget")
    raw = strict_json(path.read_bytes())
    targets = raw.get("targets") if isinstance(raw, dict) else None
    if not isinstance(targets, list) or len(targets) > 2000:
        raise ValueError("Expected at most 2000 explicit targets")
    seen = set()
    result = []
    for target in targets:
        if not isinstance(target, dict):
            raise ValueError("Target must be an object")  # noqa: TRY004 - malformed source data
        code = target.get("code")
        if not isinstance(code, str) or not BARCODE.fullmatch(code):
            raise ValueError("Target barcode is invalid")
        if code in seen:
            raise ValueError("Duplicate target barcode")
        seen.add(code)
        result.append(target)
    return result[:limit]


def fetch_product(client, code):
    """One exact source call; redirects, unrelated identities and oversized data fail closed."""
    if not BARCODE.fullmatch(code):
        raise ValueError("Invalid barcode")
    url = f"{ORIGIN}/api/v3.6/product/{code}.json?{urlencode({'fields': FIELDS})}"
    with client.stream("GET", url) as response:
        if response.status_code != 200:
            return None, {
                "code": code,
                "reason": "http_status",
                "status": response.status_code,
            }
        declared = response.headers.get("content-length")
        if declared and (not declared.isdigit() or int(declared) > MAX_RESPONSE_BYTES):
            raise ValueError("Declared response exceeds budget")
        data = bytearray()
        for chunk in response.iter_bytes(chunk_size=64 * 1024):
            data.extend(chunk)
            if len(data) > MAX_RESPONSE_BYTES:
                raise ValueError("Response exceeds budget")
    raw = strict_json(data)
    product = raw.get("product") if isinstance(raw, dict) else None
    if not isinstance(product, dict):
        return None, {"code": code, "reason": "not_found"}
    if product.get("code") != code:
        raise ValueError("Source barcode differs from requested exact identity")
    countries = product.get("countries_tags")
    if not isinstance(countries, list) or "en:india" not in countries:
        return None, {"code": code, "reason": "india_market_unconfirmed"}
    now = datetime.now(UTC)
    modified = product.get("last_modified_t")
    updated = None
    if type(modified) is int and 0 <= modified <= now.timestamp():
        updated = datetime.fromtimestamp(modified, UTC).isoformat()
    return {
        "source": {
            "provider": "open_food_facts",
            "url": url,
            "retrieved_at": now.isoformat(),
            "source_updated_at": updated,
            "license": {
                "database": "ODbL-1.0",
                "contents": "DbCL-1.0",
                "images": "CC-BY-SA-3.0",
                "reuse_status": "licensed",
            },
        },
        "product": project_record(product),
    }, None


def write_atomic(path, payload):
    """Publish only a complete bounded public source file, retaining existing outputs on error."""
    data = (
        json.dumps(
            payload, ensure_ascii=False, sort_keys=True, allow_nan=False, indent=2
        )
        + "\n"
    ).encode()
    if len(data) > MAX_OUTPUT_BYTES:
        raise ValueError("Acquired output exceeds budget")
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_symlink():
        raise ValueError("Symlink output refused")
    descriptor, temporary = tempfile.mkstemp(
        prefix=".off-acquisition-", suffix=".tmp", dir=path.parent
    )
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def load_resume(path, targets):
    if path.stat().st_size > MAX_OUTPUT_BYTES:
        raise ValueError("Resume output exceeds budget")
    previous = _selected(strict_json(path.read_bytes()))
    rows = previous.get("observations") if isinstance(previous, dict) else None
    if not isinstance(rows, list) or len(rows) > 2000:
        raise ValueError("Resume observations are invalid")
    allowed_codes = {target["code"] for target in targets}
    seen, result = set(), []
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get("product"), dict):
            raise ValueError("Resume product is invalid")  # noqa: TRY004 - malformed source data
        raw = row["product"]
        code = raw.get("code")
        if (
            code not in allowed_codes
            or code in seen
            or "en:india" not in raw.get("countries_tags", [])
        ):
            raise ValueError("Resume identities do not match explicit India targets")
        seen.add(code)
        source = row.get("source")
        expected_url = (
            f"{ORIGIN}/api/v3.6/product/{code}.json?{urlencode({'fields': FIELDS})}"
        )
        if (
            not isinstance(source, dict)
            or source.get("provider") != "open_food_facts"
            or source.get("url") != expected_url
        ):
            raise ValueError("Resume source identity differs")
        dates = {}
        for key in ("retrieved_at", "source_updated_at"):
            value = source.get(key)
            if value is None and key == "source_updated_at":
                dates[key] = None
                continue
            if not isinstance(value, str) or len(value) > 64:
                raise ValueError("Resume source date is invalid")
            date = datetime.fromisoformat(value)
            if date.utcoffset() is None or date > datetime.now(UTC):
                raise ValueError("Resume source date is invalid")
            dates[key] = value
        projected_value = project_record(raw)
        if not isinstance(projected_value, dict):
            raise TypeError("Resume product projection is invalid")
        projected: dict[str, Any] = dict(projected_value)
        projected["nutrition_legacy_present"] = (
            raw.get("nutrition_legacy_present") is True
            or projected["nutrition_legacy_present"]
        )
        result.append(
            {
                "source": {
                    "provider": "open_food_facts",
                    "url": expected_url,
                    **dates,
                    "license": {
                        "database": "ODbL-1.0",
                        "contents": "DbCL-1.0",
                        "images": "CC-BY-SA-3.0",
                        "reuse_status": "licensed",
                    },
                },
                "product": projected,
            }
        )
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--targets", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--limit", type=int, default=800)
    parser.add_argument("--delay", type=float, default=2.5)
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Retain acquired exact codes; retry unresolved targets",
    )
    args = parser.parse_args()
    if not 1 <= args.limit <= 2000 or not 2.5 <= args.delay <= 10:
        parser.error("Limit must be 1..2000 and delay 2.5..10 seconds")
    started = time.monotonic()
    observations, failures = [], []
    all_targets = load_targets(args.targets, args.limit)
    if args.resume and args.output.exists():
        observations = load_resume(args.output, all_targets)
        codes = [r["product"]["code"] for r in observations]
        targets = [t for t in all_targets if t["code"] not in set(codes)]
    else:
        targets = all_targets
    with httpx.Client(
        timeout=httpx.Timeout(25, connect=10),
        headers={"User-Agent": USER_AGENT},
        follow_redirects=False,
        trust_env=False,
    ) as client:
        for target_index, target in enumerate(targets):
            if time.monotonic() - started > 1800:
                failures.extend(
                    {"code": t["code"], "reason": "acquisition_deadline"}
                    for t in targets[target_index:]
                )
                break
            result, failure = None, None
            for attempt in range(2):
                try:
                    result, failure = fetch_product(client, target["code"])
                except (
                    httpx.HTTPError,
                    ValueError,
                    TypeError,
                    OverflowError,
                    RecursionError,
                ):
                    failure = {
                        "code": target["code"],
                        "reason": "unavailable_or_invalid_source",
                    }
                if failure and failure.get("status") == 429:
                    break
                if result is not None or (
                    failure
                    and failure.get("status") not in {429, 500, 502, 503, 504}
                    and failure["reason"] != "unavailable_or_invalid_source"
                ):
                    break
                if attempt == 0:
                    time.sleep(args.delay)
            if result is not None:
                result["research_category"] = target.get("category")
            if result is not None:
                observations.append(result)
            else:
                failures.append(
                    failure
                    or {
                        "code": target["code"],
                        "reason": "unavailable_or_invalid_source",
                    }
                )
            completed = len(observations) + len(failures)
            write_atomic(
                args.output,
                {
                    "observations": observations,
                    "failures": failures,
                    "attempted": completed,
                    "targets_count": len(all_targets),
                    "scope": "read-only exact OFF API observations; not a bulk refresh or runtime promotion",
                },
            )
            if (
                completed % 20 == 0
                or completed == len(all_targets)
                or (failure and failure.get("status") == 429)
            ):
                print(
                    json.dumps(
                        {
                            "attempted": completed,
                            "acquired": len(observations),
                            "failed": len(failures),
                            "elapsed_seconds": round(time.monotonic() - started),
                        }
                    ),
                    flush=True,
                )
            if failure and failure.get("status") == 429:
                failures.extend(
                    {"code": t["code"], "reason": "not_attempted_after_rate_limit"}
                    for t in targets[target_index + 1 :]
                )
                break
            # At most 24 nominal requests/minute; 429 stops this run immediately.
            time.sleep(args.delay)
    write_atomic(
        args.output,
        {
            "observations": observations,
            "failures": failures,
            "attempted": len(observations)
            + sum(
                r["reason"]
                not in {"not_attempted_after_rate_limit", "acquisition_deadline"}
                for r in failures
            ),
            "targets_count": len(all_targets),
            "scope": "read-only exact OFF API observations; not a bulk refresh or runtime promotion",
        },
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
