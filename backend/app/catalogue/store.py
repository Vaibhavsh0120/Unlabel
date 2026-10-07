import json
import sqlite3
from contextlib import closing, contextmanager
from pathlib import Path

from app.catalogue.facts import FactsLookup, ProductFacts
from app.catalogue.models import CatalogLookup, Manifest, validate_barcode
from app.catalogue.search import (
    MAX_INDEX_INSTRUCTIONS,
    MAX_QUERY_INSTRUCTIONS,
    InvalidSearchRequest,
    SearchResult,
    query_terms,
    search_catalogue,
    search_index_supported,
    validate_search_options,
)
from app.core.json_numbers import checked_float, reject_constant
from app.schemas.products import Product

DATABASE_FILENAME = "catalogue.sqlite3"
APPLICATION_ID = 0x554E4C42
DATABASE_VERSION = 1
MAX_RECORD_BYTES = 512 * 1024


def resolved_directory(directory: Path) -> Path:
    path = Path(directory).resolve(strict=True)
    if not path.is_dir():
        raise ValueError("Catalogue directory must be an existing directory")
    return path


@contextmanager
def read_only_connection(path: Path):
    """Opening a missing catalogue must never create a SQLite file."""
    if path.is_symlink() or not path.is_file():
        raise OSError("Catalogue database is missing or is not a regular owned file")
    try:
        with closing(sqlite3.connect(path.as_uri() + "?mode=ro", uri=True)) as connection:
            connection.execute("PRAGMA query_only = ON")
            connection.execute("BEGIN")
            yield connection
    except sqlite3.DatabaseError as error:
        raise ValueError("Catalogue database is unreadable or corrupt") from error


def read_manifest(connection: sqlite3.Connection) -> Manifest:
    if (
        connection.execute("PRAGMA application_id").fetchone()[0] != APPLICATION_ID
        or connection.execute("PRAGMA user_version").fetchone()[0] != DATABASE_VERSION
    ):
        raise ValueError("Unrecognized catalogue database")
    rows = connection.execute("SELECT id, data FROM catalogue_manifest").fetchmany(2)
    if len(rows) != 1 or rows[0][0] != 1:
        raise ValueError("Catalogue manifest is missing or ambiguous")
    value = rows[0][1]
    if not isinstance(value, str) or len(value.encode("utf-8")) > 64 * 1024:
        raise ValueError("Catalogue manifest is invalid")
    return Manifest.model_validate_json(value)


def verify_database(connection: sqlite3.Connection) -> Manifest:
    result = connection.execute("PRAGMA integrity_check").fetchmany(2)
    if result != [("ok",)]:
        raise ValueError("Catalogue database integrity check failed")
    manifest = read_manifest(connection)
    count = connection.execute("SELECT COUNT(*) FROM catalogue_products").fetchone()[0]
    if count != manifest.indexed_products:
        raise ValueError("Catalogue record count does not match its manifest")
    if _has_facts(connection):
        facts_count = connection.execute("SELECT COUNT(*) FROM catalogue_facts").fetchone()[0]
        unmatched = connection.execute(
            "SELECT COUNT(*) FROM catalogue_facts LEFT JOIN catalogue_products USING (barcode) "
            "WHERE catalogue_products.barcode IS NULL"
        ).fetchone()[0]
        distinct = connection.execute(
            "SELECT COUNT(DISTINCT barcode) FROM catalogue_facts"
        ).fetchone()[0]
        if facts_count != count or distinct != count or unmatched:
            raise ValueError("Catalogue facts do not match its identity record count/keys")
    return manifest


def _has_facts(connection: sqlite3.Connection) -> bool:
    return (
        connection.execute(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'catalogue_facts'"
        ).fetchone()
        is not None
    )


def _stored_json(value: object, *, expected_keys: set[str]) -> dict:
    if not isinstance(value, str) or len(value.encode("utf-8")) > MAX_RECORD_BYTES:
        raise ValueError("Catalogue product record is invalid")
    try:
        data = json.loads(value, parse_float=checked_float, parse_constant=reject_constant)
        if not isinstance(data, dict) or set(data) != expected_keys:
            raise ValueError("Catalogue product record has an invalid shape")
        return data
    except (RecursionError, UnicodeError) as error:
        raise ValueError("Catalogue product record is invalid") from error


def _stored_warnings(value: object) -> list[str]:
    if (
        not isinstance(value, list)
        or len(value) > 100
        or any(not isinstance(item, str) for item in value)
    ):
        raise ValueError("Catalogue warning record is invalid")
    return CatalogLookup.bounded_warnings(value)


