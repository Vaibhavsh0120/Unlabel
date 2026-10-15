"""Authenticated live display endpoint; anonymous scanner credentials are supported."""

import asyncio
from typing import Annotated

from fastapi import APIRouter, Header, Path, Request
from fastapi.responses import JSONResponse
from starlette.concurrency import run_in_threadpool

from app.community.auth import AuthenticationInvalid, AuthenticationUnavailable
from app.community.service import actor_hash
from app.core.config import Settings
from app.live_products.models import LiveLookup
from app.live_products.nutrigraph import NutriGraphLookup


def build_router(config: Settings) -> APIRouter:
    router = APIRouter(tags=["Live external product facts"])

    @router.get("/v1/live-products/nutrigraph/{barcode}", response_model=LiveLookup)
    async def lookup(
        request: Request,
        barcode: Annotated[str, Path(pattern=r"^(?:[0-9]{8}|[0-9]{12,14})$")],
        authorization: Annotated[str | None, Header(max_length=8199)] = None,
    ):
        headers = {"Cache-Control": "no-store"}
        provider: NutriGraphLookup | None = request.app.state.nutrigraph
        if provider is None:
            return JSONResponse(LiveLookup(status="disabled", requested_barcode=barcode)
                                .model_dump(mode="json"), headers=headers)
        try:
            runtime = request.app.state.community_runtime
            secret = config.community_actor_secret
            if runtime is None or secret is None:
                raise AuthenticationUnavailable()
            parts = authorization.split(" ") if authorization else []
            if len(parts) != 2 or parts[0].lower() != "bearer" or not parts[1]:
                raise AuthenticationInvalid()
            async with asyncio.timeout(5):
                subject = await run_in_threadpool(runtime.verify_token, parts[1])
            owner = actor_hash(subject, secret.get_secret_value())
            result = await provider.lookup(barcode, owner)
            return JSONResponse(result.model_dump(mode="json"), headers=headers)
        except AuthenticationInvalid:
            return JSONResponse({"status": "unavailable", "code": "scanner_authentication_required"},
                                status_code=401, headers={**headers, "WWW-Authenticate": "Bearer"})
        except (AuthenticationUnavailable, TimeoutError):
            return JSONResponse({"status": "unavailable", "code": "live_lookup_unavailable"},
                                status_code=503, headers=headers)

    return router
