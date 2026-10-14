"""Build and query an independently verified read-only researched product database."""

import base64
import gzip
import hashlib
import importlib.util
import io
import json
import os
import re
import sqlite3
import stat
import tempfile
import unicodedata
from collections.abc import Iterator
from contextlib import closing, contextmanager
from pathlib import Path
from typing import Any

from pydantic import Field

from app.catalogue.search import InvalidSearchRequest, identity_tokens, query_terms
from app.core.json_numbers import checked_float, reject_constant
from app.research_catalogue.models import (
    BARCODE_PATTERN,
    HASH_PATTERN,
    ResearchBarcodeLookup,
    ResearchCandidate,
    ResearchLookup,
    ResearchModel,
    ResearchObservation,
    ResearchSearchResult,
    canonical,
)

DATABASE_FILENAME = "research.sqlite3"
RECEIPT_FILENAME = "receipt.json"
APPLICATION_ID = 0x554E5253
DATABASE_VERSION = 3
MAX_BYTES = 64 * 1024**2
MAX_SOURCE_BYTES = 32 * 1024**2
MAX_METADATA_BYTES = 2 * 1024**2
MAX_OBSERVATIONS = 5000
MAX_MATCHES = 1000
WARNINGS = ["researched_web_facts_not_current_package_confirmation", "allergen_safety_not_assessed"]


class InvalidResearchCursor(ValueError):
    """Malformed or differently scoped cursors are redacted HTTP 422 errors."""


class ResearchReceipt(ResearchModel):
    schema_version: str = Field(pattern=r"^research-catalogue-bundle-v1$")
    database_file: str = Field(pattern=r"^research\.sqlite3$")
    database_sha256: str = Field(pattern=HASH_PATTERN)
    database_bytes: int = Field(ge=4096, le=MAX_BYTES)
    dataset_sha256: str = Field(pattern=HASH_PATTERN)
    source_compressed_sha256: str = Field(pattern=HASH_PATTERN)
    source_manifest_sha256: str = Field(pattern=HASH_PATTERN)
    observation_count: int = Field(ge=1, le=MAX_OBSERVATIONS)
    format_version: int = Field(ge=2, le=DATABASE_VERSION)


def _path(path: Path) -> Path:
    path = Path(path).absolute()
    if any(part.is_symlink() or part.is_junction() for part in (path, *path.parents)):
        raise ValueError("Research database paths cannot contain links or junctions")
    return path


def _read(path: Path, limit: int) -> bytes:
    path = _path(path)
    info = path.stat()
    if not stat.S_ISREG(info.st_mode) or not 0 < info.st_size <= limit:
        raise ValueError("Research artifact exceeds regular-file byte bounds")
    with path.open("rb") as stream:
        data = stream.read(limit + 1)
    if len(data) > limit:
        raise ValueError("Research artifact exceeds its byte bounds")
    return data


def _pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in items:
        if key in result:
            raise ValueError("Research artifact has duplicate JSON fields")
        result[key] = value
    return result


def _json(data: bytes | str) -> dict[str, Any]:
    try:
        value = json.loads(
            data,
            object_pairs_hook=_pairs,
            parse_float=checked_float,
            parse_constant=reject_constant,
        )
        if not isinstance(value, dict):
            raise ValueError("Research artifact must be a JSON object")
        return value
    except (UnicodeError, RecursionError) as error:
        raise ValueError("Research artifact is invalid bounded JSON") from error


def _signature(path: Path) -> tuple[int, int, int, int]:
    path = _path(path)
    info = path.stat()
    if not stat.S_ISREG(info.st_mode):
        raise ValueError("Research database must be a regular file")
    return info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns


@contextmanager
def read_only_connection(path: Path) -> Iterator[sqlite3.Connection]:
    path = _path(path)
    if not path.is_file():
        raise ValueError("Research database is missing")
    try:
        with closing(sqlite3.connect(path.as_uri() + "?mode=ro", uri=True)) as connection:
            connection.execute("PRAGMA query_only = ON")
            connection.execute("BEGIN")
            yield connection
    except sqlite3.DatabaseError as error:
        raise ValueError("Research database is unreadable or corrupt") from error


