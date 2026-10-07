"""Stream the official OFF JSONL export into a bounded India source projection.

The global gzip is never retained. Publication requires complete compressed bytes,
gzip CRC/EOF, valid bounded JSON objects, and an India projection within budget.
"""

import argparse
import gzip
import hashlib
import io
import json
import math
import os
import re
import shutil
import tempfile
import time
import urllib.request
import uuid
from collections import Counter
from datetime import UTC, datetime
from decimal import Decimal, DecimalException
from email.utils import parsedate_to_datetime
from pathlib import Path
from typing import Protocol
from urllib.parse import urlsplit

SOURCE = "https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz"
REDIRECT = "https://openfoodfacts-ds.s3.eu-west-3.amazonaws.com/openfoodfacts-products.jsonl.gz"
MAX_COMPRESSED_BYTES = 16 * 1024**3
MAX_DECODED_BYTES = 160 * 1024**3
MAX_RECORD_BYTES = 16 * 1024**2
MAX_PROJECTED_RECORD_BYTES = 512 * 1024
MAX_PROJECTION_BYTES = 100 * 1024**2
MAX_SECONDS = 3 * 3600
BARCODE = re.compile(r"(?:[0-9]{8}|[0-9]{12,14})\Z")
IDENTITY_FIELDS = (
    "code",
    "countries_tags",
    "product_name",
    "brands",
    "quantity",
    "ingredients_text",
    "allergens_tags",
    "traces_tags",
    "nutriscore_grade",
    "nova_group",
    "schema_version",
    "last_modified_t",
    "lc",
    "categories_tags",
    "labels_tags",
)
TABLE_FIELDS = ("source", "preparation", "per", "per_quantity", "per_unit")
NUTRIENTS = (
    "energy-kcal",
    "energy-kj",
    "fat",
    "saturated-fat",
    "carbohydrates",
    "carbohydrates-total",
    "sugars",
    "added-sugars",
    "fiber",
    "proteins",
    "sodium",
    "salt",
)


class NumberToken(str):
    """Preserve source decimal precision until the selected fields are projected."""


def _constant(token):
    raise ValueError("Nonfinite JSON constant in source")


def _object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON object key in source")
        result[key] = value
    return result


def _selected(value):
    if isinstance(value, NumberToken):
        try:
            number = float(value)
            faithful = (
                len(value) <= 64
                and math.isfinite(number)
                and Decimal(value) == Decimal(str(number))
            )
        except (ValueError, DecimalException):
            faithful = False
        # Keep rejected numeric input visibly invalid for the downstream adapter;
        # never round a long decimal into an apparently exact declaration.
        return number if faithful else {"invalid_number": str(value)}
    if isinstance(value, list):
        return [_selected(item) for item in value]
    if isinstance(value, dict):
        return {key: _selected(item) for key, item in value.items()}
    return value


def _nutrition(value):
    if not isinstance(value, dict):
        return value
    if "input_sets" not in value:
        return {}
    tables = value["input_sets"]
    if not isinstance(tables, list):
        return {"input_sets": tables}
    projected = []
    for table in tables:
        if not isinstance(table, dict):
            projected.append(table)
            continue
        result = {key: table[key] for key in TABLE_FIELDS if key in table}
        values = table.get("nutrients")
        if not isinstance(values, dict):
            result["nutrients"] = values
        elif len(values) > 200:
            # Preserve invalid container shape; selecting 12 keys must not turn an
            # over-budget source table into a supported direct declaration.
            result["nutrients"] = {"invalid_source_nutrient_count": len(values)}
            result["source_nutrient_count"] = len(values)
        else:
            result["nutrients"] = {
                key: (
                    {
                        field: values[key][field]
                        for field in ("value", "unit", "modifier")
                        if field in values[key]
                    }
                    if isinstance(values[key], dict)
                    else values[key]
                )
                for key in NUTRIENTS
                if key in values
            }
        projected.append(result)
    return {"input_sets": projected}


def _descriptor(value):
    if not isinstance(value, dict):
        return value
    result = {"rev": value["rev"]} if "rev" in value else {}
    if "sizes" in value:
        sizes = value["sizes"]
        if not isinstance(sizes, dict):
            result["sizes"] = sizes
        elif "400" in sizes:
            size = sizes["400"]
            result["sizes"] = {
                "400": (
                    {key: size[key] for key in ("w", "h") if key in size}
                    if isinstance(size, dict)
                    else size
                )
            }
    return result


