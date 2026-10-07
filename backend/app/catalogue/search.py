"""Bounded, read-only identity discovery over an optional snapshot index.

Only the final query term is a prefix. Earlier terms must occur exactly in the
printed name/brand/quantity identity text. This is candidate discovery, never
package recognition, reformulation proof, nutrition scoring or a live OFF call.
"""

import base64
import hashlib
import json
import re
import sqlite3
import unicodedata
from collections.abc import Iterable
from itertools import zip_longest
from typing import Literal, Self

from pydantic import Field, model_validator

from app.catalogue.models import BARCODE_PATTERN, CatalogLookup, CatalogueModel, Manifest
from app.schemas.products import Product

SEARCH_VERSION = "catalogue-search-v1"
MAX_QUERY_LENGTH = 128
MAX_QUERY_TERMS = 8
MAX_TOKEN_LENGTH = 64
MAX_CANDIDATES = 1000
MAX_CURSOR_LENGTH = 256
MAX_QUERY_INSTRUCTIONS = 1_000_000
MAX_INDEX_INSTRUCTIONS = 50_000_000
_JOIN_CONTROLS = frozenset({"\u200c", "\u200d"})
_TABLES = {
    "catalogue_search_terms": [("token", "TEXT", 1, 1), ("barcode", "TEXT", 1, 2)],
    "catalogue_search_prefixes": [("prefix", "TEXT", 1, 1), ("barcode", "TEXT", 1, 2)],
    "catalogue_search_counts": [
        ("kind", "TEXT", 1, 1),
        ("term", "TEXT", 1, 2),
        ("count", "INTEGER", 1, 0),
    ],
    "catalogue_search_format": [
        ("id", "INTEGER", 0, 1),
        ("version", "TEXT", 1, 0),
        ("indexed_products", "INTEGER", 1, 0),
        ("exact_postings", "INTEGER", 1, 0),
        ("prefix_postings", "INTEGER", 1, 0),
    ],
}


class InvalidSearchRequest(ValueError):
    """Only invalid queries/options/cursors become redacted HTTP 422 responses."""


class SearchIdentity(CatalogueModel):
    barcode: str = Field(pattern=f"^{BARCODE_PATTERN}$")
    name: str | None = Field(default=None, max_length=2000)
    brands: str | None = Field(default=None, max_length=2000)
    quantity_text: str | None = Field(default=None, max_length=2000)


class SearchCandidate(CatalogueModel):
    identity: SearchIdentity
    source_id: str = Field(pattern=r"^off:[0-9a-f]{64}:(?:[0-9]{8}|[0-9]{12,14})$")
    warnings: list[str] = Field(default_factory=list, max_length=100)


class SearchResult(CatalogueModel):
    schema_version: Literal["1"] = "1"
    search_version: Literal["catalogue-search-v1"] = SEARCH_VERSION
    status: Literal["ready", "not_found", "refine_query", "unavailable"]
    query: str = Field(min_length=1, max_length=MAX_QUERY_LENGTH)
    normalized_query: str = Field(
        min_length=2, max_length=MAX_QUERY_TERMS * (MAX_TOKEN_LENGTH + 1) - 1
    )
    manifest: Manifest | None = None
    candidates: list[SearchCandidate] = Field(default_factory=list, max_length=20)
    matched_count: int | None = Field(default=None, ge=0, le=MAX_CANDIDATES)
    ambiguous: bool | None = None
    next_cursor: str | None = Field(default=None, max_length=MAX_CURSOR_LENGTH)
    warnings: list[str] = Field(default_factory=list, max_length=100)

    @model_validator(mode="after")
    def coherent_result(self) -> Self:
        if self.status in {"ready", "not_found"}:
            if self.manifest is None or self.matched_count is None:
                raise ValueError("Completed discovery requires checked snapshot and match count")
            if self.ambiguous != (self.matched_count > 1):
                raise ValueError(
                    "Candidate ambiguity must reflect the complete bounded match count"
                )
            if self.status == "not_found" and (
                self.matched_count != 0 or self.candidates or self.next_cursor is not None
            ):
                raise ValueError("Not-found discovery cannot contain candidates")
            if self.status == "ready" and (self.matched_count == 0 or not self.candidates):
                raise ValueError("Ready discovery requires candidates")
            if len(self.candidates) > self.matched_count or len(
                {c.identity.barcode for c in self.candidates}
            ) != len(self.candidates):
                raise ValueError("Candidates must be a distinct subset of the checked matches")
            if any(
                c.source_id != f"off:{self.manifest.source_sha256}:{c.identity.barcode}"
                for c in self.candidates
            ):
                raise ValueError("Candidate source references must match the checked snapshot")
        elif (
            self.candidates
            or self.matched_count is not None
            or self.ambiguous is not None
            or self.next_cursor is not None
        ):
            raise ValueError("Incomplete discovery cannot claim matches or a continuation")
        if self.status == "refine_query" and self.manifest is None:
            raise ValueError("Query refinement requires the checked snapshot")
        return self


