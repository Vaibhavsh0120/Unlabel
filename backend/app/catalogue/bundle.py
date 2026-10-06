"""Build and verify the local catalogue shipped with the backend deployment.

This layer reads only the acquired source bundle. It performs no acquisition,
configuration loading, or environment decryption. Each rebuild keeps the importer's
actual indexing time and snapshot ID; its receipt records that build's database hash.
"""

import gzip
import hashlib
import json
import os
import stat
import tempfile
import zlib
from pathlib import Path
from typing import Literal, Self

from pydantic import AwareDatetime, Field, model_validator

from app.catalogue.importer import PAGE_SIZE, _exclusive_import, build_catalogue
from app.catalogue.models import (
    CatalogueModel,
    Coverage,
    Manifest,
    SourceFormat,
    validate_source_url,
)
from app.catalogue.status import snapshot_freshness
from app.catalogue.store import DATABASE_FILENAME, CatalogueStore
from app.core.json_numbers import checked_float, reject_constant

SOURCE_FILENAME = "india-products.jsonl.gz"
RECEIPT_FILENAME = "receipt.json"
MAX_ARTIFACT_BYTES = 100 * 1024**2
MAX_DECODED_BYTES = 100 * 1024**2
MAX_METADATA_BYTES = 64 * 1024
READ_BYTES = 64 * 1024
HASH_PATTERN = r"^[0-9a-f]{64}$"


class _SourceBundle(CatalogueModel):
    schema_version: Literal["1"]
    source_file: Literal["india-products.jsonl.gz"]
    source_format: SourceFormat
    source_url: str = Field(min_length=1, max_length=2048)
    exported_at: AwareDatetime
    coverage: Coverage
    compressed_sha256: str = Field(pattern=HASH_PATTERN)
    compressed_bytes: int = Field(ge=1, le=MAX_ARTIFACT_BYTES)
    decoded_sha256: str = Field(pattern=HASH_PATTERN)
    decoded_bytes: int = Field(ge=1, le=MAX_DECODED_BYTES)
    expected_input_rows: int = Field(ge=1, le=MAX_DECODED_BYTES)
    indexed_products: int = Field(ge=1, le=MAX_DECODED_BYTES)
    unsupported_barcodes: int = Field(ge=0, le=MAX_DECODED_BYTES)
    market_tag: Literal["en:india"]
    database_license: Literal["ODbL-1.0"]
    contents_license: Literal["DbCL-1.0"]
    attribution: Literal["Product data from Open Food Facts"]
    refresh_interval_months: Literal[9]

    @model_validator(mode="after")
    def validate_provenance(self) -> Self:
        validate_source_url(self.source_url)
        if self.indexed_products + self.unsupported_barcodes > self.expected_input_rows:
            raise ValueError("Source bundle counts are inconsistent")
        return self


class _Receipt(CatalogueModel):
    schema_version: Literal["1"]
    database_file: Literal["catalogue.sqlite3"]
    database_sha256: str = Field(pattern=HASH_PATTERN)
    database_bytes: int = Field(ge=PAGE_SIZE, le=MAX_ARTIFACT_BYTES)
    source_sha256: str = Field(pattern=HASH_PATTERN)
    source_compressed_sha256: str = Field(pattern=HASH_PATTERN)
    snapshot_id: str = Field(min_length=1, max_length=128, pattern=r"^[A-Za-z0-9._:-]+$")
    indexed_products: int = Field(ge=1, le=MAX_DECODED_BYTES)
    exported_at: AwareDatetime
    source_format: SourceFormat
    coverage: Coverage


def _reject_links(path: Path) -> None:
    for candidate in (path, *path.parents):
        if candidate.is_symlink() or candidate.is_junction():
            raise ValueError("Catalogue bundle paths cannot contain symlinks or junctions")


def _directory(path: Path, *, create: bool = False) -> Path:
    path = Path(path).absolute()
    _reject_links(path)
    if create:
        path.mkdir(parents=True, exist_ok=True)
    path = path.resolve(strict=True)
    if not path.is_dir():
        raise ValueError("Catalogue bundle directory must be a local directory")
    return path


def _regular_file(path: Path) -> int:
    _reject_links(path)
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode):
        raise ValueError("Catalogue bundle input must be a regular file")
    return info.st_size


