import gzip
import hashlib
import json
import os
import re
import shutil
import sqlite3
import tempfile
import uuid
import zlib
from collections.abc import Callable
from contextlib import closing, contextmanager
from datetime import UTC, datetime
from pathlib import Path

from app.catalogue.facts import project_facts
from app.catalogue.models import (
    BARCODE_PATTERN,
    Coverage,
    Manifest,
    SourceFormat,
    validate_source_url,
)
from app.catalogue.store import (
    APPLICATION_ID,
    DATABASE_FILENAME,
    DATABASE_VERSION,
    read_only_connection,
    resolved_directory,
    verify_database,
)
from app.core.json_numbers import checked_float, reject_constant
from app.schemas.products import Product, ProviderInsights

MAX_ROW_BYTES = 512 * 1024
BATCH_SIZE = 100
PAGE_SIZE = 4096
IMPORT_LOCK_FILENAME = ".catalogue-import.lock"


@contextmanager
def _exclusive_import(directory: Path):
    """Keep one explicit lock from initial validation through atomic publication.

    Crash locks are left for operator review; a busy importer never removes them.
    Identity and a unique marker prevent cleanup of a replaced or altered lock.
    """
    path = directory / IMPORT_LOCK_FILENAME
    try:
        descriptor = os.open(
            path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_BINARY", 0), 0o600
        )
    except FileExistsError as error:
        raise ValueError(
            "Catalogue import is busy; existing lock requires operator review"
        ) from error
    stat = os.fstat(descriptor)
    identity = stat.st_dev, stat.st_ino
    marker = f"pid={os.getpid()} token={uuid.uuid4().hex}\n".encode("ascii")
    written = 0

    def owns_lock() -> bool:
        try:
            current = path.lstat()
            if (current.st_dev, current.st_ino) != identity or path.is_symlink():
                return False
            with path.open("rb") as lock:
                if lock.read(len(marker) + 1) != marker[:written]:
                    return False
            current = path.lstat()
            return (current.st_dev, current.st_ino) == identity
        except OSError:
            return False

    def ensure_owned() -> None:
        if not owns_lock():
            raise ValueError("Catalogue import lock changed; operator review is required")

    try:
        try:
            while written < len(marker):
                count = os.write(descriptor, marker[written:])
                if count == 0:
                    raise OSError("Could not write catalogue import lock")
                written += count
        finally:
            os.close(descriptor)
        yield ensure_owned
    finally:
        if owns_lock():
            path.unlink()


def _directory_bytes(directory: Path) -> int:
    """Account for all immediate files, including the input if it is in this directory."""
    return sum(path.stat().st_size for path in directory.iterdir() if path.is_file())


def _check_work_budget(directory: Path, limit: int) -> None:
    if _directory_bytes(directory) > limit:
        raise ValueError("Catalogue directory exceeds the work-size budget")


def _active_signature(path: Path) -> tuple[int, int, int, int] | None:
    if path.is_symlink():
        raise ValueError("Refusing to overwrite a symlink catalogue")
    if not path.exists():
        return None
    with read_only_connection(path) as connection:
        verify_database(connection)
    stat = path.stat()
    return stat.st_dev, stat.st_ino, stat.st_size, stat.st_mtime_ns