def _search_text(value: str) -> str:
    # Join brand apostrophes and fold Latin accents without dropping Indic marks.
    value = re.sub(r"(?<=\w)['’](?=\w)", "", value)
    result = []
    for character in unicodedata.normalize("NFKC", value):
        if "LATIN" in unicodedata.name(character, ""):
            result.extend(
                part
                for part in unicodedata.normalize("NFD", character)
                if not unicodedata.combining(part)
            )
        else:
            result.append(character)
    return "".join(result)


def _tokens(observation: ResearchObservation) -> tuple[str, ...]:
    identity = observation.identity
    text = [identity.name, identity.brand, identity.variant, identity.quantity]
    # Retrieval may match source wording; it never promotes a marketing tag to
    # a verified current-package claim or combines incompatible source records.
    for section in (observation.sections.ingredients, observation.sections.contains,
                    observation.sections.may_contain):
        if section is not None:
            text.append(section.text)
    projection = observation.raw_projection or {}
    for key in ("labels", "labels_tags"):
        labels = projection.get(key)
        if isinstance(labels, str):
            text.append(labels)
        elif isinstance(labels, list):
            text.extend(value for value in labels if isinstance(value, str))
    for key in ("front_claims", "claims"):
        claims = observation.metadata.get(key)
        if isinstance(claims, list):
            text.extend(value for value in claims if isinstance(value, str))
    return identity_tokens(
        _search_text(value)
        for value in text
        if value is not None
    )


def research_query_terms(query: str) -> tuple[str, tuple[str, ...]]:
    if not isinstance(query, str) or not 1 <= len(query) <= 128:
        raise InvalidSearchRequest("Invalid search query")
    _, terms = query_terms(_search_text(query))
    return query.strip(), terms


def _checked_record(data: object) -> ResearchObservation:
    if not isinstance(data, str) or len(data.encode("utf-8")) > 256 * 1024:
        raise ValueError("Research observation record exceeds byte bounds")
    raw = _json(data)
    observation = ResearchObservation.model_validate(raw)
    if canonical(raw).decode("utf-8") != data:
        raise ValueError("Research observation must retain canonical source bytes")
    return observation


def _candidate(observation: ResearchObservation, conflict_fields: list[str]) -> ResearchCandidate:
    return ResearchCandidate(
        entry_id=observation.observation_id,
        identity=observation.identity,
        provider=observation.source.provider,
        source=observation.source,
        eligibility="conflicting" if conflict_fields else observation.eligibility,
        conflict_fields=conflict_fields,
        ingredients_available=observation.sections.ingredients is not None,
        nutrition_available=bool(observation.nutrition.direct_tables),
    )


def _conflicts(value: str) -> list[str]:
    raw = _json('{"fields":' + value + "}").get("fields")
    if (
        not isinstance(raw, list)
        or len(raw) > 16
        or any(not isinstance(field, str) or not field or len(field) > 2000 for field in raw)
    ):
        raise ValueError("Research conflict fields are invalid")
    return raw


def _database_manifest(connection: sqlite3.Connection, version: int = DATABASE_VERSION) -> dict[str, Any]:
    if connection.execute("PRAGMA application_id").fetchone()[0] != APPLICATION_ID or (
        connection.execute("PRAGMA user_version").fetchone()[0] != version
    ):
        raise ValueError("Unrecognized research database")
    rows = connection.execute("SELECT id,data FROM research_manifest").fetchmany(2)
    if len(rows) != 1 or rows[0][0] != 1 or len(rows[0][1].encode("utf-8")) > MAX_METADATA_BYTES:
        raise ValueError("Research database manifest is missing or ambiguous")
    return _json(rows[0][1])