def _tokenize(value: str) -> Iterable[str]:
    token: list[str] = []
    for character in unicodedata.normalize("NFKC", value).casefold():
        category = unicodedata.category(character)[0]
        if category in {"L", "N"} or (category == "M" and token):
            token.append(character)
        elif character not in _JOIN_CONTROLS:
            if token:
                yield "".join(token)
            token = []
    if token:
        yield "".join(token)


def identity_tokens(values: Iterable[str | None]) -> tuple[str, ...]:
    """Preserve Indic combining marks; use the same NFKC/casefold rules at both ends.

    Punctuation separates words. Explicit join controls inside Indic text do not
    create artificial word boundaries. Tokens larger than the advertised index
    limit are omitted, rather than truncated into identities that never existed.
    """
    return tuple(
        sorted(
            {
                token
                for value in values
                if value is not None
                for token in _tokenize(value)
                if len(token) <= MAX_TOKEN_LENGTH
            }
        )
    )


def query_terms(query: str) -> tuple[str, tuple[str, ...]]:
    if (
        not isinstance(query, str)
        or not 1 <= len(query) <= MAX_QUERY_LENGTH
        or any(unicodedata.category(c)[0] == "C" and c not in _JOIN_CONTROLS for c in query)
    ):
        raise InvalidSearchRequest("Invalid search query")
    query = query.strip()
    # Preserve input order (only its final token is a prefix). Do not silently
    # discard an oversized query term as the importer may discard source tokens.
    tokens = tuple(_tokenize(query))
    if (
        not 1 <= len(tokens) <= MAX_QUERY_TERMS
        or any(len(t) > MAX_TOKEN_LENGTH for t in tokens)
        or len(tokens[-1]) < 2
    ):
        raise InvalidSearchRequest("Invalid search query")
    return query, tokens


def validate_search_options(limit: int, cursor: str | None) -> None:
    if type(limit) is not int or not 1 <= limit <= 20:
        raise InvalidSearchRequest("Invalid search limit")
    if cursor is not None and (
        not isinstance(cursor, str)
        or not 1 <= len(cursor) <= MAX_CURSOR_LENGTH
        or re.fullmatch(r"[A-Za-z0-9_-]+", cursor) is None
    ):
        raise InvalidSearchRequest("Invalid search cursor")
    if cursor is not None:
        _cursor_data(cursor)


def create_search_index(connection: sqlite3.Connection) -> None:
    connection.execute(
        "CREATE TABLE catalogue_search_terms (token TEXT NOT NULL, barcode TEXT NOT NULL, "
        "PRIMARY KEY(token, barcode)) WITHOUT ROWID"
    )
    connection.execute(
        "CREATE TABLE catalogue_search_prefixes (prefix TEXT NOT NULL, barcode TEXT NOT NULL, "
        "PRIMARY KEY(prefix, barcode)) WITHOUT ROWID"
    )
    connection.execute(
        "CREATE TABLE catalogue_search_counts (kind TEXT NOT NULL, term TEXT NOT NULL, "
        "count INTEGER NOT NULL CHECK(count > 0), PRIMARY KEY(kind, term)) WITHOUT ROWID"
    )
    connection.execute(
        "CREATE TABLE catalogue_search_format (id INTEGER PRIMARY KEY CHECK(id = 1), "
        "version TEXT NOT NULL, indexed_products INTEGER NOT NULL, "
        "exact_postings INTEGER NOT NULL, prefix_postings INTEGER NOT NULL)"
    )


def index_identity(connection: sqlite3.Connection, product: Product) -> None:
    tokens = identity_tokens((product.name, product.brands, product.quantity_text))
    prefixes = sorted({token[:length] for token in tokens for length in range(2, len(token) + 1)})
    connection.executemany(
        "INSERT INTO catalogue_search_terms(token, barcode) VALUES (?, ?)",
        [(token, product.barcode) for token in tokens],
    )
    connection.executemany(
        "INSERT INTO catalogue_search_prefixes(prefix, barcode) VALUES (?, ?)",
        [(prefix, product.barcode) for prefix in prefixes],
    )


