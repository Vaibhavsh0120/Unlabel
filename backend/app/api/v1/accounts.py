"""Optional owner-only private scanner snapshots. Login never gates product reads."""

from typing import Annotated, Any, Protocol, cast

from fastapi import APIRouter, Header, Request
from fastapi.responses import JSONResponse

from app.accounts.models import SyncFailure, SyncRequest, SyncSnapshot
from app.accounts.store import PersonalStore, SyncConflict, owner_hash
from app.community.auth import AuthenticationInvalid, AuthenticationUnavailable
from app.community.store import StoreQuotaExceeded, StoreUnavailable
from app.core.config import Settings


class AccountRuntime(Protocol):
    @property
    def personal_store(self) -> PersonalStore: ...
    def verify_account_token(self, token: str) -> str: ...


def failure(status: int, revision: int | None = None) -> JSONResponse:
    state, code = {
        401: ("unauthorized", "account_authentication_required"),
        409: ("conflict", "account_revision_conflict"),
        429: ("rate_limited", "account_sync_limit"),
        503: ("unavailable", "account_sync_unavailable"),
    }[status]
    result = SyncFailure.model_validate(
        {"status": state, "code": code, "current_revision": revision}
    )
    headers = {"Cache-Control": "no-store"}
    if status == 401:
        headers["WWW-Authenticate"] = "Bearer"
    return JSONResponse(result.model_dump(mode="json"), status_code=status, headers=headers)


def build_router(*, config: Settings) -> APIRouter:
    router = APIRouter(tags=["Optional private scanner sync"])
    errors: dict[int | str, dict[str, Any]] = {
        code: {"model": SyncFailure} for code in (401, 409, 429, 503)
    }

    def owner(request: Request, authorization: str | None) -> tuple[AccountRuntime, str]:
        runtime = request.app.state.community_runtime
        if (
            not config.account_sync_enabled
            or runtime is None
            or config.community_actor_secret is None
        ):
            raise StoreUnavailable()
        if authorization is None:
            raise AuthenticationInvalid()
        parts = authorization.split(" ")
        if len(parts) != 2 or parts[0].lower() != "bearer" or not 1 <= len(parts[1]) <= 8192:
            raise AuthenticationInvalid()
        active = cast(AccountRuntime, runtime)
        uid = active.verify_account_token(parts[1])
        return active, owner_hash(uid, config.community_actor_secret.get_secret_value())

    def mapped_error(error: Exception) -> JSONResponse:
        if isinstance(error, AuthenticationInvalid):
            return failure(401)
        if isinstance(error, SyncConflict):
            return failure(409, error.revision)
        if isinstance(error, StoreQuotaExceeded):
            return failure(429)
        return failure(503)

    @router.get("/v1/account/sync", response_model=SyncSnapshot, responses=errors)
    def read(
        request: Request, authorization: Annotated[str | None, Header(max_length=8199)] = None
    ):
        try:
            runtime, key = owner(request, authorization)
            result = runtime.personal_store.read(key)
        except (AuthenticationInvalid, AuthenticationUnavailable, StoreUnavailable) as error:
            return mapped_error(error)
        return JSONResponse(result.model_dump(mode="json"), headers={"Cache-Control": "no-store"})

    @router.post(
        "/v1/account/sync",
        response_model=SyncSnapshot,
        responses={**errors, 413: {"description": "Actual body exceeds 512 KiB"}},
    )
    def replace(
        request: Request,
        body: SyncRequest,
        authorization: Annotated[str | None, Header(max_length=8199)] = None,
    ):
        try:
            runtime, key = owner(request, authorization)
            result = runtime.personal_store.replace(key, body)
        except (
            AuthenticationInvalid,
            AuthenticationUnavailable,
            StoreUnavailable,
            StoreQuotaExceeded,
            SyncConflict,
        ) as error:
            return mapped_error(error)
        return JSONResponse(result.model_dump(mode="json"), headers={"Cache-Control": "no-store"})

    return router
