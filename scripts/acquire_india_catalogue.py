"""Stream the official global OFF CSV into an India-only identity projection."""

import argparse
import csv
import gzip
import hashlib
import io
import json
import os
import shutil
import tempfile
import time
import urllib.request
import uuid
from datetime import UTC, datetime
from pathlib import Path
from typing import Protocol
from urllib.parse import urlsplit

SOURCE = "https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz"
MAX_PROJECTION_BYTES = 100 * 1024**2
MAX_LINE_BYTES = 2 * 1024**2
MAX_DECODED_BYTES = 32 * 1024**3


class BinaryReader(Protocol):
    def read(self, size: int = -1, /) -> bytes: ...


class MeteredReader:
    def __init__(
        self,
        stream: BinaryReader,
        *,
        max_bytes: int = 2 * 1024**3,
        progress: bool = False,
    ) -> None:
        self.stream = stream
        self.max_bytes = max_bytes
        self.bytes_read = 0
        self.digest = hashlib.sha256()
        self.started = self.last_report = time.monotonic()
        self.progress = progress

    def read(self, size: int = -1) -> bytes:
        if size < 0 or size > 1024 * 1024:
            raise ValueError("Unbounded compressed read refused")
        if time.monotonic() - self.started > 3600:
            raise ValueError("Acquisition exceeded one-hour deadline")
        data = self.stream.read(size)
        self.bytes_read += len(data)
        if self.bytes_read > self.max_bytes:
            raise ValueError("Compressed transfer exceeds 2 GiB budget")
        self.digest.update(data)
        if self.progress and time.monotonic() - self.last_report >= 20:
            print(
                json.dumps(
                    {
                        "compressed_bytes_read": self.bytes_read,
                        "elapsed_seconds": round(time.monotonic() - self.started),
                    }
                ),
                flush=True,
            )
            self.last_report = time.monotonic()
        return data

    def seek(self, offset: int, whence: int = 0) -> int:
        # Rewinding would invalidate the acquisition byte count and digest.
        raise io.UnsupportedOperation("Compressed acquisition stream cannot seek")


class BoundedLines:
    def __init__(self, source):
        self.source = source
        self.decoded_bytes = 0
        self.record_bytes = 0

    def __iter__(self):
        return self

    def __next__(self):
        line = self.source.readline(MAX_LINE_BYTES + 1)
        if not line:
            raise StopIteration
        self.decoded_bytes += len(line)
        self.record_bytes += len(line)
        if self.record_bytes > MAX_LINE_BYTES or self.decoded_bytes > MAX_DECODED_BYTES:
            raise ValueError("CSV row or decoded export exceeds budget")
        return line.decode("utf-8", errors="strict")


def project_csv(source, target):
    """No nutrition/image projection: nightly CSV nutrient values are aggregated."""
    csv.field_size_limit(MAX_LINE_BYTES)
    lines = BoundedLines(source)
    # Nightly export_database.pl sanitizes controls and emits unquoted TSV.
    # Filtered-search CSV uses a different dialect; never reuse it here.
    reader = csv.reader(lines, delimiter="\t", quoting=csv.QUOTE_NONE, strict=True)
    try:
        header = next(reader)
        if len(header) != len(set(header)) or not {"code", "countries_tags"} <= set(
            header
        ):
            raise ValueError("Export is missing required unique columns")
        rows_read = india_rows = written = 0
        lines.record_bytes = 0
        for cells in reader:
            lines.record_bytes = 0
            if len(cells) != len(header):
                raise ValueError("CSV row has inconsistent column count")
            rows_read += 1
            row = dict(zip(header, cells, strict=True))
            countries = [
                value.strip()
                for value in row["countries_tags"].split(",")
                if value.strip()
            ]
            if "en:india" not in countries:
                continue
            india_rows += 1

            def tags(field, values=row):
                value = values.get(field, "")
                if not value:
                    return None
                return [tag.strip() for tag in value.split(",") if tag.strip()]

            nova = row.get("nova_group", "")
            product = {
                "code": row["code"],
                "countries_tags": countries,
                "product_name": row.get("product_name") or None,
                "brands": row.get("brands") or None,
                "quantity": row.get("quantity") or None,
                "ingredients_text": row.get("ingredients_text") or None,
                # Legacy bare allergens may omit ingredient-derived tags.
                # Use the actual canonical column only; otherwise leave unknown.
                "allergens_tags": tags("allergens_tags"),
                "traces_tags": tags("traces_tags"),
                "nutriscore_grade": row.get("nutriscore_grade") or None,
                "nova_group": int(nova) if nova in {"1", "2", "3", "4"} else None,
            }
            payload = (json.dumps(product, ensure_ascii=True) + "\n").encode("utf-8")
            written += len(payload)
            if written > MAX_PROJECTION_BYTES:
                raise ValueError("India projection exceeds 100 MiB budget")
            target.write(payload)
    except (csv.Error, UnicodeError) as exc:
        raise ValueError("Invalid CSV export") from exc
    if not india_rows:
        raise ValueError("No India records in complete source")
    return {"rows_read": rows_read, "india_rows": india_rows}


