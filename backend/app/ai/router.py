"""Scanner authentication and machine-only global AI controls."""

import asyncio
import hmac
from datetime import UTC, datetime
from typing import Annotated, Literal

from fastapi import APIRouter, Header, Path, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field
from starlette.concurrency import run_in_threadpool

from app.ai.admission import automatic_contribution, known_baseline
from app.ai.gateway import AiGateway
from app.ai.models import ExtractedLabel, ExtractionRequest
from app.ai.observations import (
    MachineContribution,
    MachineObservationLookup,
    comparison_values,
    compatible_identity,
    conflict_fields,
)
from app.ai.providers import ProviderFailure
from app.ai.staging import StagingResult
from app.ai.store import AiSelectionConflict
from app.community.auth import AuthenticationInvalid, AuthenticationUnavailable
from app.community.service import actor_hash
from app.community.store import StoreQuotaExceeded, StoreUnavailable
from app.core.config import Settings


class ActivateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    credential_id: str = Field(pattern=r"^[a-z][a-z0-9-]{0,47}$")
    expected_revision: int = Field(ge=1, le=2**53 - 2)


class ActiveResponse(BaseModel):
    status: Literal["ready", "unavailable"]
    scope: Literal["global"] = "global"
    credential_id: str
    provider: Literal["gemini", "openai"] | None
    model: str | None
    revision: int
    configuration_matches: bool
    retry_after: int


class ProviderSelection(BaseModel):
    scope: Literal["global"] = "global"
    provider: Literal["gemini", "openai"]
    model: str
    revision: int


class ActivationResponse(BaseModel):
    status: Literal["ready"] = "ready"
    scope: Literal["global"] = "global"
    credential_id: str
    provider: Literal["gemini", "openai"]
    model: str
    revision: int


class ExtractionResponse(BaseModel):
    status: Literal["extracted"] = "extracted"
    extraction: ExtractedLabel
    ai: ProviderSelection
    storage: StagingResult
    contribution: MachineContribution


def failure(status: int, code: str, *, retry_after: int | None = None) -> JSONResponse:
    headers = {"Cache-Control": "no-store"}
    if retry_after is not None:
        headers["Retry-After"] = str(retry_after)
    if status == 401:
        headers["WWW-Authenticate"] = "Bearer"
    return JSONResponse({"status": "unavailable", "code": code}, status_code=status, headers=headers)


