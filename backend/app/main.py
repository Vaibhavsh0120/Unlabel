from contextlib import asynccontextmanager
from datetime import UTC, datetime
from typing import Annotated

import httpx
from fastapi import FastAPI, Path, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app import __version__
from app.core.body_limit import RequestBodyLimit
from app.core.config import Settings
from app.providers.products.nutrition import NutritionProvider
from app.providers.products.open_food_facts import BARCODE_PATTERN, OpenFoodFactsProvider
from app.schemas.nutrition import NormalizeRequest
from app.schemas.nutrition_products import NormalizeResponse, NutritionLookup
from app.schemas.products import ProductLookup
from app.services.parsing.nutrition import normalize_rows


def create_app(
    settings: Settings | None = None, transport: httpx.AsyncBaseTransport | None = None
) -> FastAPI:
    config = settings or Settings()

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
            yield

    application = FastAPI(title="Unlabel Backend", version=__version__, lifespan=lifespan)
    application.add_middleware(RequestBodyLimit)
    application.add_middleware(
        CORSMiddleware,
        allow_origins=config.cors_origins,
        allow_methods=["GET", "POST"],
        allow_headers=["Accept", "Content-Type"],
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

    @application.get("/v1/meta", tags=["Service"])
    async def meta():
        return {
            "backend_version": __version__,
            "api_major": 1,
            "contract_schema": "1",
            "product_adapter_version": "1",
            "nutrition_adapter_version": "1",
            "normalization_version": "1",
            "knowledge_version": "not_populated",
            "capabilities": {
                "product_lookup": True,
                "nutrition_lookup": True,
                "nutrition_normalization": True,
                "nutrition_analysis": False,
                "claim_checks": False,
                "ingredient_explanations": False,
                "comparison": False,
                "ai_explanations": False,
            },
        }

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

    return application


app = create_app()
