from contextlib import asynccontextmanager
from typing import Annotated

import httpx
from fastapi import FastAPI, Path, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app import __version__
from app.core.config import Settings
from app.providers.products.open_food_facts import BARCODE_PATTERN, OpenFoodFactsProvider
from app.schemas.products import ProductLookup


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
            yield

    application = FastAPI(title="Unlabel Backend", version=__version__, lifespan=lifespan)
    application.add_middleware(
        CORSMiddleware,
        allow_origins=config.cors_origins,
        allow_methods=["GET"],
        allow_headers=["Accept"],
        allow_credentials=False,
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
            "knowledge_version": "not_populated",
            "capabilities": {
                "product_lookup": True,
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

    return application


app = create_app()