def finish_search_index(connection: sqlite3.Connection, indexed_products: int) -> None:
    connection.execute(
        "INSERT INTO catalogue_search_counts(kind, term, count) "
        "SELECT 'exact', token, COUNT(*) FROM catalogue_search_terms GROUP BY token"
    )
    connection.execute(
        "INSERT INTO catalogue_search_counts(kind, term, count) "
        "SELECT 'prefix', prefix, COUNT(*) FROM catalogue_search_prefixes GROUP BY prefix"
    )
    exact = connection.execute("SELECT COUNT(*) FROM catalogue_search_terms").fetchone()[0]
    prefixes = connection.execute("SELECT COUNT(*) FROM catalogue_search_prefixes").fetchone()[0]
    connection.execute(
        "INSERT INTO catalogue_search_format VALUES (1, ?, ?, ?, ?)",
        (SEARCH_VERSION, indexed_products, exact, prefixes),
    )


def search_index_supported(
    connection: sqlite3.Connection, manifest: Manifest, *, full: bool = True
) -> bool:
    """Search is optional; reject a broken extension without disabling exact lookups."""
    try:
        for name, expected in _TABLES.items():
            actual = [
                tuple(row[1:])[:3] + (row[5],)
                for row in connection.execute(f"PRAGMA table_info({name})")
            ]
            if actual != expected:
                return False
        rows = connection.execute("SELECT * FROM catalogue_search_format").fetchmany(2)
        if len(rows) != 1 or rows[0][:3] != (1, SEARCH_VERSION, manifest.indexed_products):
            return False
        if any(type(count) is not int or count < 0 for count in rows[0][3:]):
            return False
        if not full:
            return True
        for kind, table, column, expected_count in (
            ("exact", "catalogue_search_terms", "token", rows[0][3]),
            ("prefix", "catalogue_search_prefixes", "prefix", rows[0][4]),
        ):
            if connection.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0] != expected_count:
                return False
            if (
                connection.execute(
                    f"SELECT 1 FROM {table} AS t LEFT JOIN catalogue_products AS p USING(barcode) "
                    "WHERE p.barcode IS NULL LIMIT 1"
                ).fetchone()
                is not None
            ):
                return False
            actual_counts = connection.execute(
                f"SELECT {column}, COUNT(*) FROM {table} GROUP BY {column}"
            )
            stored_counts = connection.execute(
                "SELECT term, count FROM catalogue_search_counts WHERE kind=? ORDER BY term",
                (kind,),
            )
            if any(
                actual != stored for actual, stored in zip_longest(actual_counts, stored_counts)
            ):
                return False
        if (
            connection.execute(
                "SELECT 1 FROM catalogue_search_counts WHERE kind NOT IN ('exact', 'prefix') LIMIT 1"
            ).fetchone()
            is not None
        ):
            return False
        return True
    except (sqlite3.DatabaseError, ValueError, TypeError):
        return False


def _cursor_scope(manifest: Manifest, terms: tuple[str, ...], limit: int) -> str:
    data = [
        SEARCH_VERSION,
        manifest.snapshot_id,
        manifest.source_sha256,
        manifest.indexed_at.isoformat(),
        terms,
        limit,
    ]
    return hashlib.sha256(
        json.dumps(data, ensure_ascii=False, separators=(",", ":")).encode()
    ).hexdigest()


def _cursor_data(cursor: str) -> dict:
    try:
        decoded = base64.b64decode(cursor + "=" * (-len(cursor) % 4), altchars=b"-_", validate=True)
        data = json.loads(decoded)
        if (
            not isinstance(data, dict)
            or set(data) != {"v", "scope", "offset"}
            or type(data["v"]) is not int
            or data["v"] != 1
            or not isinstance(data["scope"], str)
            or re.fullmatch(r"[0-9a-f]{64}", data["scope"]) is None
            or type(data["offset"]) is not int
            or not 1 <= data["offset"] <= MAX_CANDIDATES
            or _encode_cursor(data["scope"], data["offset"]) != cursor
        ):
            raise ValueError("Invalid cursor")
        return data
    except (ValueError, UnicodeError, TypeError, RecursionError) as error:
        raise InvalidSearchRequest("Invalid or expired search cursor") from error


def _decode_cursor(cursor: str | None, scope: str) -> int:
    if cursor is None:
        return 0
    data = _cursor_data(cursor)
    if data["scope"] != scope:
        raise InvalidSearchRequest("Invalid or expired search cursor")
    return data["offset"]


def _encode_cursor(scope: str, offset: int) -> str:
    data = json.dumps({"v": 1, "scope": scope, "offset": offset}, separators=(",", ":")).encode()
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