def _images(value, lc):
    if not isinstance(value, dict):
        return value
    languages = {"en", "hi"}
    if isinstance(lc, str) and re.fullmatch(r"[a-z]{2,3}", lc):
        languages.add(lc)
    result = {}
    if "selected" in value:
        selected = value["selected"]
        if not isinstance(selected, dict):
            result["selected"] = selected
        elif "front" in selected:
            front = selected["front"]
            result["selected"] = {
                "front": (
                    {
                        lang: _descriptor(front[lang])
                        for lang in sorted(languages)
                        if lang in front
                    }
                    if isinstance(front, dict)
                    else front
                )
            }
    for lang in sorted(languages):
        key = f"front_{lang}"
        if key in value:
            result[key] = _descriptor(value[key])
    return result


def selected_front_present(images):
    """Measure projected descriptor availability, independently of image safety."""
    if not isinstance(images, dict):
        return False
    selected = images.get("selected")
    front = selected.get("front") if isinstance(selected, dict) else None
    descriptors = list(front.values()) if isinstance(front, dict) else []
    descriptors.extend(
        value for key, value in images.items() if key.startswith("front_")
    )
    return any(
        isinstance(value, dict) and value.get("rev") is not None
        for value in descriptors
    )


def project_record(raw):
    result = {key: raw[key] for key in IDENTITY_FIELDS if key in raw}
    if "nutrition" in raw:
        result["nutrition"] = _nutrition(raw["nutrition"])
    result["nutrition_legacy_present"] = "nutriments" in raw or "nutrition_data" in raw
    if "images" in raw:
        result["images"] = _images(raw["images"], raw.get("lc"))
    return _selected(result)


class BinaryReader(Protocol):
    def read(self, size: int = -1, /) -> bytes: ...


class MeteredReader:
    def __init__(
        self,
        stream: BinaryReader,
        *,
        max_bytes: int = MAX_COMPRESSED_BYTES,
        progress: bool = False,
    ) -> None:
        self.stream = stream
        self.max_bytes = max_bytes
        self.bytes_read = 0
        self.digest = hashlib.sha256()
        self.started = self.last_report = time.monotonic()
        self.last_report_bytes = 0
        self.progress = progress

    def read(self, size: int = -1) -> bytes:
        if not 0 <= size <= 1024**2:
            raise ValueError("Unbounded compressed read refused")
        if time.monotonic() - self.started > MAX_SECONDS:
            raise ValueError("Acquisition exceeded three-hour deadline")
        data = self.stream.read(size)
        self.bytes_read += len(data)
        if self.bytes_read > self.max_bytes:
            raise ValueError("Compressed export exceeds transfer budget")
        self.digest.update(data)
        now = time.monotonic()
        if self.progress and (
            now - self.last_report >= 20
            or self.bytes_read - self.last_report_bytes >= 50 * 1024**2
        ):
            print(
                json.dumps(
                    {
                        "compressed_bytes_read": self.bytes_read,
                        "elapsed_seconds": round(now - self.started),
                    }
                ),
                flush=True,
            )
            self.last_report = now
            self.last_report_bytes = self.bytes_read
        return data

    def seek(self, offset: int, whence: int = 0) -> int:
        # Rewinding would invalidate the acquisition byte count and digest.
        raise io.UnsupportedOperation("Compressed acquisition stream cannot seek")