def _bounded_product(raw: dict, barcode: str) -> tuple[Product, list[str]]:
    # Match the current online adapter's bounds without copying its API source wrapper.
    warnings = [
        "community_record_not_package_verified",
        "allergen_safety_not_assessed",
        "snapshot_age_needs_review",
    ]

    def valid_text(value: object, limit: int) -> bool:
        return (
            isinstance(value, str)
            and len(value) <= limit
            and not any("\ud800" <= character <= "\udfff" for character in value)
        )

    def text(field: str, limit: int = 2000) -> str | None:
        value = raw.get(field)
        if value is None or value == "":
            return None
        if not valid_text(value, limit):
            warnings.append(f"{field}_invalid")
            return None
        return value.strip() or None

    def tags(field: str) -> list[str]:
        value = raw.get(field)
        if value is None:
            warnings.append(f"{field}_missing")
            return []
        if (
            not isinstance(value, list)
            or len(value) > 100
            or any(not valid_text(tag, 256) for tag in value)
        ):
            warnings.append(f"{field}_invalid")
            return []
        return value

    name = text("product_name")
    if name is None:
        warnings.append("name_missing")
    ingredients = text("ingredients_text", 16000)
    if ingredients is None:
        warnings.append("ingredients_missing")
    grade = raw.get("nutriscore_grade")
    grade = grade if isinstance(grade, str) and grade in {"a", "b", "c", "d", "e"} else None
    nova = raw.get("nova_group")
    nova = nova if type(nova) is int and 1 <= nova <= 4 else None
    product = Product(
        barcode=barcode,
        name=name,
        brands=text("brands"),
        quantity_text=text("quantity"),
        ingredients_text=ingredients,
        allergen_tags=tags("allergens_tags"),
        trace_tags=tags("traces_tags"),
        insights=ProviderInsights.model_validate({"nutri_score_grade": grade, "nova_group": nova}),
    )
    return product, warnings


def _stream_rows(source: Path, digest):
    with source.open("rb") as raw:
        compressed = raw.read(2) == b"\x1f\x8b"
        raw.seek(0)
        # GzipFile validates the trailer and raises on truncation before successful EOF.
        stream = gzip.GzipFile(fileobj=raw, mode="rb") if compressed else raw
        try:
            row_number = 0
            while True:
                line = stream.readline(MAX_ROW_BYTES + 1)
                if not line:
                    break
                row_number += 1
                if len(line) > MAX_ROW_BYTES:
                    raise ValueError(f"Source row {row_number} exceeds the decoded row-size limit")
                digest.update(line)
                try:
                    row = json.loads(
                        line.decode("utf-8"),
                        parse_float=checked_float,
                        parse_constant=reject_constant,
                    )
                except (ValueError, UnicodeError, RecursionError) as error:
                    raise ValueError(f"Source row {row_number} is invalid UTF-8 JSON") from error
                if not isinstance(row, dict):
                    raise ValueError(f"Source row {row_number} is not a JSON object")
                countries = row.get("countries_tags")
                if not isinstance(countries, list) or any(
                    not isinstance(tag, str) for tag in countries
                ):
                    raise ValueError(f"Source row {row_number} has invalid countries_tags")
                yield row
        except (gzip.BadGzipFile, EOFError, zlib.error) as error:
            raise ValueError("Compressed source is invalid or incomplete") from error
        finally:
            if compressed:
                stream.close()


def build_catalogue(
    source: Path,
    directory: Path,
    *,
    source_url: str,
    exported_at: datetime,
    coverage: Coverage = "sample",
    source_format: SourceFormat = "off_jsonl",
    max_artifact_bytes: int = 100 * 1024**2,
    max_work_bytes: int = 1024**3,
    expected_source_sha256: str | None = None,
    expected_rows_read: int | None = None,
    expected_indexed_products: int | None = None,
) -> Manifest:
    """Index an existing local plain/gzip JSONL input, publishing only after full EOF.

    The source hash is over decoded import-input bytes, including non-India rows. It
    is not the compressed upstream acquisition hash. No downloads or raw retention
    occur here. ``unverified`` coverage never claims all products sold in India.
    """
    validate_source_url(source_url)
    if not isinstance(exported_at, datetime) or exported_at.utcoffset() is None:
        raise ValueError("exported_at must include a timezone")
    if coverage not in {"sample", "unverified"} or source_format not in {
        "off_jsonl",
        "off_csv_projection",
    }:
        raise ValueError("Unsupported catalogue coverage or source format")
    if (
        type(max_artifact_bytes) is not int
        or max_artifact_bytes < PAGE_SIZE
        or type(max_work_bytes) is not int
        or max_work_bytes < PAGE_SIZE
    ):
        raise ValueError("Catalogue budgets must be positive integer byte limits")
    directory = resolved_directory(directory)
    source = Path(source).resolve(strict=True)
    if not source.is_file():
        raise ValueError("Catalogue source must be a local file")
    active = directory / DATABASE_FILENAME
    if source == active:
        raise ValueError("Catalogue source cannot be the active database")
    with _exclusive_import(directory) as ensure_lock_owned:
        return _build_locked(
            source,
            directory,
            source_url=source_url,
            exported_at=exported_at,
            coverage=coverage,
            source_format=source_format,
            max_artifact_bytes=max_artifact_bytes,
            max_work_bytes=max_work_bytes,
            ensure_lock_owned=ensure_lock_owned,
            expected_source_sha256=expected_source_sha256,
            expected_rows_read=expected_rows_read,
            expected_indexed_products=expected_indexed_products,
        )