def build_router(config: Settings) -> APIRouter:
    router = APIRouter(tags=["Automatic label extraction"])

    def gateway(request: Request) -> AiGateway | None:
        return request.app.state.ai_gateway if config.ai_enabled else None

    def machine_failure(authorization: str | None) -> JSONResponse | None:
        secret = config.ai_control_secret
        if secret is None:
            return failure(503, "ai_control_not_configured")
        parts = authorization.split(" ") if authorization else []
        supplied = parts[1] if len(parts) == 2 and parts[0].lower() == "bearer" else ""
        if not hmac.compare_digest(supplied.encode(), secret.get_secret_value().encode()):
            return failure(401, "machine_authorization_required")
        return None

    @router.get("/v1/ai/active", response_model=ActiveResponse)
    async def active(
        request: Request,
        authorization: Annotated[str | None, Header(max_length=8199)] = None,
    ):
        denied = machine_failure(authorization)
        if denied is not None:
            return denied
        selected = gateway(request)
        if selected is None:
            return failure(503, "ai_not_configured")
        try:
            current = await selected.selection()
            credential = selected.by_id.get(current.credential_id)
            until = current.blocked_until.get(current.credential_id)
            configured = current.configuration == selected.configuration and credential is not None
            available = configured and (until is None or until <= datetime.now(UTC))
            return JSONResponse({
                "status": "ready" if available else "unavailable",
                "scope": "global",
                "credential_id": current.credential_id,
                "provider": credential.provider if credential else None,
                "model": credential.model if credential else None,
                "revision": current.revision,
                "configuration_matches": configured,
                "retry_after": max(0, int((until - datetime.now(UTC)).total_seconds())) if until else 0,
            }, headers={"Cache-Control": "no-store"})
        except StoreUnavailable:
            return failure(503, "ai_selection_unavailable")

    @router.post("/v1/ai/control/activate", response_model=ActivationResponse)
    async def activate(
        request: Request, body: ActivateRequest,
        authorization: Annotated[str | None, Header(max_length=8199)] = None,
    ):
        # This service credential is not a scanner/admin account or a client key.
        denied = machine_failure(authorization)
        if denied is not None:
            return denied
        selected = gateway(request)
        if selected is None:
            return failure(503, "ai_not_configured")
        if body.credential_id not in selected.by_id:
            return failure(422, "credential_not_configured")
        try:
            current = await run_in_threadpool(
                selected.store.activate, body.credential_id, body.expected_revision,
                selected.initial_credential_id, selected.configuration,
            )
            value = selected.by_id[current.credential_id]
            return JSONResponse({
                "status": "ready", "scope": "global", "credential_id": current.credential_id,
                "provider": value.provider, "model": value.model, "revision": current.revision,
            }, headers={"Cache-Control": "no-store"})
        except AiSelectionConflict:
            return failure(409, "ai_selection_changed")
        except StoreUnavailable:
            return failure(503, "ai_selection_unavailable")

    @router.post("/v1/ai/extract", response_model=ExtractionResponse)
    async def extract_label(
        request: Request, body: ExtractionRequest,
        authorization: Annotated[str | None, Header(max_length=8199)] = None,
    ):
        selected = gateway(request)
        runtime = request.app.state.community_runtime
        if selected is None or runtime is None:
            return failure(503, "ai_not_configured")
        try:
            parts = authorization.split(" ") if authorization else []
            if len(parts) != 2 or parts[0].lower() != "bearer" or not parts[1]:
                raise AuthenticationInvalid()
            secret = config.community_actor_secret
            if secret is None:
                raise AuthenticationUnavailable()
            async with asyncio.timeout(5):
                subject = await run_in_threadpool(runtime.verify_token, parts[1])
            owner = actor_hash(subject, secret.get_secret_value())
            # Leave time for a sanitized response before the 60-second host limit.
            async with asyncio.timeout(42):
                result, selection = await selected.extract(owner, body)
            value = selected.by_id[selection.credential_id]
            try:
                # Bound the response wait separately. An idempotent private write
                # may finish after the wait expires; it cannot publish facts.
                async with asyncio.timeout(3):
                    storage = await run_in_threadpool(selected.store.stage, owner, result)
            except (StoreUnavailable, TimeoutError):
                # A staging outage does not destroy a useful reading or select
                # another AI key; its explicit status lets the scanner retry.
                storage = StagingResult(status="not_stored", reason="unavailable")
            try:
                async with asyncio.timeout(4):
                    contribution = await run_in_threadpool(
                        automatic_contribution, request.app.state, selected.store, body, result,
                        provider=value.provider, model=value.model, revision=selection.revision,
                    )
            except (StoreUnavailable, TimeoutError):
                contribution = MachineContribution(status="not_shared", reason="unavailable")
            return JSONResponse({
                "status": "extracted", "extraction": result.model_dump(mode="json"),
                "ai": {"scope": "global", "provider": value.provider,
                       "model": value.model, "revision": selection.revision},
                "storage": storage.model_dump(mode="json"),
                "contribution": contribution.model_dump(mode="json"),
            }, headers={"Cache-Control": "no-store"})
        except AuthenticationInvalid:
            return failure(401, "scanner_authentication_required")
        except (AuthenticationUnavailable, StoreUnavailable):
            return failure(503, "ai_selection_unavailable")
        except StoreQuotaExceeded:
            return failure(429, "ai_admission_limit", retry_after=3600)
        except TimeoutError:
            return failure(503, "ai_timeout", retry_after=30)
        except ProviderFailure as error:
            return failure(
                429 if error.kind == "quota" else 502 if error.kind == "invalid_response" else 503,
                "ai_" + error.kind, retry_after=error.cooldown_seconds,
            )

    @router.get("/v1/ai/observations/{barcode}", response_model=MachineObservationLookup)
    def observations(request: Request, barcode: Annotated[str, Path(pattern=r"^(?:[0-9]{8}|[0-9]{12,14})$")]):
        selected = gateway(request)
        if selected is None:
            return failure(503, "ai_not_configured")
        try:
            result = selected.store.machine_observations(barcode)
            if result.observations:
                baseline = known_baseline(request.app.state, barcode)
                conflicts = set(result.conflict_fields)
                conflicts.update(conflict_fields(baseline.values + [comparison_values(item.facts) for item in result.observations]))
                if not baseline.identities or any(
                    not compatible_identity(item.facts.identity.model_dump(), known)
                    for item in result.observations for known in baseline.identities
                ):
                    conflicts.add("identity")
                result = result.model_copy(update={"conflict_fields": sorted(conflicts)[:128]})
            return JSONResponse(result.model_dump(mode="json"), headers={"Cache-Control": "no-store"})
        except (StoreUnavailable, OSError, ValueError):
            return failure(503, "machine_observations_unavailable")

    return router