def project_jsonl(source, target):
    counts = Counter()
    schemas_global = Counter()
    schemas_india = Counter()
    seen = set()
    while True:
        line = source.readline(MAX_RECORD_BYTES + 1)
        if not line:
            break
        counts["decoded_bytes"] += len(line)
        if len(line) > MAX_RECORD_BYTES or counts["decoded_bytes"] > MAX_DECODED_BYTES:
            raise ValueError("JSONL record or decoded export exceeds budget")
        try:
            raw = json.loads(
                line,
                parse_float=NumberToken,
                parse_constant=_constant,
                object_pairs_hook=_object,
            )
        except (UnicodeError, json.JSONDecodeError, RecursionError) as error:
            raise ValueError("Malformed JSONL record") from error
        if not isinstance(raw, dict):
            raise ValueError("JSONL record must be an object")  # noqa: TRY004 - acquisition errors use one fail-closed exception type.
        counts["rows_read"] += 1
        version = raw.get("schema_version")
        schema = (
            str(version)
            if type(version) is int and 0 <= version <= 100000
            else ("missing" if version is None else "invalid")
        )
        schemas_global[schema] += 1
        countries = raw.get("countries_tags")
        if countries is None:
            counts["global_missing_countries_tags"] += 1
            continue
        if not isinstance(countries, list) or any(
            not isinstance(tag, str) or isinstance(tag, NumberToken)
            for tag in countries
        ):
            raise ValueError("Malformed canonical countries_tags")
        if "en:india" not in countries:
            continue
        counts["india_rows"] += 1
        schemas_india[schema] += 1
        code = raw.get("code")
        if (
            not isinstance(code, str)
            or isinstance(code, NumberToken)
            or BARCODE.fullmatch(code) is None
        ):
            counts["unsupported_barcodes"] += 1
        else:
            if code in seen:
                counts["duplicate_barcodes"] += 1
                raise ValueError(
                    "Duplicate supported India barcode; source requires review"
                )
            seen.add(code)
            counts["supported_unique_barcodes"] += 1
        for field, key in (
            ("product_name", "missing_name"),
            ("ingredients_text", "missing_ingredients"),
            ("allergens_tags", "missing_allergens_tags"),
            ("last_modified_t", "missing_last_modified_t"),
        ):
            if raw.get(field) is None or raw.get(field) == "":
                counts[key] += 1
        nutrition = raw.get("nutrition")
        tables = nutrition.get("input_sets") if isinstance(nutrition, dict) else None
        if not isinstance(tables, list) or not tables:
            counts["missing_direct_nutrition_input_sets"] += 1
        if "nutriments" in raw or "nutrition_data" in raw:
            counts["legacy_nutrition_present_rows"] += 1
        images = _images(raw.get("images"), raw.get("lc"))
        if not selected_front_present(images):
            counts["missing_selected_front_images"] += 1
        payload = (
            json.dumps(
                project_record(raw),
                ensure_ascii=True,
                separators=(",", ":"),
                allow_nan=False,
            )
            + "\n"
        ).encode("utf-8")
        if len(payload) > MAX_PROJECTED_RECORD_BYTES:
            raise ValueError("Projected India record exceeds importer row budget")
        counts["projection_bytes"] += len(payload)
        if counts["projection_bytes"] > MAX_PROJECTION_BYTES:
            raise ValueError("India projection exceeds decoded storage budget")
        target.write(payload)
    if not counts["india_rows"]:
        raise ValueError("No India records in complete source")
    required_counts = (
        "rows_read",
        "india_rows",
        "decoded_bytes",
        "projection_bytes",
        "unsupported_barcodes",
        "supported_unique_barcodes",
        "duplicate_barcodes",
        "missing_name",
        "missing_ingredients",
        "missing_allergens_tags",
        "missing_last_modified_t",
        "missing_direct_nutrition_input_sets",
        "legacy_nutrition_present_rows",
        "missing_selected_front_images",
        "global_missing_countries_tags",
    )
    return {
        **{key: counts[key] for key in required_counts},
        "schema_distribution_global": dict(sorted(schemas_global.items())),
        "schema_distribution_india": dict(sorted(schemas_india.items())),
    }


def _regular_directory(directory):
    directory = directory.absolute()
    if any(
        path.is_symlink() or path.is_junction()
        for path in (directory, *directory.parents)
    ):
        raise ValueError("Symlink or junction source directory refused")
    return directory.resolve(strict=True)