class CatalogueStore:
    def __init__(self, directory: Path):
        self.directory = resolved_directory(directory)
        self.path = self.directory / DATABASE_FILENAME
        with read_only_connection(self.path) as connection:
            manifest = verify_database(connection)
            self._supports_facts = _has_facts(connection)
            self._supports_search = search_index_supported(connection, manifest)
            self._search_manifest = manifest

    @property
    def supports_facts(self) -> bool:
        """The optional facts table passed identity count/key checks at initialization."""
        return self._supports_facts

    @property
    def supports_search(self) -> bool:
        """Optional Unicode discovery tables passed format/count/key checks."""
        try:
            with read_only_connection(self.path) as connection:
                return self._search_supported(connection, read_manifest(connection))
        except (ValueError, OSError):
            return False

    def _search_supported(self, connection: sqlite3.Connection, manifest: Manifest) -> bool:
        if manifest != self._search_manifest:
            instructions = 0

            def exceeded() -> bool:
                nonlocal instructions
                instructions += 1000
                return instructions > MAX_INDEX_INSTRUCTIONS

            # An explicit local snapshot replacement is uncommon and must pass
            # the complete optional-index validation before being advertised.
            connection.set_progress_handler(exceeded, 1000)
            supported = search_index_supported(connection, manifest)
            connection.set_progress_handler(None, 0)
            self._supports_search = supported
            self._search_manifest = manifest
            return supported
        return self._supports_search

    def search(self, query: str, *, limit: int = 10, cursor: str | None = None) -> SearchResult:
        query, terms = query_terms(query)
        validate_search_options(limit, cursor)
        manifest = None
        try:
            with read_only_connection(self.path) as connection:
                manifest = read_manifest(connection)
                if not self._search_supported(connection, manifest):
                    return SearchResult(
                        status="unavailable",
                        query=query,
                        normalized_query=" ".join(terms),
                        manifest=manifest,
                        warnings=["catalogue_search_unavailable"],
                    )
                instructions = 0

                def exceeded() -> bool:
                    nonlocal instructions
                    instructions += 1000
                    return instructions > MAX_QUERY_INSTRUCTIONS

                connection.set_progress_handler(exceeded, 1000)
                return search_catalogue(
                    connection, manifest, query, terms, limit=limit, cursor=cursor
                )
        except InvalidSearchRequest:
            raise
        except (ValueError, OSError):
            return SearchResult(
                status="unavailable",
                query=query,
                normalized_query=" ".join(terms),
                manifest=manifest,
                warnings=["catalogue_search_unavailable"],
            )

    @property
    def manifest(self) -> Manifest:
        with read_only_connection(self.path) as connection:
            return read_manifest(connection)

    def lookup(self, barcode: str) -> CatalogLookup:
        validate_barcode(barcode)
        with read_only_connection(self.path) as connection:
            # One read transaction keeps the manifest and product in the same snapshot.
            manifest = read_manifest(connection)
            row = connection.execute(
                "SELECT data FROM catalogue_products WHERE barcode = ?", (barcode,)
            ).fetchone()
            if row is None:
                return CatalogLookup(
                    requested_barcode=barcode,
                    status="not_found",
                    manifest=manifest,
                    warnings=["snapshot_age_needs_review"],
                )
            data = _stored_json(row[0], expected_keys={"product", "warnings"})
            product = Product.model_validate(data["product"], strict=True)
            return CatalogLookup(
                requested_barcode=barcode,
                status="found",
                manifest=manifest,
                product=product,
                warnings=data["warnings"],
            )

    def lookup_facts(self, barcode: str) -> FactsLookup:
        validate_barcode(barcode)
        with read_only_connection(self.path) as connection:
            # A single transaction keeps identity, details, and provenance coherent.
            manifest = read_manifest(connection)
            row = connection.execute(
                "SELECT data FROM catalogue_products WHERE barcode = ?", (barcode,)
            ).fetchone()
            if row is None:
                return FactsLookup(
                    requested_barcode=barcode,
                    status="not_found",
                    manifest=manifest,
                    warnings=["snapshot_age_needs_review"],
                )
            if not _has_facts(connection):
                return FactsLookup(
                    requested_barcode=barcode,
                    status="unavailable",
                    manifest=manifest,
                    warnings=["identity_snapshot_has_no_details"],
                )
            identity = _stored_json(row[0], expected_keys={"product", "warnings"})
            facts_row = connection.execute(
                "SELECT data FROM catalogue_facts WHERE barcode = ?", (barcode,)
            ).fetchone()
            if facts_row is None:
                raise ValueError("Catalogue details are missing for its identity")
            facts = _stored_json(facts_row[0], expected_keys={"details", "warnings"})
            details = ProductFacts.model_validate_json(
                json.dumps(facts["details"], ensure_ascii=False, allow_nan=False)
            )
            product = Product.model_validate(identity["product"], strict=True)
            warnings = list(
                dict.fromkeys(
                    [
                        *_stored_warnings(identity["warnings"]),
                        *_stored_warnings(facts["warnings"]),
                    ]
                )
            )[:100]
            return FactsLookup(
                requested_barcode=barcode,
                status="found",
                manifest=manifest,
                product=product,
                details=details,
                warnings=warnings,
            )