def _expected_conflicts(observations: list[ResearchObservation]) -> dict[str, list[str]]:
    """Recompute conservative barcode conflicts from retained original observations."""
    groups: dict[str, list[ResearchObservation]] = {}
    for observation in observations:
        if observation.identity.barcode is not None:
            groups.setdefault(observation.identity.barcode, []).append(observation)

    def folded(value: str) -> str:
        return " ".join(unicodedata.normalize("NFKC", value).casefold().split())

    result = {}
    for barcode, entries in groups.items():
        fields = []
        for field in ("name", "brand", "variant", "quantity"):
            values = [getattr(item.identity, field) for item in entries]
            if len({folded(value) for value in values if value}) > 1:
                fields.append("identity." + field)
        for field in ("ingredients", "contains", "may_contain"):
            sections = [getattr(item.sections, field) for item in entries]
            if len({folded(section.text) for section in sections if section is not None}) > 1:
                fields.append(field)
        nutrition: dict[tuple[bytes, str, str, str | None, str], set[int | float]] = {}
        for item in entries:
            for table in item.nutrition.direct_tables:
                for row in table.rows:
                    if row.value is not None:
                        key = (
                            canonical(table.basis),
                            table.preparation,
                            row.nutrient,
                            row.unit,
                            row.qualifier,
                        )
                        nutrition.setdefault(key, set()).add(row.value)
        if any(len(values) > 1 for values in nutrition.values()):
            fields.append("nutrition")
        result[barcode] = fields
    return result


def verify_research_bundle(directory: Path) -> dict[str, Any]:
    """Verify the separate DB receipt and every immutable source/index relationship."""
    return _verify_research_bundle(directory, DATABASE_VERSION)


def _verify_research_bundle(directory: Path, version: int) -> dict[str, Any]:
    directory = _path(directory)
    receipt_data = _read(directory / RECEIPT_FILENAME, 64 * 1024)
    receipt = ResearchReceipt.model_validate(_json(receipt_data))
    if receipt.format_version != version:
        raise ValueError("Research format requires a verified source rebuild")
    database = _read(directory / DATABASE_FILENAME, MAX_BYTES)
    if (len(database), hashlib.sha256(database).hexdigest()) != (
        receipt.database_bytes,
        receipt.database_sha256,
    ):
        raise ValueError("Research database differs from its receipt hash/size")
    with read_only_connection(directory / DATABASE_FILENAME) as connection:
        if connection.execute("PRAGMA integrity_check").fetchmany(2) != [("ok",)]:
            raise ValueError("Research database integrity check failed")
        expected_schema = {
            "research_manifest": ["id", "data"],
            "research_products": [
                "entry_id",
                "data",
                "barcode",
                "eligible_barcode",
                "name_sort",
                "conflict_fields",
            ],
            "research_terms": ["token", "entry_id"],
        }
        if {
            row[0]
            for row in connection.execute("SELECT name FROM sqlite_master WHERE type='table'")
        } != set(expected_schema):
            raise ValueError("Research database schema contains untracked tables")
        for table, columns in expected_schema.items():
            if [row[1] for row in connection.execute(f"PRAGMA table_info({table})")] != columns:
                raise ValueError("Research database schema differs from its bounded format")
        if [row[2] for row in connection.execute("PRAGMA index_info(research_entry_terms)")] != [
            "entry_id",
            "token",
        ]:
            raise ValueError("Research database schema lacks its bounded query index")
        manifest = _database_manifest(connection, version)
        if manifest != receipt.model_dump(exclude={"database_sha256", "database_bytes"}):
            raise ValueError("Research database manifest differs from its receipt")
        count = connection.execute("SELECT COUNT(*) FROM research_products").fetchone()[0]
        if count != receipt.observation_count:
            raise ValueError("Research record count differs from its manifest")
        expected_terms = set()
        verified_observations = []
        stored_conflicts = {}
        source_digest = hashlib.sha256()
        source_bytes = 0
        for entry_id, data, barcode, eligible, name_sort, conflicts in connection.execute(
            "SELECT entry_id,data,barcode,eligible_barcode,name_sort,conflict_fields FROM research_products ORDER BY entry_id"
        ):
            observation = _checked_record(data)
            source_record = data.encode("utf-8") + b"\n"
            source_bytes += len(source_record)
            if source_bytes > MAX_SOURCE_BYTES:
                raise ValueError("Research original dataset exceeds source byte bounds")
            source_digest.update(source_record)
            verified_observations.append(observation)
            conflict_fields = _conflicts(conflicts)
            stored_conflicts[entry_id] = conflict_fields
            expected_eligible = (
                observation.identity.barcode
                if (observation.eligibility == "exact_sku" and not conflict_fields)
                else None
            )
            if (
                entry_id != observation.observation_id
                or barcode != observation.identity.barcode
                or eligible != expected_eligible
                or name_sort != (observation.identity.name or "").casefold()
            ):
                raise ValueError("Research identity index differs from original source identity")
            tokens = _tokens(observation) if version == DATABASE_VERSION else identity_tokens(
                _search_text(value) for value in (
                    observation.identity.name, observation.identity.brand,
                    observation.identity.variant, observation.identity.quantity,
                ) if value is not None
            )
            expected_terms.update((token, entry_id) for token in tokens)
        if source_digest.hexdigest() != receipt.dataset_sha256:
            raise ValueError(
                "Research database records differ from the original acquired dataset hash"
            )
        recomputed_conflicts = _expected_conflicts(verified_observations)
        for observation in verified_observations:
            if stored_conflicts[observation.observation_id] != recomputed_conflicts.get(
                observation.identity.barcode or "", []
            ):
                raise ValueError("Research indexed conflicts differ from original source facts")
        actual_terms = set(connection.execute("SELECT token,entry_id FROM research_terms"))
        if actual_terms != expected_terms:
            raise ValueError("Research search index differs from source identities")
    return receipt.model_dump()