def acquire(directory):
    directory = _regular_directory(directory)
    target = directory / "india-products.jsonl.gz"
    metadata = directory / "acquisition.json"
    if target.exists() or metadata.exists():
        raise ValueError(
            "Use a new source directory; existing acquisition is preserved"
        )
    occupied = sum(
        item.stat().st_size for item in directory.iterdir() if item.is_file()
    )
    if (
        occupied + MAX_PROJECTION_BYTES > 1024**3
        or shutil.disk_usage(directory).free < MAX_PROJECTION_BYTES
    ):
        raise ValueError("Insufficient work budget or free disk")
    lock = directory / ".jsonl-acquisition.lock"
    # Windows text descriptors translate LF to CRLF and break the exact marker
    # ownership check used during cleanup. Keep the marker's bytes unchanged.
    descriptor = os.open(
        lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY | getattr(os, "O_BINARY", 0), 0o600
    )
    identity = os.fstat(descriptor)
    marker = f"pid={os.getpid()} token={uuid.uuid4().hex}\n".encode("ascii")
    try:
        written = 0
        while written < len(marker):
            count = os.write(descriptor, marker[written:])
            if not count:
                raise OSError("Could not write acquisition lock")
            written += count
    finally:
        os.close(descriptor)
    staging = metadata_staging = None
    started = datetime.now(UTC)
    try:
        request = urllib.request.Request(
            SOURCE,
            headers={
                "User-Agent": "Unlabel/0.5.0 (https://github.com/Vaibhavsh0120/Unlabel)",
                "Accept-Encoding": "identity",
            },
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            final = urlsplit(response.url)
            if (
                response.status != 200
                or response.url not in {SOURCE, REDIRECT}
                or final.username is not None
            ):
                raise ValueError(
                    "Official JSONL origin/status changed; review before acquisition"
                )
            if response.headers.get("Content-Encoding", "identity") != "identity":
                raise ValueError("Unexpected HTTP compression")
            try:
                expected = int(response.headers["Content-Length"])
                modified = parsedate_to_datetime(response.headers["Last-Modified"])
                if modified.tzinfo is None or modified.utcoffset() is None:
                    raise ValueError("Export Last-Modified must include a timezone")
                modified = modified.astimezone(UTC)
            except (KeyError, ValueError, TypeError, OverflowError) as error:
                raise ValueError(
                    "Official export is missing bounded length or source date"
                ) from error
            if not 0 < expected <= MAX_COMPRESSED_BYTES:
                raise ValueError("Official compressed source exceeds transfer budget")
            with tempfile.NamedTemporaryFile(
                dir=directory, prefix=".india-jsonl-", suffix=".part", delete=False
            ) as output:
                staging = Path(output.name)
            meter = MeteredReader(response, progress=True)
            with gzip.GzipFile(fileobj=meter) as decoded, staging.open("wb") as output:
                with gzip.GzipFile(
                    filename="", fileobj=output, mode="wb", mtime=0, compresslevel=9
                ) as projection:
                    counts = project_jsonl(decoded, projection)
                output.flush()
                os.fsync(output.fileno())
            if meter.bytes_read != expected:
                raise ValueError("Incomplete compressed transfer")
        with staging.open("rb") as stream:
            compressed_digest = hashlib.file_digest(stream, "sha256").hexdigest()
        with gzip.open(staging, "rb") as stream:
            projection_digest = hashlib.file_digest(stream, "sha256").hexdigest()
        evidence = {
            "source_format": "off_jsonl",
            "source_url": SOURCE,
            "resolved_source_url": response.url,
            "started_at": started.isoformat(),
            "completed_at": datetime.now(UTC).isoformat(),
            "source_last_modified_http": response.headers["Last-Modified"],
            "exported_at": modified.isoformat(),
            "compressed_bytes": meter.bytes_read,
            "compressed_sha256": meter.digest.hexdigest(),
            "gzip_eof_verified": True,
            "projection_sha256": projection_digest,
            "projection_compressed_bytes": staging.stat().st_size,
            "projection_compressed_sha256": compressed_digest,
            **counts,
            "scope": "all exact en:india rows in the complete dated export; not every product sold in India",
            "omitted": [
                "nutrition aggregates",
                "computed-only nutrient values",
                "other nutrients",
                "image binaries",
                "uploaded-image/user metadata",
                "image URLs",
            ],
            "database_license": "ODbL-1.0",
            "contents_license": "DbCL-1.0",
            "coverage": "unverified",
        }
        with tempfile.NamedTemporaryFile(
            dir=directory, prefix=".india-meta-", suffix=".part", delete=False
        ) as output:
            metadata_staging = Path(output.name)
            output.write((json.dumps(evidence, indent=2) + "\n").encode("utf-8"))
            output.flush()
            os.fsync(output.fileno())
        # Exclusive hard links preserve foreign files even across the final race.
        os.link(staging, target)
        try:
            os.link(metadata_staging, metadata)
        except OSError:
            if target.exists() and os.path.samefile(staging, target):
                target.unlink()
            raise
        print(json.dumps(evidence, indent=2), flush=True)
        return evidence
    finally:
        for path in (staging, metadata_staging):
            if path is not None and path.exists():
                path.unlink()
        try:
            current = lock.lstat()
            if not lock.is_symlink() and (current.st_dev, current.st_ino) == (
                identity.st_dev,
                identity.st_ino,
            ):
                with lock.open("rb") as owned:
                    content = owned.read(len(marker) + 1)
                if content == marker:
                    lock.unlink()
        except FileNotFoundError:
            pass


def main():
    parser = argparse.ArgumentParser(
        description="Stream official full OFF JSONL into a compact India-only source gzip."
    )
    parser.add_argument(
        "--directory",
        type=Path,
        required=True,
        help="Existing empty candidate directory; no world dump is retained",
    )
    args = parser.parse_args()
    try:
        acquire(args.directory)
    except (ValueError, OSError, EOFError) as error:
        parser.exit(
            1,
            f"Acquisition stopped: {type(error).__name__}: {error}. Existing catalogue is unchanged.\n",
        )


if __name__ == "__main__":
    main()