def search_catalogue(
    connection: sqlite3.Connection,
    manifest: Manifest,
    query: str,
    terms: tuple[str, ...],
    *,
    limit: int,
    cursor: str | None,
) -> SearchResult:
    """At most 1,001 anchor keys are read and at most 1,000 candidates examined."""
    normalized = " ".join(terms)
    base = {"query": query, "normalized_query": normalized, "manifest": manifest}
    scope = _cursor_scope(manifest, terms, limit)
    offset = _decode_cursor(cursor, scope)
    if not search_index_supported(connection, manifest, full=False):
        return SearchResult(status="unavailable", **base, warnings=["catalogue_search_unavailable"])
    clauses = sorted(set(("exact", term) for term in terms[:-1]) | {("prefix", terms[-1])})
    anchors = []
    for kind, term in clauses:
        row = connection.execute(
            "SELECT count FROM catalogue_search_counts WHERE kind=? AND term=?", (kind, term)
        ).fetchone()
        if row is None:
            table, column = (
                ("catalogue_search_terms", "token")
                if kind == "exact"
                else ("catalogue_search_prefixes", "prefix")
            )
            if (
                connection.execute(
                    f"SELECT 1 FROM {table} WHERE {column}=? LIMIT 1", (term,)
                ).fetchone()
                is not None
            ):
                raise ValueError("Discovery posting count is missing")
            if offset:
                raise InvalidSearchRequest("Invalid or expired search cursor")
            return SearchResult(status="not_found", **base, matched_count=0, ambiguous=False)
        if type(row[0]) is not int or not 1 <= row[0] <= manifest.indexed_products:
            raise ValueError("Invalid discovery count")
        anchors.append((row[0], kind, term))
    count, kind, term = min(anchors)
    if count > MAX_CANDIDATES:
        if offset:
            raise InvalidSearchRequest("Invalid or expired search cursor")
        return SearchResult(status="refine_query", **base, warnings=["search_query_too_broad"])
    table, column = (
        ("catalogue_search_terms", "token")
        if kind == "exact"
        else ("catalogue_search_prefixes", "prefix")
    )
    keys = connection.execute(
        f"SELECT barcode FROM {table} WHERE {column}=? ORDER BY barcode LIMIT ?",
        (term, MAX_CANDIDATES + 1),
    ).fetchmany(MAX_CANDIDATES + 1)
    if len(keys) != count or len(keys) > MAX_CANDIDATES:
        raise ValueError("Discovery count differs from postings")
    matches = []
    for (barcode,) in keys:
        compatible = True
        for other_kind, other_term in clauses:
            other_table, other_column = (
                ("catalogue_search_terms", "token")
                if other_kind == "exact"
                else ("catalogue_search_prefixes", "prefix")
            )
            if (
                connection.execute(
                    f"SELECT 1 FROM {other_table} WHERE {other_column}=? AND barcode=?",
                    (other_term, barcode),
                ).fetchone()
                is None
            ):
                compatible = False
                break
        if compatible:
            matches.append(barcode)
    if offset and offset >= len(matches):
        raise InvalidSearchRequest("Invalid or expired search cursor")
    from app.catalogue.store import _stored_json, _stored_warnings

    candidates = []
    for barcode in matches[offset : offset + limit]:
        row = connection.execute(
            "SELECT data FROM catalogue_products WHERE barcode=?", (barcode,)
        ).fetchone()
        if row is None:
            raise ValueError("Discovery identity is missing")
        data = _stored_json(row[0], expected_keys={"product", "warnings"})
        product = CatalogLookup.bounded_product(
            Product.model_validate(data["product"], strict=True)
        )
        assert product is not None
        if product.barcode != barcode:
            raise ValueError("Discovery identity disagrees with barcode")
        tokens = identity_tokens((product.name, product.brands, product.quantity_text))
        if any(t not in tokens for t in terms[:-1]) or not any(
            t.startswith(terms[-1]) for t in tokens
        ):
            raise ValueError("Discovery postings disagree with original identity")
        candidates.append(
            SearchCandidate(
                identity=SearchIdentity(
                    barcode=barcode,
                    name=product.name,
                    brands=product.brands,
                    quantity_text=product.quantity_text,
                ),
                source_id=f"off:{manifest.source_sha256}:{barcode}",
                warnings=[
                    "candidate_requires_identity_confirmation",
                    *_stored_warnings(data["warnings"]),
                ][:100],
            )
        )
    more = offset + limit < len(matches)
    return SearchResult(
        status="ready" if candidates else "not_found",
        **base,
        candidates=candidates,
        matched_count=len(matches),
        ambiguous=len(matches) > 1,
        next_cursor=_encode_cursor(scope, offset + limit) if more else None,
        warnings=["candidate_search_is_not_current_package_proof", "snapshot_age_needs_review"],
    )
