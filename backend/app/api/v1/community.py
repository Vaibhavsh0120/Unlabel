"""Bounded community HTTP access; synchronous provider work uses FastAPI's pool."""

from collections.abc import Callable
from typing import Annotated, Any, Protocol
from uuid import UUID

from fastapi import APIRouter, Header, Path, Request
from fastapi.responses import JSONResponse

from app.catalogue.facts import FactsLookup
from app.community.auth import AuthenticationInvalid, AuthenticationUnavailable
from app.community.models import (
    CommunityFailure,
    CommunityLookup,
    ContributionReceipt,
    ContributionRequest,
    ResolvedProduct,
)
from app.community.resolver import resolve_product
from app.community.service import actor_hash, prepare_submission
from app.community.store import (
    ContributionStore,
    StoreConflict,
    StoreQuotaExceeded,
    StoreUnavailable,
)
from app.core.config import Settings
from app.providers.products.open_food_facts import BARCODE_PATTERN


class CommunityRuntimeProtocol(Protocol):
    @property
    def store(self) -> ContributionStore: ...

    def verify_token(self, token: str) -> str: ...

    def close(self) -> None: ...


def failure(status_code: int, code: str) -> JSONResponse:
    result = CommunityFailure.model_validate(
        {
            "status": {
                401: "unauthorized",
                404: "not_found",
                409: "conflict",
                429: "rate_limited",
                503: "unavailable",
            }[status_code],
            "code": code,
        }
    )
    headers = {"Cache-Control": "no-store"}
    if status_code == 401:
        headers["WWW-Authenticate"] = "Bearer"
    return JSONResponse(result.model_dump(mode="json"), status_code=status_code, headers=headers)


def build_router(
    *,
    config: Settings,
    snapshot_lookup: Callable[[Request, str], FactsLookup],
    knowledge_version: str | None,
) -> APIRouter:
    router = APIRouter(tags=["Community product catalogue"])
    errors: dict[int | str, dict[str, Any]] = {
        code: {"model": CommunityFailure} for code in (401, 404, 409, 429, 503)
    }

    def runtime(request: Request) -> CommunityRuntimeProtocol | None:
        return request.app.state.community_runtime if config.community_enabled else None

    def owner(active: CommunityRuntimeProtocol, authorization: str | None) -> str:
        if authorization is None:
            raise AuthenticationInvalid()
        parts = authorization.split(" ")
        if len(parts) != 2 or parts[0].lower() != "bearer" or not 1 <= len(parts[1]) <= 8192:
            raise AuthenticationInvalid()
        secret = config.community_actor_secret
        if secret is None:
            raise AuthenticationUnavailable()
        subject = active.verify_token(parts[1])
        return actor_hash(subject, secret.get_secret_value())

    def mapped_error(error: Exception) -> JSONResponse:
        if isinstance(error, AuthenticationInvalid):
            return failure(401, "anonymous_authentication_required")
        if isinstance(error, (AuthenticationUnavailable, StoreUnavailable)):
            return failure(503, "community_unavailable")
        if isinstance(error, StoreQuotaExceeded):
            return failure(429, "community_admission_limit")
        return failure(409, "community_content_conflict")

    @router.post(
        "/v1/community/contributions",
        response_model=ContributionReceipt,
        responses={**errors, 413: {"description": "Actual body exceeds 32 KiB"}},
    )
    def contribute(
        request: Request,
        body: ContributionRequest,
        authorization: Annotated[str | None, Header(max_length=8199)] = None,
    ):
        active = runtime(request)
        if active is None:
            return failure(503, "community_not_available")
        try:
            actor = owner(active, authorization)
            baseline = snapshot_lookup(request, body.barcode) if body.barcode is not None else None
            # Storage revalidates references for new records after checking immutable
            # retries; a replaced/offline snapshot must not invalidate an old receipt.
            prepared = prepare_submission(body)
            result = active.store.submit(actor, prepared, baseline=baseline)
        except (
            AuthenticationInvalid,
            AuthenticationUnavailable,
            StoreUnavailable,
            StoreQuotaExceeded,
            StoreConflict,
        ) as error:
            return mapped_error(error)
        except ValueError:
            return failure(409, "community_facts_need_correction")
        return JSONResponse(result.model_dump(mode="json"), headers={"Cache-Control": "no-store"})

    @router.get(
        "/v1/community/contributions/{submission_id}",
        response_model=ContributionReceipt,
        responses=errors,
    )
    def receipt(
        request: Request,
        submission_id: Annotated[
            str,
            Path(
                min_length=36,
                max_length=36,
                pattern=r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
            ),
        ],
        authorization: Annotated[str | None, Header(max_length=8199)] = None,
    ):
        active = runtime(request)
        if active is None:
            return failure(503, "community_not_available")
        try:
            result = active.store.receipt(owner(active, authorization), UUID(submission_id))
        except (
            AuthenticationInvalid,
            AuthenticationUnavailable,
            StoreUnavailable,
            StoreQuotaExceeded,
            StoreConflict,
        ) as error:
            return mapped_error(error)
        if result is None:
            return failure(404, "owned_submission_not_found")
        return JSONResponse(result.model_dump(mode="json"), headers={"Cache-Control": "no-store"})

    @router.get(
        "/v1/community/products/{barcode}",
        response_model=CommunityLookup,
        responses={
            404: {"model": CommunityLookup},
            409: {"model": CommunityFailure},
            429: {"model": CommunityFailure},
            503: {"model": CommunityFailure},
        },
    )
    def product(request: Request, barcode: Annotated[str, Path(pattern=BARCODE_PATTERN)]):
        active = runtime(request)
        if active is None:
            return failure(503, "community_not_available")
        try:
            result = active.store.lookup(barcode)
        except (StoreUnavailable, StoreQuotaExceeded, StoreConflict) as error:
            return mapped_error(error)
        if result.status == "unavailable":
            return failure(503, "community_unavailable")
        return JSONResponse(
            result.model_dump(mode="json"),
            status_code={"found": 200, "not_found": 404, "unavailable": 503}[result.status],
            headers={"Cache-Control": "no-store"},
        )

    @router.get(
        "/v1/products/{barcode}/resolved",
        response_model=ResolvedProduct,
        responses={
            404: {"model": ResolvedProduct},
            409: {"model": CommunityFailure},
            429: {"model": CommunityFailure},
            503: {"model": CommunityFailure},
        },
    )
    def resolved(request: Request, barcode: Annotated[str, Path(pattern=BARCODE_PATTERN)]):
        active = runtime(request)
        try:
            community = (
                active.store.lookup(barcode)
                if active is not None
                else CommunityLookup(
                    requested_barcode=barcode,
                    status="unavailable",
                    warnings=["community_not_configured"],
                )
            )
        except StoreUnavailable:
            community = CommunityLookup(
                requested_barcode=barcode,
                status="unavailable",
                warnings=["community_unavailable"],
            )
        except (StoreQuotaExceeded, StoreConflict) as error:
            return mapped_error(error)
        try:
            snapshot = snapshot_lookup(request, barcode)
            result = resolve_product(snapshot, community, knowledge_version=knowledge_version)
        except (StoreUnavailable, StoreQuotaExceeded, StoreConflict) as error:
            return mapped_error(error)
        status_code = 200 if community.status == "found" or snapshot.status == "found" else 404
        if community.status == "unavailable" or snapshot.status == "unavailable":
            if status_code != 200:
                return failure(503, "product_sources_unavailable")
        return JSONResponse(
            result.model_dump(mode="json"),
            status_code=status_code,
            headers={"Cache-Control": "no-store"},
        )

    return router