def _verified_source(
    directory: Path,
) -> tuple[dict[str, Any], bytes, list[tuple[str, ResearchObservation]]]:
    # Acquisition validation is a build-only dependency; runtime never imports
    # scripts, opens source gzip, acquires internet data or loads credentials.
    script = Path(__file__).resolve().parents[3] / "scripts/data/build_popular_dataset.py"
    specification = importlib.util.spec_from_file_location("_unlabel_popular_build", script)
    if specification is None or specification.loader is None:
        raise ValueError("Research source verifier is unavailable during build")
    verifier = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(verifier)
    manifest = verifier.verify_dataset(directory)
    compressed = _read(directory / "observations.jsonl.gz", MAX_SOURCE_BYTES)
    with gzip.GzipFile(fileobj=io.BytesIO(compressed)) as stream:
        decoded = stream.read(MAX_SOURCE_BYTES + 1)
        if len(decoded) > MAX_SOURCE_BYTES or stream.read(1):
            raise ValueError("Research source exceeds decoded byte bounds")
    observations = []
    for line in decoded.splitlines():
        data = line.decode("utf-8")
        observations.append((data, _checked_record(data)))
    if len(observations) != manifest["observation_count"]:
        raise ValueError("Research source record count differs from verified manifest")
    return manifest, _read(directory / "manifest.json", MAX_METADATA_BYTES), observations