def acquire(directory):
    directory = directory.resolve(strict=True)
    target = directory / "india-products.jsonl"
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
    lock = directory / ".acquisition.lock"
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
    started = datetime.now(UTC)
    staging = metadata_staging = None
    try:
        with tempfile.NamedTemporaryFile(
            dir=directory, prefix=".india-source-", suffix=".part", delete=False
        ) as temporary:
            staging = Path(temporary.name)
        request = urllib.request.Request(
            SOURCE,
            headers={
                "User-Agent": "Unlabel/0.4.0 (https://github.com/Vaibhavsh0120/Unlabel)",
                "Accept-Encoding": "identity",
            },
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            if (
                response.status != 200
                or urlsplit(response.url).hostname
                != "openfoodfacts-ds.s3.eu-west-3.amazonaws.com"
            ):
                raise ValueError(
                    "Official CSV origin/status changed; review before acquisition"
                )
            expected = int(response.headers["Content-Length"])
            if not 0 < expected <= 2 * 1024**3:
                raise ValueError("Official compressed source exceeds transfer budget")
            last_modified = response.headers.get("Last-Modified")
            meter = MeteredReader(response, progress=True)
            with gzip.GzipFile(fileobj=meter) as decoded, staging.open("wb") as output:
                counts = project_csv(decoded, output)
                output.flush()
                os.fsync(output.fileno())
            if meter.bytes_read != expected:
                raise ValueError("Incomplete compressed transfer")
        with staging.open("rb") as projected:
            projection_sha256 = hashlib.file_digest(projected, "sha256").hexdigest()
        evidence = {
            "source_format": "off_csv_projection",
            "source_url": SOURCE,
            "started_at": started.isoformat(),
            "completed_at": datetime.now(UTC).isoformat(),
            "source_last_modified_http": last_modified,
            "compressed_bytes": meter.bytes_read,
            "compressed_sha256": meter.digest.hexdigest(),
            "gzip_eof_verified": True,
            "projection_bytes": staging.stat().st_size,
            "projection_sha256": projection_sha256,
            **counts,
            "scope": "all en:india rows in this export; not every product sold in India",
            "omitted": ["nutrition", "images", "provider record modification dates"],
            "database_license": "ODbL-1.0",
            "contents_license": "DbCL-1.0",
        }
        # Refuse publication if another artifact appeared during the transfer.
        # Hard-link creation is exclusive even across the final check/create race.
        if target.exists() or metadata.exists():
            raise ValueError(
                "Acquisition files appeared during download; refusing overwrite"
            )
        with tempfile.NamedTemporaryFile(
            dir=directory, prefix=".india-meta-", suffix=".part", delete=False
        ) as output:
            metadata_staging = Path(output.name)
            output.write((json.dumps(evidence, indent=2) + "\n").encode("utf-8"))
            output.flush()
            os.fsync(output.fileno())
        try:
            os.link(staging, target)
            try:
                os.link(metadata_staging, metadata)
            except OSError:
                # Only remove our own newly-linked file, never a replacement.
                if target.exists() and os.path.samefile(staging, target):
                    target.unlink()
                raise
        finally:
            metadata_staging.unlink()
        print(json.dumps(evidence, indent=2), flush=True)
        return evidence
    finally:
        # Only the unique staging file created by this invocation can be removed.
        if staging is not None and staging.exists():
            staging.unlink()
        if metadata_staging is not None and metadata_staging.exists():
            metadata_staging.unlink()
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
        description="Stream official OFF CSV to an India-only identity catalogue source."
    )
    parser.add_argument(
        "--directory",
        type=Path,
        required=True,
        help="Existing empty source directory; output stays outside Git",
    )
    args = parser.parse_args()
    try:
        acquire(args.directory)
    except (ValueError, OSError, EOFError) as exc:
        parser.exit(
            1,
            f"Acquisition stopped: {type(exc).__name__}. Existing catalogue is unchanged.\n",
        )


if __name__ == "__main__":
    main()
