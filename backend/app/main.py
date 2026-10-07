import os
from contextlib import asynccontextmanager
from datetime import UTC, datetime
from pathlib import Path as FilePath
from typing import Annotated, cast

import httpx
from fastapi import FastAPI, Path, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.concurrency import run_in_threadpool

from app import __version__
from app.accounts.models import MAX_SNAPSHOT_BYTES
from app.api.v1.accounts import build_router as build_accounts_router
from app.api.v1.claims import build_router
from app.api.v1.community import CommunityRuntimeProtocol
from app.api.v1.community import build_router as build_community_router
from app.api.v1.reports import build_router as build_reports_router
from app.catalogue.facts import FactsLookup
from app.catalogue.models import CatalogLookup
from app.catalogue.search import (
    MAX_CURSOR_LENGTH,
    MAX_QUERY_LENGTH,
    InvalidSearchRequest,
    SearchResult,
    query_terms,
    validate_search_options,
)
from app.catalogue.status import CatalogueArtifact, CatalogueStatus, snapshot_freshness
from app.catalogue.store import CatalogueStore
from app.claims.knowledge import KnowledgeStore
from app.community.auth import AuthenticationUnavailable, create_runtime
from app.core.body_limit import RequestBodyLimit
from app.core.config import Settings
from app.providers.products.nutrition import NutritionProvider
from app.providers.products.open_food_facts import BARCODE_PATTERN, OpenFoodFactsProvider
from app.reports.glossary import GlossaryStore
from app.schemas.errors import ValidationFailure
from app.schemas.nutrition import NormalizeRequest
from app.schemas.nutrition_products import NormalizeResponse, NutritionLookup
from app.schemas.products import ProductLookup
from app.services.parsing.nutrition import normalize_rows


