"""Current-label analysis survives automatic catalogue persistence failures."""

from collections.abc import Callable
from typing import Annotated, cast

from fastapi import APIRouter, Header, Path, Request
from fastapi.responses import JSONResponse

from app.api.v1.community import CommunityRuntimeProtocol
from app.catalogue.facts import FactsLookup
from app.claims.knowledge import KnowledgeStore
from app.community.auth import AuthenticationInvalid, AuthenticationUnavailable
from app.community.models import CommunityLookup
from app.community.resolver import resolve_product
from app.community.service import actor_hash, prepare_submission
from app.community.store import StoreConflict, StoreQuotaExceeded, StoreUnavailable
from app.core.config import Settings
from app.providers.products.open_food_facts import BARCODE_PATTERN
from app.reports.glossary import GlossaryResponse, GlossaryStore
from app.reports.models import LabelReport, ReportCheckRequest, ReportFailure, StorageOutcome
from app.reports.service import report_from_observation, report_from_resolved


def build_router(
    *,
    config: Settings,
    snapshot_lookup: Callable[[Request, str], FactsLookup],
    claims_store: KnowledgeStore | None,
    glossary: GlossaryStore | None,
) -> APIRouter:
    router = APIRouter(tags=["Label reports"])

    def runtime(request: Request) -> CommunityRuntimeProtocol | None:
        return cast(CommunityRuntimeProtocol | None, request.app.state.community_runtime)

    @router.get(
        "/v1/ingredients/glossary",
        response_model=GlossaryResponse,
        responses={503: {"model": ReportFailure}},
    )
    def ingredients_glossary():
        if glossary is None:
            failure = ReportFailure(status="unavailable", code="ingredient_glossary_unavailable")
            return JSONResponse(
                failure.model_dump(mode="json"),
                status_code=503,
                headers={"Cache-Control": "no-store"},
            )
        return JSONResponse(
            glossary.response().model_dump(mode="json"), headers={"Cache-Control": "no-store"}
        )

    def autosave(
        request: Request,
        body: ReportCheckRequest,
        authorization: str | None,
        *,
        quantities_need_correction: bool,
    ) -> StorageOutcome:
        # Analysis is already complete. Authentication and storage failures must
        # change only the persistence outcome, never discard the useful report.
        active = runtime(request)
        if active is None:
            return StorageOutcome(status="unavailable", warnings=["community_not_available"])
        try:
            if authorization is None:
                raise AuthenticationInvalid()
            parts = authorization.split()
            if len(parts) != 2 or parts[0].lower() != "bearer" or not 1 <= len(parts[1]) <= 8192:
                raise AuthenticationInvalid()
            secret = config.community_actor_secret
            if secret is None:
                raise AuthenticationUnavailable()
            actor = actor_hash(active.verify_token(parts[1]), secret.get_secret_value())
        except AuthenticationInvalid:
            return StorageOutcome(
                status="authentication_required", warnings=["anonymous_authentication_required"]
            )
        except AuthenticationUnavailable:
            return StorageOutcome(
                status="unavailable", warnings=["authentication_provider_unavailable"]
            )
        if quantities_need_correction:
            return StorageOutcome(
                status="needs_correction", warnings=["nutrition_quantities_need_review"]
            )
        try:
            prepared = prepare_submission(body.observation)
        except ValueError:
            return StorageOutcome(
                status="needs_correction", warnings=["community_facts_need_correction"]
            )
        try:
            baseline = (
                snapshot_lookup(request, body.observation.barcode)
                if body.observation.barcode is not None
                else None
            )
            receipt = active.store.submit(actor, prepared, baseline=baseline)
            return StorageOutcome(status="saved", receipt=receipt)
        except StoreQuotaExceeded:
            return StorageOutcome(status="rate_limited", warnings=["community_admission_limit"])
        except StoreConflict:
            return StorageOutcome(status="conflict", warnings=["community_content_conflict"])
        except ValueError:
            # New references must match an actually available exact source.
            # Existing immutable retries are handled by storage before this check.
            return StorageOutcome(status="conflict", warnings=["community_reference_conflict"])
        except (StoreUnavailable, OSError):
            return StorageOutcome(status="unavailable", warnings=["community_unavailable"])

    @router.post(
        "/v1/reports/check",
        response_model=LabelReport,
        responses={413: {"description": "Actual body exceeds 32 KiB"}},
    )
    def check(
        request: Request,
        body: ReportCheckRequest,
        authorization: Annotated[str | None, Header()] = None,
    ):
        report = report_from_observation(body, claims_store=claims_store, glossary=glossary)
        storage = autosave(
            request,
            body,
            authorization,
            quantities_need_correction="nutrition_quantities_need_review" in report.warnings,
        )
        result = LabelReport.model_validate({**report.model_dump(), "storage": storage})
        return JSONResponse(result.model_dump(mode="json"), headers={"Cache-Control": "no-store"})

    @router.get(
        "/v1/products/{barcode}/report",
        response_model=LabelReport,
        responses={code: {"model": LabelReport} for code in (404, 503)},
    )
    def historical(request: Request, barcode: Annotated[str, Path(pattern=BARCODE_PATTERN)]):
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
        except (StoreUnavailable, StoreQuotaExceeded, StoreConflict):
            community = CommunityLookup(
                requested_barcode=barcode, status="unavailable", warnings=["community_unavailable"]
            )
        snapshot = snapshot_lookup(request, barcode)
        resolved = resolve_product(
            snapshot,
            community,
            knowledge_version=claims_store.knowledge_version if claims_store is not None else None,
        )
        report = report_from_resolved(resolved, claims_store=claims_store, glossary=glossary)
        code = (
            200
            if community.status == "found" or snapshot.status == "found"
            else (
                503
                if community.status == "unavailable" or snapshot.status == "unavailable"
                else 404
            )
        )
        return JSONResponse(
            report.model_dump(mode="json"), status_code=code, headers={"Cache-Control": "no-store"}
        )

    return router