def build_research_bundle(source_directory: Path, output_directory: Path) -> dict[str, Any]:
    """Build an unpublished separate DB from the verified acquired supplement only."""
    source_directory, output_directory = _path(source_directory), _path(output_directory)
    if (
        source_directory == output_directory
        or output_directory in source_directory.parents
        or source_directory in output_directory.parents
        or any(
            (output_directory / filename).exists()
            for filename in (
                "india-products.jsonl.gz",
                "bundle.json",
                "acquisition.json",
                "catalogue.sqlite3",
            )
        )
    ):
        raise ValueError("Research database must preserve original acquisition directories")
    source_manifest, source_metadata, observations = _verified_source(source_directory)
    metadata = {
        "schema_version": "research-catalogue-bundle-v1",
        "database_file": DATABASE_FILENAME,
        "dataset_sha256": source_manifest["decoded_sha256"],
        "source_compressed_sha256": source_manifest["compressed_sha256"],
        "source_manifest_sha256": hashlib.sha256(source_metadata).hexdigest(),
        "observation_count": len(observations),
        "format_version": DATABASE_VERSION,
    }
    output_directory.mkdir(parents=True, exist_ok=True)
    for filename in (DATABASE_FILENAME, RECEIPT_FILENAME):
        _path(output_directory / filename)
    existing = any(
        (output_directory / filename).exists() for filename in (DATABASE_FILENAME, RECEIPT_FILENAME)
    )
    lock = output_directory / ".research-build.lock"
    descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    lock_identity = os.fstat(descriptor)
    os.close(descriptor)
    try:
        previous_files = {}
        if existing:
            previous = ResearchReceipt.model_validate(_json(_read(
                output_directory / RECEIPT_FILENAME, 64 * 1024
            )))
            _verify_research_bundle(output_directory, previous.format_version)
            source_records = {observation.observation_id: data for data, observation in observations}
            with read_only_connection(output_directory / DATABASE_FILENAME) as connection:
                if any(source_records.get(entry_id) != data for entry_id, data in connection.execute(
                    "SELECT entry_id,data FROM research_products"
                )):
                    raise ValueError("Source rebuild would discard or alter retained observations")
            previous_files = {
                filename: _read(output_directory / filename, MAX_BYTES)
                for filename in (DATABASE_FILENAME, RECEIPT_FILENAME)
            }
            backup = _path(output_directory / ".research-backups" / previous.database_sha256)
            backup.mkdir(parents=True, exist_ok=True)
            for filename, contents in previous_files.items():
                destination = _path(backup / filename)
                if destination.exists():
                    if _read(destination, MAX_BYTES) != contents:
                        raise ValueError("Research backup differs from preserved bundle")
                else:
                    with destination.open("xb") as stream:
                        stream.write(contents)
            _verify_research_bundle(backup, previous.format_version)
        with tempfile.TemporaryDirectory(prefix=".research-build-", dir=output_directory) as name:
            staging = Path(name)
            with closing(sqlite3.connect(staging / DATABASE_FILENAME)) as connection:
                connection.execute("PRAGMA page_size=4096")
                connection.execute("PRAGMA journal_mode=OFF")
                connection.execute(f"PRAGMA max_page_count={MAX_BYTES // 4096}")
                connection.execute(f"PRAGMA application_id={APPLICATION_ID}")
                connection.execute(f"PRAGMA user_version={DATABASE_VERSION}")
                connection.execute(
                    "CREATE TABLE research_manifest(id INTEGER PRIMARY KEY CHECK(id=1),data TEXT NOT NULL)"
                )
                connection.execute(
                    "CREATE TABLE research_products(entry_id TEXT PRIMARY KEY,data TEXT NOT NULL,barcode TEXT,eligible_barcode TEXT,name_sort TEXT NOT NULL,conflict_fields TEXT NOT NULL)"
                )
                connection.execute(
                    "CREATE TABLE research_terms(token TEXT NOT NULL,entry_id TEXT NOT NULL,PRIMARY KEY(token,entry_id)) WITHOUT ROWID"
                )
                connection.execute(
                    "CREATE INDEX research_barcode ON research_products(eligible_barcode,entry_id)"
                )
                connection.execute(
                    "CREATE INDEX research_entry_terms ON research_terms(entry_id,token)"
                )
                connection.execute(
                    "INSERT INTO research_manifest VALUES(1,?)",
                    (canonical(metadata).decode("utf-8"),),
                )
                for data, observation in observations:
                    group = source_manifest["barcode_groups"].get(observation.identity.barcode, {})
                    conflict_fields = group.get("conflict_fields", [])
                    eligible = (
                        observation.identity.barcode
                        if (observation.eligibility == "exact_sku" and not conflict_fields)
                        else None
                    )
                    connection.execute(
                        "INSERT INTO research_products VALUES(?,?,?,?,?,?)",
                        (
                            observation.observation_id,
                            data,
                            observation.identity.barcode,
                            eligible,
                            (observation.identity.name or "").casefold(),
                            canonical(conflict_fields).decode("utf-8"),
                        ),
                    )
                    connection.executemany(
                        "INSERT INTO research_terms VALUES(?,?)",
                        ((token, observation.observation_id) for token in _tokens(observation)),
                    )
                connection.commit()
            database = _read(staging / DATABASE_FILENAME, MAX_BYTES)
            receipt = ResearchReceipt(
                **metadata,
                database_sha256=hashlib.sha256(database).hexdigest(),
                database_bytes=len(database),
            )
            (staging / RECEIPT_FILENAME).write_bytes(canonical(receipt.model_dump()) + b"\n")
            verify_research_bundle(staging)
            if _read(source_directory / "manifest.json", MAX_METADATA_BYTES) != source_metadata or (
                hashlib.sha256(
                    _read(source_directory / "observations.jsonl.gz", MAX_SOURCE_BYTES)
                ).hexdigest()
                != receipt.source_compressed_sha256
            ):
                raise ValueError("Research acquisition changed during database build")
            if any(_read(output_directory / filename, MAX_BYTES) != contents
                   for filename, contents in previous_files.items()):
                raise ValueError("Retained research bundle changed during rebuild")
            for filename in (DATABASE_FILENAME, RECEIPT_FILENAME):
                current_lock = lock.lstat()
                if (current_lock.st_dev, current_lock.st_ino) != (
                    lock_identity.st_dev,
                    lock_identity.st_ino,
                ) or lock.is_symlink():
                    raise ValueError("Research build lock changed before publication")
                destination = _path(output_directory / filename)
                os.replace(staging / filename, destination)
    except sqlite3.DatabaseError as error:
        raise ValueError(
            "Research database build exceeded its validated database bounds"
        ) from error
    finally:
        if lock.exists():
            current = lock.lstat()
            if (current.st_dev, current.st_ino) == (
                lock_identity.st_dev,
                lock_identity.st_ino,
            ) and not lock.is_symlink():
                lock.unlink()
    return verify_research_bundle(output_directory)