def _build_locked(
    source: Path,
    directory: Path,
    *,
    source_url: str,
    exported_at: datetime,
    coverage: Coverage,
    source_format: SourceFormat,
    max_artifact_bytes: int,
    max_work_bytes: int,
    ensure_lock_owned: Callable[[], None],
    expected_source_sha256: str | None,
    expected_rows_read: int | None,
    expected_indexed_products: int | None,
) -> Manifest:
    active = directory / DATABASE_FILENAME
    initial_signature = _active_signature(active)
    _check_work_budget(directory, max_work_bytes)
    remaining = max_work_bytes - _directory_bytes(directory)
    if remaining < PAGE_SIZE or shutil.disk_usage(directory).free < min(
        max_artifact_bytes, remaining
    ):
        raise ValueError("Insufficient available work or disk space for catalogue import")

    descriptor, staging_name = tempfile.mkstemp(
        prefix=".catalogue-", suffix=".sqlite3", dir=directory
    )
    os.close(descriptor)
    staging = Path(staging_name)
    digest = hashlib.sha256()
    counts = {
        "rows_read": 0,
        "india_rows": 0,
        "indexed_products": 0,
        "unsupported_barcodes": 0,
        "missing_name": 0,
        "missing_ingredients": 0,
    }
    try:
        with closing(sqlite3.connect(staging)) as connection:
            # The active database is never opened for writes. No journal sidecars
            # are created for this disposable staging file.
            connection.execute(f"PRAGMA page_size = {PAGE_SIZE}")
            connection.execute("PRAGMA journal_mode = OFF")
            connection.execute("PRAGMA cache_size = -2048")
            # Cap staging allocation at the remaining whole-directory budget as
            # well as the artifact cap, so a batch cannot transiently exceed it.
            staging_limit = min(max_artifact_bytes, remaining)
            connection.execute(f"PRAGMA max_page_count = {staging_limit // PAGE_SIZE}")
            connection.execute(f"PRAGMA application_id = {APPLICATION_ID}")
            connection.execute(f"PRAGMA user_version = {DATABASE_VERSION}")
            connection.execute(
                "CREATE TABLE catalogue_products (barcode TEXT PRIMARY KEY, data TEXT NOT NULL)"
            )
            connection.execute(
                "CREATE TABLE catalogue_manifest (id INTEGER PRIMARY KEY CHECK(id = 1), "
                "data TEXT NOT NULL)"
            )
            if source_format == "off_jsonl":
                connection.execute(
                    "CREATE TABLE catalogue_facts (barcode TEXT PRIMARY KEY, data TEXT NOT NULL)"
                )
            connection.commit()
            _check_work_budget(directory, max_work_bytes)
            for row in _stream_rows(source, digest):
                counts["rows_read"] += 1
                if "en:india" not in row["countries_tags"]:
                    if counts["rows_read"] % BATCH_SIZE == 0:
                        _check_work_budget(directory, max_work_bytes)
                    continue
                counts["india_rows"] += 1
                code = row.get("code")
                if not isinstance(code, str) or re.fullmatch(BARCODE_PATTERN, code) is None:
                    counts["unsupported_barcodes"] += 1
                    if counts["rows_read"] % BATCH_SIZE == 0:
                        _check_work_budget(directory, max_work_bytes)
                    continue
                product, warnings = _bounded_product(row, code)
                data = json.dumps(
                    {"product": product.model_dump(mode="json"), "warnings": warnings},
                    ensure_ascii=False,
                    separators=(",", ":"),
                    allow_nan=False,
                )
                try:
                    connection.execute(
                        "INSERT INTO catalogue_products (barcode, data) VALUES (?, ?)",
                        (code, data),
                    )
                except sqlite3.IntegrityError as error:
                    raise ValueError("Duplicate exact barcode in India source rows") from error
                if source_format == "off_jsonl":
                    details, fact_warnings = project_facts(row, code)
                    facts_data = json.dumps(
                        {"details": details.model_dump(mode="json"), "warnings": fact_warnings},
                        ensure_ascii=False,
                        separators=(",", ":"),
                        allow_nan=False,
                    )
                    if len(facts_data.encode("utf-8")) > MAX_ROW_BYTES:
                        raise ValueError("Projected product facts exceed the record-size limit")
                    connection.execute(
                        "INSERT INTO catalogue_facts (barcode, data) VALUES (?, ?)",
                        (code, facts_data),
                    )
                counts["indexed_products"] += 1
                counts["missing_name"] += product.name is None
                counts["missing_ingredients"] += product.ingredients_text is None
                if counts["indexed_products"] % BATCH_SIZE == 0:
                    connection.commit()
                    _check_work_budget(directory, max_work_bytes)
            if counts["indexed_products"] == 0:
                raise ValueError("Source contains no supported India products")
            manifest = Manifest(
                snapshot_id=str(uuid.uuid4()),
                source_url=source_url,
                source_sha256=digest.hexdigest(),
                source_format=source_format,
                coverage=coverage,
                exported_at=exported_at,
                indexed_at=datetime.now(UTC),
                rows_read=counts["rows_read"],
                india_rows=counts["india_rows"],
                indexed_products=counts["indexed_products"],
                unsupported_barcodes=counts["unsupported_barcodes"],
                missing_name=counts["missing_name"],
                missing_ingredients=counts["missing_ingredients"],
            )
            for expected, actual in (
                (expected_source_sha256, manifest.source_sha256),
                (expected_rows_read, manifest.rows_read),
                (expected_indexed_products, manifest.indexed_products),
            ):
                if expected is not None and expected != actual:
                    raise ValueError("Staged catalogue differs from expected bundle hash/counts")
            connection.execute(
                "INSERT INTO catalogue_manifest (id, data) VALUES (1, ?)",
                (manifest.model_dump_json(),),
            )
            connection.commit()
            _check_work_budget(directory, max_work_bytes)
            if staging.stat().st_size > max_artifact_bytes:
                raise ValueError("Catalogue exceeds the artifact-size budget")
            if verify_database(connection) != manifest:
                raise ValueError("Staged catalogue manifest did not round-trip")
        # Re-open read-only after closing the writer before the one-file swap.
        with read_only_connection(staging) as connection:
            if verify_database(connection) != manifest:
                raise ValueError("Closed catalogue did not verify")
        if _active_signature(active) != initial_signature:
            raise ValueError("Active catalogue changed during import")
        _check_work_budget(directory, max_work_bytes)
        ensure_lock_owned()
        os.replace(staging, active)
        return manifest
    except sqlite3.DatabaseError as error:
        raise ValueError("Catalogue could not be built within its database budget") from error
    finally:
        # Delete only this call's unique staging file; never glob or recurse.
        if staging.exists():
            staging.unlink()
