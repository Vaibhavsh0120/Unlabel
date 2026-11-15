"""PostgreSQL product read model and immutable MongoDB research repository."""

import hashlib
import json
from contextlib import contextmanager

import psycopg
from pymongo.errors import PyMongoError

from app.catalogue.facts import FactsLookup, ProductFacts
from app.catalogue.models import CatalogLookup, Manifest, validate_barcode
from app.catalogue.search import (
    InvalidSearchRequest,
    SearchCandidate,
    SearchIdentity,
    SearchResult,
    _cursor_scope,
    _decode_cursor,
    _encode_cursor,
    query_terms,
    validate_search_options,
)
from app.research_catalogue.models import (
    ResearchBarcodeLookup,
    ResearchImage,
    ResearchLookup,
    ResearchObservation,
    ResearchSearchResult,
)
from app.research_catalogue.store import (
    WARNINGS,
    InvalidResearchCursor,
    _candidate,
    _cursor,
    _tokens,
    research_query_terms,
)
from app.schemas.products import Product


@contextmanager
def read_connection(pool):
    try:
        with pool.connection() as connection:
            yield connection
    except psycopg.Error:
        raise OSError("Catalogue database unavailable") from None


def canonical(value):
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False
    ).encode()


def tsquery(terms):
    # Native tsquery literals preserve already-normalized Indic marks. SQL remains
    # parameterized; no user input is interpolated into SQL source.
    return " & ".join(
        "'"
        + term.replace("\\", "\\\\").replace("'", "''")
        + "'"
        + (":*" if index == len(terms) - 1 else "")
        for index, term in enumerate(terms)
    )


class PostgresCatalogue:
    supports_facts = True
    supports_search = True

    def __init__(self, pool):
        self.pool = pool

    @staticmethod
    def _manifest(connection):
        row = connection.execute("""SELECT b.receipt FROM catalogue.active_snapshot a
            JOIN catalogue.source_bundles b ON b.sha256=a.bundle_sha256""").fetchone()
        if not row:
            raise ValueError("Catalogue has not passed import verification")
        return Manifest.model_validate_json(json.dumps(row[0]))

    @property
    def manifest(self):
        with read_connection(self.pool) as connection:
            return self._manifest(connection)

    def lookup(self, barcode):
        result = self.lookup_facts(barcode)
        return CatalogLookup(
            requested_barcode=barcode,
            status=result.status,
            manifest=result.manifest,
            product=result.product,
            warnings=result.warnings,
        )

    def lookup_facts(self, barcode):
        validate_barcode(barcode)
        with read_connection(self.pool) as connection:
            connection.execute("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY")
            manifest = self._manifest(connection)
            row = connection.execute(
                """SELECT identity,facts FROM catalogue.products
                WHERE barcode=%s AND bundle_sha256=%s""",
                (barcode, manifest.source_sha256),
            ).fetchone()
            if not row:
                return FactsLookup(
                    requested_barcode=barcode,
                    status="not_found",
                    manifest=manifest,
                    warnings=["snapshot_age_needs_review"],
                )
            identity, facts = row
            return FactsLookup(
                requested_barcode=barcode,
                status="found",
                manifest=manifest,
                product=Product.model_validate(identity["product"], strict=True),
                details=ProductFacts.model_validate_json(json.dumps(facts["details"])),
                warnings=list(dict.fromkeys(identity["warnings"] + facts["warnings"]))[:100],
            )

    def search(self, query, *, limit=10, cursor=None):
        query, terms = query_terms(query)
        validate_search_options(limit, cursor)
        with read_connection(self.pool) as connection:
            connection.execute("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY")
            manifest = self._manifest(connection)
            scope = _cursor_scope(manifest, terms, limit)
            offset = _decode_cursor(cursor, scope)
            rows = connection.execute(
                """SELECT barcode,identity FROM catalogue.products
                WHERE bundle_sha256=%s AND search_vector @@ %s::tsquery
                ORDER BY barcode LIMIT 1001""",
                (manifest.source_sha256, tsquery(terms)),
            ).fetchall()
        base = dict(query=query, normalized_query=" ".join(terms), manifest=manifest)
        if len(rows) > 1000:
            if cursor:
                raise InvalidSearchRequest("Expired search cursor")
            return SearchResult(status="refine_query", **base, warnings=["search_query_too_broad"])
        if offset and offset >= len(rows):
            raise InvalidSearchRequest("Expired search cursor")
        candidates = []
        for barcode, identity in rows[offset : offset + limit]:
            product = Product.model_validate(identity["product"], strict=True)
            candidates.append(
                SearchCandidate(
                    identity=SearchIdentity(
                        barcode=barcode,
                        name=product.name,
                        brands=product.brands,
                        quantity_text=product.quantity_text,
                    ),
                    source_id=f"off:{manifest.source_sha256}:{barcode}",
                    warnings=["candidate_requires_identity_confirmation", *identity["warnings"]][
                        :100
                    ],
                )
            )
        return SearchResult(
            status="ready" if rows else "not_found",
            **base,
            candidates=candidates,
            matched_count=len(rows),
            ambiguous=len(rows) > 1,
            next_cursor=_encode_cursor(scope, offset + limit)
            if offset + limit < len(rows)
            else None,
            warnings=["candidate_search_is_not_current_package_proof", "snapshot_age_needs_review"],
        )


