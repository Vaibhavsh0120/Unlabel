"""Read-only routes for named researched products with explicit source evidence."""

from collections.abc import Callable
from typing import Annotated

from fastapi import APIRouter, Path, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.catalogue.search import InvalidSearchRequest
from app.research_catalogue.models import (
    BARCODE_PATTERN,
    HASH_PATTERN,
    ResearchBarcodeLookup,
    ResearchLookup,
    ResearchSearchResult,
)
from app.research_catalogue.store import (
    InvalidResearchCursor,
    ResearchCatalogueStore,
    research_query_terms,
)


def _payload(result: ResearchSearchResult | ResearchLookup | ResearchBarcodeLookup):
    data = result.model_dump()
    if isinstance(result, ResearchLookup) and result.observation is not None:
        # Response envelope defaults are explicit; source records retain exactly
        # the acquired keys so the immutable observation hash remains meaningful.
        data["observation"] = result.observation.model_dump(exclude_unset=True)
    return data


def build_router(get_store: Callable[[Request], ResearchCatalogueStore | None]) -> APIRouter:
    router = APIRouter(prefix="/v1/researched/products", tags=["Researched product catalogue"])

    @router.get(
        "/search",
        response_model=ResearchSearchResult,
        responses={503: {"model": ResearchSearchResult}},
    )
    def search(
        request: Request,
        q: Annotated[str, Query(min_length=1, max_length=128)],
        limit: Annotated[int, Query(ge=1, le=20)] = 10,
        cursor: Annotated[str | None, Query(min_length=1, max_length=256)] = None,
    ):
        try:
            query, terms = research_query_terms(q)
            store = get_store(request)
            result = (
                store.search(query, limit=limit, cursor=cursor)
                if store is not None
                else ResearchSearchResult(
                    status="unavailable",
                    dataset_sha256=None,
                    query=query,
                    normalized_query=" ".join(terms),
                    warnings=["research_catalogue_unavailable"],
                )
            )
        except (InvalidSearchRequest, InvalidResearchCursor) as error:
            raise RequestValidationError(
                [{"loc": ("query", "search"), "type": "value_error", "msg": "Invalid request data"}]
            ) from error
        except ValueError:
            result = ResearchSearchResult(
                status="unavailable",
                dataset_sha256=None,
                query=q,
                normalized_query=" ".join(research_query_terms(q)[1]),
                warnings=["research_catalogue_unavailable"],
            )
        except OSError:
            result = ResearchSearchResult(
                status="unavailable",
                dataset_sha256=None,
                query=q,
                normalized_query=" ".join(research_query_terms(q)[1]),
                warnings=["research_catalogue_unavailable"],
            )
        return JSONResponse(
            _payload(result),
            status_code=503 if result.status == "unavailable" else 200,
            headers={"Cache-Control": "no-store"},
        )

    @router.get(
        "/by-barcode/{barcode}",
        response_model=ResearchBarcodeLookup,
        responses={code: {"model": ResearchBarcodeLookup} for code in (404, 503)},
    )
    def barcode_lookup(request: Request, barcode: Annotated[str, Path(pattern=BARCODE_PATTERN)]):
        try:
            store = get_store(request)
            result = (
                store.by_barcode(barcode)
                if store is not None
                else ResearchBarcodeLookup(
                    status="unavailable",
                    barcode=barcode,
                    dataset_sha256=None,
                    warnings=["research_catalogue_unavailable"],
                )
            )
        except (ValueError, OSError):
            result = ResearchBarcodeLookup(
                status="unavailable",
                barcode=barcode,
                dataset_sha256=None,
                warnings=["research_catalogue_unavailable"],
            )
        return JSONResponse(
            _payload(result),
            status_code={"found": 200, "not_found": 404, "unavailable": 503}[result.status],
            headers={"Cache-Control": "no-store"},
        )

    @router.get(
        "/{entry_id}",
        response_model=ResearchLookup,
        responses={code: {"model": ResearchLookup} for code in (404, 503)},
    )
    def lookup(request: Request, entry_id: Annotated[str, Path(pattern=HASH_PATTERN)]):
        try:
            store = get_store(request)
            result = (
                store.lookup(entry_id)
                if store is not None
                else ResearchLookup(
                    status="unavailable",
                    entry_id=entry_id,
                    dataset_sha256=None,
                    warnings=["research_catalogue_unavailable"],
                )
            )
        except (ValueError, OSError):
            result = ResearchLookup(
                status="unavailable",
                entry_id=entry_id,
                dataset_sha256=None,
                warnings=["research_catalogue_unavailable"],
            )
        return JSONResponse(
            _payload(result),
            status_code={"found": 200, "not_found": 404, "unavailable": 503}[result.status],
            headers={"Cache-Control": "no-store"},
        )

    return router