def create_app(
    settings: Settings | None = None,
    transport: httpx.AsyncBaseTransport | None = None,
    community_runtime: CommunityRuntimeProtocol | None = None,
) -> FastAPI:
    config = settings or Settings()
    knowledge_artifact = None
    try:
        knowledge_path = config.claims_knowledge_path()
        if (
            os.environ.get("VERCEL") == "1"
            or knowledge_path == FilePath(__file__).resolve().parent / "claims/data"
            or (knowledge_path / "receipt.json").exists()
        ):
            from app.claims.bundle import verify_knowledge_bundle

            knowledge_artifact = verify_knowledge_bundle(knowledge_path)
        claim_store = KnowledgeStore(knowledge_path)
    except (OSError, ValueError):
        claim_store = None
        knowledge_artifact = None

    try:
        glossary = GlossaryStore()
    except (OSError, ValueError):
        glossary = None

    @asynccontextmanager
    async def lifespan(application: FastAPI):
        async with httpx.AsyncClient(
            timeout=httpx.Timeout(config.off_timeout_seconds),
            follow_redirects=False,
            limits=httpx.Limits(max_connections=6, max_keepalive_connections=3),
            transport=transport,
        ) as client:
            application.state.products = OpenFoodFactsProvider(client, config)
            application.state.nutrition = NutritionProvider(application.state.products)
            application.state.catalogue = None
            application.state.catalogue_artifact = None
            application.state.community_runtime = None
            if config.community_enabled:
                if community_runtime is not None and config.community_actor_secret is not None:
                    application.state.community_runtime = community_runtime
                elif config.community_configured():
                    account = config.community_service_account_json
                    assert account is not None
                    try:
                        application.state.community_runtime = await run_in_threadpool(
                            create_runtime,
                            config.community_project_id,
                            config.community_database_id,
                            account.get_secret_value(),
                        )
                    except AuthenticationUnavailable:
                        pass
            directory = config.catalogue_path()
            if directory is not None:
                try:
                    artifact = None
                    if config.catalogue_require_receipt:
                        from app.catalogue.bundle import verify_bundle

                        receipt = verify_bundle(directory)
                        artifact = CatalogueArtifact.model_validate(
                            {key: receipt[key] for key in CatalogueArtifact.model_fields}
                        )
                    application.state.catalogue = CatalogueStore(directory)
                    application.state.catalogue_artifact = artifact
                except (ValueError, OSError):
                    pass  # Live endpoints remain usable; catalogue reports unavailable.
            try:
                yield
            finally:
                active = application.state.community_runtime
                if active is not None:
                    try:
                        await run_in_threadpool(active.close)
                    except Exception:
                        pass  # Shutdown failures must not expose backend credentials.

    application = FastAPI(
        title="Unlabel Backend",
        version=__version__,
        lifespan=lifespan,
        responses={422: {"model": ValidationFailure, "description": "Invalid request data"}},
    )
    application.include_router(build_router(store=claim_store))
    application.add_middleware(RequestBodyLimit)
    application.add_middleware(
        CORSMiddleware,
        allow_origins=config.cors_origins,
        allow_methods=["GET", "POST"],
        allow_headers=["Accept", "Content-Type", "Authorization"],
        allow_credentials=False,
    )

    @application.exception_handler(RequestValidationError)
    async def validation_error(request: Request, exc: RequestValidationError):
        # Do not echo submitted values, request bodies or arbitrary extra-field names.
        errors = []
        all_errors = exc.errors()
        for error in all_errors[:32]:
            location = list(error["loc"])
            if error["type"] == "extra_forbidden" and location:
                location[-1] = "<unknown_field>"
            errors.append({"loc": location, "type": error["type"], "msg": "Invalid request data"})
        return JSONResponse(
            {"detail": errors, "errors_truncated": len(all_errors) > 32},
            status_code=422,
            headers={"Cache-Control": "no-store"},
        )

    @application.get("/v1/health", tags=["Service"])
    async def health():
        return {
            "status": "ready",
            "backend_version": __version__,
            "provider_connectivity": "not_checked",
        }

    def catalogue_metadata(request: Request):
        directory = config.catalogue_path()
        if directory is None:
            return CatalogueStatus(status="not_configured")
        try:
            store = request.app.state.catalogue
            if store is None:
                return CatalogueStatus(status="unavailable")
            manifest = store.manifest
            field_limits = (
                [
                    "nutrition_direct_tables_only",
                    "images_are_source_urls_only",
                    "per_product_dates_may_be_missing",
                    "missing_allergen_tags_do_not_mean_allergen_free",
                ]
                if store.supports_facts
                else CatalogueStatus.model_fields["field_limits"].get_default(
                    call_default_factory=True
                )
            )
            return CatalogueStatus(
                status="ready",
                manifest=manifest,
                freshness=snapshot_freshness(manifest.exported_at),
                artifact=request.app.state.catalogue_artifact,
                field_limits=field_limits,
            )
        except (ValueError, OSError):
            return CatalogueStatus(status="unavailable")

    @application.get(
        "/v1/catalogue",
        response_model=CatalogueStatus,
        tags=["Catalogue"],
        responses={503: {"model": CatalogueStatus}},
    )
    def catalogue_status(request: Request):
        result = catalogue_metadata(request)
        return JSONResponse(
            result.model_dump(mode="json"),
            status_code=200 if result.status == "ready" else 503,
            headers={"Cache-Control": "no-store"},
        )

    @application.get("/v1/meta", tags=["Service"])
    def meta(request: Request):
        catalogue = catalogue_metadata(request).model_dump(mode="json")
        community_ready = request.app.state.community_runtime is not None
        return {
            "backend_version": __version__,
            "api_major": 1,
            "contract_schema": "1",
            "product_adapter_version": "1",
            "nutrition_adapter_version": "1",
            "normalization_version": "1",
            "report_version": "label-report-v1",
            "knowledge_version": claim_store.knowledge_version if claim_store else "not_populated",
            "knowledge_artifact": knowledge_artifact,
            "glossary": {
                "status": "ready" if glossary is not None else "unavailable",
                "version": glossary.version if glossary is not None else None,
                "artifact": glossary.artifact if glossary is not None else None,
            },
            "catalogue": catalogue,
            "community": {
                "status": "ready"
                if community_ready
                else "unavailable"
                if config.community_enabled
                else "not_configured",
                "provider_connectivity": "not_checked",
                "database_id": config.community_database_id if community_ready else None,
            },
            "account_sync": {
                "status": "ready"
                if config.account_sync_enabled and community_ready
                else "unavailable"
                if config.account_sync_enabled
                else "not_configured",
                "sync_version": "personal-sync-v1",
                "max_snapshot_bytes": MAX_SNAPSHOT_BYTES,
                "max_saved": 50,
                "max_history": 100,
                "authentication": "password",
            },
            "capabilities": {
                "product_lookup": True,
                "nutrition_lookup": True,
                "nutrition_normalization": True,
                "catalogue_lookup": catalogue["status"] == "ready",
                "catalogue_facts": catalogue["status"] == "ready"
                and request.app.state.catalogue.supports_facts,
                "catalogue_search": catalogue["status"] == "ready"
                and request.app.state.catalogue.supports_search,
                "nutrition_analysis": True,
                "label_reports": True,
                "claim_checks": claim_store is not None,
                "ingredient_explanations": glossary is not None,
                "comparison": False,
                "ai_explanations": False,
                "community_contributions": community_ready,
                "community_lookup": community_ready,
                "account_sync": config.account_sync_enabled and community_ready,
                "resolved_product_lookup": community_ready
                or (catalogue["status"] == "ready" and request.app.state.catalogue.supports_facts),
            },
        }

    def snapshot_result(request: Request, barcode: str, *, facts: bool = False):
        model = FactsLookup if facts else CatalogLookup
        if config.catalogue_path() is None:
            return model(
                requested_barcode=barcode,
                status="unavailable",
                warnings=["catalogue_not_configured"],
            )
        try:
            store = request.app.state.catalogue
            if store is None:
                raise ValueError("Catalogue unavailable")
            result = store.lookup_facts(barcode) if facts else store.lookup(barcode)
            artifact = request.app.state.catalogue_artifact
            if result.manifest is not None:
                if artifact is not None and (
                    result.manifest.snapshot_id != artifact.snapshot_id
                    or result.manifest.source_sha256 != artifact.source_sha256
                ):
                    raise ValueError("A bundled catalogue cannot change inside a deployment")
                freshness = snapshot_freshness(result.manifest.exported_at)
                warnings = list(result.warnings)
                additional_warnings = []
                if freshness.status == "refresh_due":
                    additional_warnings.append("snapshot_refresh_due")
                elif freshness.status == "source_date_in_future":
                    additional_warnings.append("snapshot_source_date_in_future")
                if result.manifest.coverage == "unverified":
                    additional_warnings.append("snapshot_coverage_unverified")
                for warning in additional_warnings:
                    if warning not in warnings and len(warnings) < 100:
                        warnings.append(warning)
                result = model.model_validate({**result.model_dump(), "warnings": warnings})
            return result
        except (ValueError, OSError):
            return model(
                requested_barcode=barcode, status="unavailable", warnings=["catalogue_unavailable"]
            )

    def snapshot_response(result):
        return JSONResponse(
            result.model_dump(mode="json"),
            status_code={"found": 200, "not_found": 404, "unavailable": 503}[result.status],
            headers={"Cache-Control": "no-store"},
        )

    @application.get(
        "/v1/catalogue/search",
        response_model=SearchResult,
        tags=["Catalogue"],
        responses={503: {"model": SearchResult}},
    )
    def catalogue_search(
        request: Request,
        q: Annotated[str, Query(min_length=1, max_length=MAX_QUERY_LENGTH)],
        limit: Annotated[int, Query(ge=1, le=20)] = 10,
        cursor: Annotated[str | None, Query(min_length=1, max_length=MAX_CURSOR_LENGTH)] = None,
    ):
        try:
            query, terms = query_terms(q)
            validate_search_options(limit, cursor)
            store = request.app.state.catalogue
            if store is None:
                result = SearchResult(
                    status="unavailable",
                    query=query,
                    normalized_query=" ".join(terms),
                    warnings=[
                        "catalogue_not_configured"
                        if config.catalogue_path() is None
                        else "catalogue_search_unavailable"
                    ],
                )
            else:
                result = store.search(query, limit=limit, cursor=cursor)
                artifact = request.app.state.catalogue_artifact
                if (
                    artifact is not None
                    and result.manifest is not None
                    and (
                        result.manifest.snapshot_id != artifact.snapshot_id
                        or result.manifest.source_sha256 != artifact.source_sha256
                    )
                ):
                    result = SearchResult(
                        status="unavailable",
                        query=query,
                        normalized_query=" ".join(terms),
                        warnings=["catalogue_search_unavailable"],
                    )
                elif result.manifest is not None:
                    freshness = snapshot_freshness(result.manifest.exported_at)
                    warnings = list(result.warnings)
                    if freshness.status == "refresh_due":
                        warnings.append("snapshot_refresh_due")
                    elif freshness.status == "source_date_in_future":
                        warnings.append("snapshot_source_date_in_future")
                    if result.manifest.coverage == "unverified":
                        warnings.append("snapshot_coverage_unverified")
                    result = result.model_copy(
                        update={"warnings": list(dict.fromkeys(warnings))[:100]}
                    )
        except InvalidSearchRequest as error:
            raise RequestValidationError(
                [{"loc": ("query", "search"), "type": "value_error", "msg": "Invalid request data"}]
            ) from error
        except (ValueError, OSError):
            query, terms = query_terms(q)
            result = SearchResult(
                status="unavailable",
                query=query,
                normalized_query=" ".join(terms),
                warnings=["catalogue_search_unavailable"],
            )
        return JSONResponse(
            result.model_dump(mode="json"),
            status_code=503 if result.status == "unavailable" else 200,
            headers={"Cache-Control": "no-store"},
        )

    @application.get(
        "/v1/catalogue/products/{barcode}/facts",
        response_model=FactsLookup,
        tags=["Catalogue"],
        responses={code: {"model": FactsLookup} for code in (404, 503)},
    )
    def catalogue_facts(request: Request, barcode: Annotated[str, Path(pattern=BARCODE_PATTERN)]):
        return snapshot_response(snapshot_result(request, barcode, facts=True))

    @application.get(
        "/v1/catalogue/products/{barcode}",
        response_model=CatalogLookup,
        tags=["Catalogue"],
        responses={code: {"model": CatalogLookup} for code in (404, 503)},
    )
    def catalogue_product(request: Request, barcode: Annotated[str, Path(pattern=BARCODE_PATTERN)]):
        # Sync routes run in FastAPI's thread pool; SQLite never blocks the event loop.
        return snapshot_response(snapshot_result(request, barcode))

    @application.get(
        "/v1/products/{barcode}",
        response_model=ProductLookup,
        tags=["Products"],
        responses={
            404: {"model": ProductLookup},
            429: {"model": ProductLookup},
            502: {"model": ProductLookup},
            503: {"model": ProductLookup},
        },
    )
    async def product(request: Request, barcode: Annotated[str, Path(pattern=BARCODE_PATTERN)]):
        result = await request.app.state.products.lookup(barcode)
        status_code = {
            "found": 200,
            "not_found": 404,
            "rate_limited": 429,
            "unavailable": 503,
            "incompatible_response": 502,
        }[result.status]
        return JSONResponse(
            result.model_dump(mode="json"),
            status_code=status_code,
            headers={"Cache-Control": "no-store"},
        )

    @application.get(
        "/v1/products/{barcode}/nutrition",
        response_model=NutritionLookup,
        tags=["Nutrition"],
        responses={code: {"model": NutritionLookup} for code in (404, 429, 502, 503)},
    )
    async def nutrition(request: Request, barcode: Annotated[str, Path(pattern=BARCODE_PATTERN)]):
        result = await request.app.state.nutrition.lookup(barcode)
        code = {
            "found": 200,
            "not_found": 404,
            "rate_limited": 429,
            "unavailable": 503,
            "incompatible_response": 502,
        }[result.status]
        return JSONResponse(
            result.model_dump(mode="json"), status_code=code, headers={"Cache-Control": "no-store"}
        )

    @application.post(
        "/v1/nutrition/normalize",
        response_model=NormalizeResponse,
        tags=["Nutrition"],
        responses={413: {"description": "Actual request body exceeds 32 KiB"}},
    )
    async def normalize(body: NormalizeRequest):
        result = NormalizeResponse(
            client_request_id=body.client_request_id,
            capture_session_id=body.capture_session_id,
            input_revision=body.input_revision,
            normalized_at=datetime.now(UTC),
            snapshot=normalize_rows(body.rows, completeness=body.completeness),
        )
        return JSONResponse(result.model_dump(mode="json"), headers={"Cache-Control": "no-store"})

    application.include_router(
        build_community_router(
            config=config,
            snapshot_lookup=lambda request, barcode: cast(
                FactsLookup, snapshot_result(request, barcode, facts=True)
            ),
            knowledge_version=claim_store.knowledge_version if claim_store else None,
        )
    )
    application.include_router(
        build_reports_router(
            config=config,
            snapshot_lookup=lambda request, barcode: cast(
                FactsLookup, snapshot_result(request, barcode, facts=True)
            ),
            claims_store=claim_store,
            glossary=glossary,
        )
    )
    application.include_router(build_accounts_router(config=config))
    return application


app = create_app()