class MongoResearch:
    def __init__(self, database, pool):
        self.collection = database.research_observations
        self.pool = pool

    def _receipt(self):
        with read_connection(self.pool) as connection:
            row = connection.execute("""SELECT receipt FROM catalogue.dataset_receipts
                WHERE dataset_id='research-v1'""").fetchone()
        if not row:
            raise ValueError("Research import is not verified")
        return row[0]

    def status(self):
        receipt = self._receipt()
        return dict(
            status="ready",
            dataset_sha256=receipt["decoded_sha256"],
            observation_count=receipt["observation_count"],
            storage_engine="mongodb",
            search_version="research-search-v1",
            warnings=WARNINGS,
        )

    @staticmethod
    def _checked(document):
        raw = document["observation"]
        result = ResearchObservation.model_validate(raw)
        if (
            result.observation_id != document["_id"]
            or hashlib.sha256(canonical(raw)).hexdigest() != document["content_sha256"]
        ):
            raise ValueError("Immutable research record failed its content check")
        return result

    def _originals(self, entry_ids):
        if not entry_ids:
            return {}
        try:
            originals = {
                document["_id"]: document
                for document in self.collection.find({"_id": {"$in": entry_ids}})
            }
        except PyMongoError:
            raise OSError("Immutable evidence unavailable") from None
        if len(originals) != len(entry_ids):
            raise ValueError("Immutable evidence missing for its projection")
        return originals

    def lookup(self, entry_id):
        if len(entry_id) != 64 or any(
            character not in "0123456789abcdef" for character in entry_id
        ):
            raise ValueError("Invalid immutable observation ID")
        receipt = self._receipt()
        with read_connection(self.pool) as connection:
            projection = connection.execute(
                """SELECT s.dataset_sha256,s.conflict_fields,d.receipt
                FROM catalogue.research_search s JOIN catalogue.research_datasets d
                ON d.sha256=s.dataset_sha256 WHERE s.entry_id=%s
                ORDER BY (s.dataset_sha256=%s) DESC,s.dataset_sha256 LIMIT 1""",
                (entry_id, receipt["decoded_sha256"]),
            ).fetchone()
        document = self._originals([entry_id])[entry_id] if projection else None
        if projection:
            receipt = projection[2]
        observation = self._checked(document) if document else None
        image = None
        if observation:
            with read_connection(self.pool) as connection:
                row = connection.execute(
                    """SELECT source_reference FROM catalogue.image_descriptors
                    WHERE descriptor_id=%s""",
                    (entry_id,),
                ).fetchone()
            if row:
                candidate = ResearchImage.model_validate(row[0])
                if (
                    candidate.source_url == observation.source.url
                    and candidate.provider == observation.source.provider
                ):
                    image = candidate
        return ResearchLookup(
            status="found" if document else "not_found",
            entry_id=entry_id,
            dataset_sha256=receipt["decoded_sha256"],
            observation=observation,
            image=image,
            conflict_fields=projection[1] if document else [],
            warnings=WARNINGS,
        )

    def by_barcode(self, barcode):
        validate_barcode(barcode)
        receipt = self._receipt()
        with read_connection(self.pool) as connection:
            projections = connection.execute(
                """SELECT entry_id,conflict_fields
                FROM catalogue.research_search WHERE dataset_sha256=%s AND eligible_barcode=%s
                ORDER BY entry_id LIMIT 21""",
                (receipt["decoded_sha256"], barcode),
            ).fetchall()
        if len(projections) > 20:
            raise ValueError("Too many exact research alternatives")
        documents = self._originals([row[0] for row in projections])
        return ResearchBarcodeLookup(
            status="found" if documents else "not_found",
            barcode=barcode,
            dataset_sha256=receipt["decoded_sha256"],
            warnings=WARNINGS,
            candidates=[
                _candidate(self._checked(documents[entry_id]), conflicts)
                for entry_id, conflicts in projections
            ],
        )

    def search(self, query, *, limit=10, cursor=None):
        query, terms = research_query_terms(query)
        validate_search_options(limit, cursor)
        receipt = self._receipt()
        scope = hashlib.sha256(
            canonical(["mongo-research-v1", receipt["decoded_sha256"], terms, limit])
        ).hexdigest()
        try:
            offset = _decode_cursor(cursor, scope)
        except InvalidSearchRequest:
            raise InvalidResearchCursor("Invalid research cursor") from None
        with read_connection(self.pool) as connection:
            projections = connection.execute(
                """SELECT entry_id,conflict_fields
                FROM catalogue.research_search WHERE dataset_sha256=%s
                AND search_vector @@ %s::tsquery ORDER BY name_sort,entry_id LIMIT 1001""",
                (receipt["decoded_sha256"], tsquery(terms)),
            ).fetchall()
        documents = projections
        if len(documents) > 1000:
            return ResearchSearchResult(
                status="refine_query",
                dataset_sha256=receipt["decoded_sha256"],
                query=query,
                normalized_query=" ".join(terms),
                warnings=WARNINGS,
            )
        if offset and offset >= len(documents):
            raise InvalidResearchCursor("Expired research cursor")
        candidates = []
        page = documents[offset : offset + limit]
        originals = self._originals([row[0] for row in page])
        for entry_id, conflicts in page:
            observation = self._checked(originals[entry_id])
            tokens = _tokens(observation)
            if any(term not in tokens for term in terms[:-1]) or not any(
                token.startswith(terms[-1]) for token in tokens
            ):
                raise ValueError("Research index differs from immutable evidence")
            candidates.append(_candidate(observation, conflicts))
        return ResearchSearchResult(
            status="ready" if candidates else "not_found",
            dataset_sha256=receipt["decoded_sha256"],
            query=query,
            normalized_query=" ".join(terms),
            candidates=candidates,
            matched_count=len(documents),
            next_cursor=_cursor(scope, offset + limit) if offset + limit < len(documents) else None,
            warnings=WARNINGS,
        )