class ResearchCatalogueStore:
    def __init__(self, directory: Path):
        self.directory = _path(directory)
        self.path = self.directory / DATABASE_FILENAME
        before = _signature(self.path)
        self.receipt = verify_research_bundle(self.directory)
        self._signature = _signature(self.path)
        if self._signature != before:
            raise ValueError("Research database changed during verification")
        from app.research_catalogue.images import load_images
        self._image_path = Path(__file__).with_name('image_sources.json')
        self._images = load_images(self._image_path)
        self._image_signature = _signature(self._image_path) if self._image_path.exists() else None

    def _unchanged(self) -> None:
        if _signature(self.path) != self._signature:
            raise ValueError("Research database changed inside an active deployment")
        if self._image_signature is not None and _signature(self._image_path) != self._image_signature:
            raise ValueError('Image descriptors changed inside an active deployment')

    def status(self) -> dict[str, Any]:
        self._unchanged()
        return {
            "status": "ready",
            "dataset_sha256": self.receipt["dataset_sha256"],
            "database_sha256": self.receipt["database_sha256"],
            "observation_count": self.receipt["observation_count"],
            "search_version": "research-search-v1",
            "format_version": DATABASE_VERSION,
            "warnings": WARNINGS,
        }

    def lookup(self, entry_id: str) -> ResearchLookup:
        if not isinstance(entry_id, str) or re.fullmatch(HASH_PATTERN, entry_id) is None:
            raise ValueError("Research entry ID must be an immutable source hash")
        self._unchanged()
        with read_only_connection(self.path) as connection:
            row = connection.execute(
                "SELECT data,conflict_fields FROM research_products WHERE entry_id=?", (entry_id,)
            ).fetchone()
            result = ResearchLookup(
                status="found" if row else "not_found",
                entry_id=entry_id,
                dataset_sha256=self.receipt["dataset_sha256"],
                observation=_checked_record(row[0]) if row else None,
                conflict_fields=_conflicts(row[1]) if row else [],
                warnings=WARNINGS,
            )
        self._unchanged()
        image = self._images.get(entry_id)
        if (image is not None and result.observation is not None and
                image.source_url == result.observation.source.url and
                image.provider == result.observation.source.provider):
            # Extra response metadata has separate provenance; acquired source
            # JSON and its content hash remain unchanged.
            result = result.model_copy(update={'image': image})
        return result

    def by_barcode(self, barcode: str) -> ResearchBarcodeLookup:
        if not isinstance(barcode, str) or re.fullmatch(BARCODE_PATTERN, barcode) is None:
            raise ValueError("Research exact barcode format is invalid")
        self._unchanged()
        with read_only_connection(self.path) as connection:
            rows = connection.execute(
                "SELECT data,conflict_fields FROM research_products WHERE eligible_barcode=? ORDER BY entry_id LIMIT 21",
                (barcode,),
            ).fetchall()
            if len(rows) > 20:
                raise ValueError("Research exact barcode alternatives exceed response bounds")
            candidates = [_candidate(_checked_record(row[0]), _conflicts(row[1])) for row in rows]
            result = ResearchBarcodeLookup(
                status="found" if rows else "not_found",
                barcode=barcode,
                dataset_sha256=self.receipt["dataset_sha256"],
                candidates=candidates,
                warnings=WARNINGS,
            )
        self._unchanged()
        return result

    def search(
        self, query: str, *, limit: int = 10, cursor: str | None = None
    ) -> ResearchSearchResult:
        query, terms = research_query_terms(query)
        if type(limit) is not int or not 1 <= limit <= 20:
            raise ValueError("Research search page limit is invalid")
        self._unchanged()
        scope = hashlib.sha256(
            canonical(
                [
                    "research-search-v1",
                    DATABASE_VERSION,
                    self.receipt["dataset_sha256"],
                    self.receipt["database_sha256"],
                    terms,
                    limit,
                ]
            )
        ).hexdigest()
        offset = 0
        if cursor is not None:
            try:
                if not isinstance(cursor, str) or not 1 <= len(cursor) <= 256:
                    raise ValueError("Invalid cursor")
                payload = _json(
                    base64.b64decode(
                        cursor + "=" * (-len(cursor) % 4), altchars=b"-_", validate=True
                    )
                )
                if (
                    set(payload) != {"v", "scope", "offset"}
                    or payload["v"] != 1
                    or payload["scope"] != scope
                    or type(payload["offset"]) is not int
                    or not 1 <= payload["offset"] <= MAX_MATCHES
                    or _cursor(scope, payload["offset"]) != cursor
                ):
                    raise ValueError("Invalid cursor")
                offset = payload["offset"]
            except (ValueError, TypeError, UnicodeError) as error:
                raise InvalidResearchCursor("Invalid or expired research search cursor") from error
        parameters: list[Any] = []
        clauses = []
        for index, term in enumerate(terms):
            predicate = "t.token=?" if index < len(terms) - 1 else "t.token>=? AND t.token<?"
            parameters.extend([term] if index < len(terms) - 1 else [term, term + "\U0010ffff"])
            clauses.append(
                f"EXISTS(SELECT 1 FROM research_terms t WHERE t.entry_id=p.entry_id AND {predicate})"
            )
        with read_only_connection(self.path) as connection:
            instructions = 0

            def exceeded() -> bool:
                nonlocal instructions
                instructions += 1000
                return instructions > 2_000_000

            connection.set_progress_handler(exceeded, 1000)
            rows = connection.execute(
                "SELECT p.entry_id,p.data,p.conflict_fields FROM research_products p WHERE "
                + " AND ".join(clauses)
                + " ORDER BY p.name_sort,p.entry_id LIMIT 1001",
                parameters,
            ).fetchall()
            candidates = []
            if len(rows) <= MAX_MATCHES:
                if offset and offset >= len(rows):
                    raise InvalidResearchCursor("Invalid or expired research search cursor")
                for entry_id, data, conflicts in rows[offset : offset + limit]:
                    observation = _checked_record(data)
                    tokens = _tokens(observation)
                    if (
                        entry_id != observation.observation_id
                        or any(term not in tokens for term in terms[:-1])
                        or not any(token.startswith(terms[-1]) for token in tokens)
                    ):
                        raise ValueError(
                            "Research search identity differs from its original source"
                        )
                    candidates.append(_candidate(observation, _conflicts(conflicts)))
            result = ResearchSearchResult(
                status="refine_query"
                if len(rows) > MAX_MATCHES
                else "ready"
                if candidates
                else "not_found",
                dataset_sha256=self.receipt["dataset_sha256"],
                query=query,
                normalized_query=" ".join(terms),
                candidates=candidates,
                matched_count=len(rows) if len(rows) <= MAX_MATCHES else None,
                next_cursor=_cursor(scope, offset + limit)
                if offset + limit < len(rows) <= MAX_MATCHES
                else None,
                warnings=WARNINGS,
            )
        self._unchanged()
        return result


def _cursor(scope: str, offset: int) -> str:
    return (
        base64.urlsafe_b64encode(canonical({"v": 1, "scope": scope, "offset": offset}))
        .decode("ascii")
        .rstrip("=")
    )