def _unique_object(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Catalogue metadata has duplicate JSON fields")
        result[key] = value
    return result


def _metadata(path: Path, model: type[_SourceBundle] | type[_Receipt]):
    if not 0 < _regular_file(path) <= MAX_METADATA_BYTES:
        raise ValueError("Catalogue metadata exceeds its size limit")
    with path.open("rb") as stream:
        data = stream.read(MAX_METADATA_BYTES + 1)
    if len(data) > MAX_METADATA_BYTES:
        raise ValueError("Catalogue metadata exceeds its size limit")
    try:
        raw = json.loads(
            data.decode("utf-8"),
            parse_float=checked_float,
            parse_constant=reject_constant,
            object_pairs_hook=_unique_object,
        )
        if (
            not isinstance(raw, dict)
            or not isinstance(raw.get("exported_at"), str)
            or not 1 <= len(raw["exported_at"]) <= 64
        ):
            raise ValueError("Catalogue metadata must contain an aware export date")
        return model.model_validate_json(data)
    except (UnicodeError, RecursionError) as error:
        raise ValueError("Catalogue metadata is invalid UTF-8 JSON") from error


def _file_hash(path: Path, limit: int) -> tuple[str, int]:
    if not 0 < _regular_file(path) <= limit:
        raise ValueError("Catalogue bundle file exceeds its byte limit")
    digest = hashlib.sha256()
    size = 0
    with path.open("rb") as stream:
        while chunk := stream.read(READ_BYTES):
            size += len(chunk)
            if size > limit:
                raise ValueError("Catalogue bundle file exceeds its byte limit")
            digest.update(chunk)
    return digest.hexdigest(), size


def _verify_source(path: Path, source: _SourceBundle) -> None:
    if _file_hash(path, MAX_ARTIFACT_BYTES) != (source.compressed_sha256, source.compressed_bytes):
        raise ValueError("Compressed catalogue source differs from its bundle hash/size")
    digest = hashlib.sha256()
    size = 0
    try:
        with path.open("rb") as raw, gzip.GzipFile(fileobj=raw, mode="rb") as decoded:
            while chunk := decoded.read(min(READ_BYTES, MAX_DECODED_BYTES - size + 1)):
                size += len(chunk)
                if size > MAX_DECODED_BYTES:
                    raise ValueError("Decoded catalogue source exceeds its byte limit")
                digest.update(chunk)
    except (gzip.BadGzipFile, EOFError, zlib.error) as error:
        raise ValueError("Compressed catalogue source is invalid or incomplete") from error
    if (digest.hexdigest(), size) != (source.decoded_sha256, source.decoded_bytes):
        raise ValueError("Decoded catalogue source differs from its bundle hash/size")


def _receipt(directory: Path, manifest: Manifest, source: _SourceBundle) -> _Receipt:
    digest, size = _file_hash(directory / DATABASE_FILENAME, MAX_ARTIFACT_BYTES)
    return _Receipt(
        schema_version="1",
        database_file=DATABASE_FILENAME,
        database_sha256=digest,
        database_bytes=size,
        source_sha256=manifest.source_sha256,
        source_compressed_sha256=source.compressed_sha256,
        snapshot_id=manifest.snapshot_id,
        indexed_products=manifest.indexed_products,
        exported_at=manifest.exported_at,
        source_format=manifest.source_format,
        coverage=manifest.coverage,
    )


def verify_bundle(directory: Path) -> dict:
    """Hash the bounded database once and check its receipt against the store manifest.

    The compressed source hash is acquisition metadata: runtime does not include the
    gzip source. Hashes detect artifact mismatch; the receipt is not a signature.
    """
    directory = _directory(directory)
    receipt = _metadata(directory / RECEIPT_FILENAME, _Receipt)
    digest, size = _file_hash(directory / DATABASE_FILENAME, MAX_ARTIFACT_BYTES)
    if (digest, size) != (receipt.database_sha256, receipt.database_bytes):
        raise ValueError("Packaged catalogue differs from its receipt database hash/size")
    manifest = CatalogueStore(directory).manifest
    if any(
        getattr(receipt, field) != getattr(manifest, field)
        for field in (
            "schema_version",
            "source_sha256",
            "snapshot_id",
            "indexed_products",
            "exported_at",
            "source_format",
            "coverage",
        )
    ):
        raise ValueError("Packaged catalogue manifest differs from its receipt")
    return receipt.model_dump(mode="json")


def build_bundle(source_directory: Path, output_directory: Path) -> dict:
    """Assemble a deployable bundle from existing local source with runtime deps only.

    Validate source before touching the active files, then use the importer's owned
    lock and staging publication. Database and receipt swaps are separate operations:
    a receipt publication failure fails the build and must not be served as a release.
    This is a deployment build step, not an atomic runtime hot-swap API.
    """
    source_directory = _directory(source_directory)
    source = _metadata(source_directory / "bundle.json", _SourceBundle)
    # The packaged source must have a representable UTC date and refresh due date.
    snapshot_freshness(source.exported_at)
    source_path = source_directory / SOURCE_FILENAME
    _verify_source(source_path, source)
    output_directory = _directory(output_directory, create=True)
    for filename in (DATABASE_FILENAME, RECEIPT_FILENAME):
        path = output_directory / filename
        _reject_links(path)
        if path.exists():
            _regular_file(path)
    with _exclusive_import(output_directory) as ensure_owned:
        # Reject a pre-existing unrecognized database rather than overwriting it.
        if (output_directory / DATABASE_FILENAME).exists():
            CatalogueStore(output_directory)
        with tempfile.TemporaryDirectory(prefix=".catalogue-bundle-", dir=output_directory) as name:
            staging = Path(name)
            manifest = build_catalogue(
                source_path,
                staging,
                source_url=source.source_url,
                exported_at=source.exported_at,
                coverage=source.coverage,
                source_format=source.source_format,
                max_artifact_bytes=MAX_ARTIFACT_BYTES,
                expected_source_sha256=source.decoded_sha256,
                expected_rows_read=source.expected_input_rows,
                expected_indexed_products=source.indexed_products,
            )
            if manifest.unsupported_barcodes != source.unsupported_barcodes:
                raise ValueError("Staged catalogue differs from the source bundle counts")
            # Include gzip trailer validation again before publishing; neither source
            # nor descriptor changes may silently enter the assembled deployment.
            if _metadata(source_directory / "bundle.json", _SourceBundle) != source:
                raise ValueError("Catalogue source metadata changed during build")
            _verify_source(source_path, source)
            receipt = _receipt(staging, manifest, source)
            receipt_path = staging / RECEIPT_FILENAME
            with receipt_path.open("x", encoding="utf-8", newline="\n") as stream:
                stream.write(receipt.model_dump_json(indent=2) + "\n")
                stream.flush()
                os.fsync(stream.fileno())
            result = verify_bundle(staging)
            for filename in (DATABASE_FILENAME, RECEIPT_FILENAME):
                _reject_links(output_directory / filename)
            ensure_owned()
            os.replace(staging / DATABASE_FILENAME, output_directory / DATABASE_FILENAME)
            os.replace(receipt_path, output_directory / RECEIPT_FILENAME)
            return result
