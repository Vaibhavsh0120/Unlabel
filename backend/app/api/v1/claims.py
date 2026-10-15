from typing import Annotated

from fastapi import APIRouter, Request
from fastapi import Path as PathParameter
from fastapi.responses import JSONResponse

from app.claims.catalogue import (
    CatalogueClaimsRequest,
    CatalogueClaimsResponse,
    assess_catalogue_claims,
)
from app.claims.engine import assess_claims
from app.claims.knowledge import UNSUPPORTED_CLAIMS, KnowledgeStore
from app.claims.models import (
    ClaimsRequest,
    ClaimsResponse,
    ClaimsRulesResponse,
    ClaimsUnavailable,
    EvidenceResponse,
)


def build_router(*, store: KnowledgeStore | None = None) -> APIRouter:
    """Mount independent claims routes; invalid knowledge disables these routes only."""
    router = APIRouter(tags=["Claim checks"])

    @router.post("/v1/claims/catalogue-check", response_model=CatalogueClaimsResponse)
    def catalogue_claims(request: Request, body: CatalogueClaimsRequest):
        result = assess_catalogue_claims(request.app.state, body, store)
        return JSONResponse(result.model_dump(mode="json"), headers={"Cache-Control": "no-store"})

    @router.post(
        "/v1/claims/check",
        response_model=ClaimsResponse,
        responses={503: {"model": ClaimsUnavailable}, 413: {"description": "Body exceeds 32 KiB"}},
    )
    def check_claims(body: ClaimsRequest):
        if store is None:
            result = ClaimsUnavailable(warnings=["reviewed_claim_knowledge_unavailable"])
            return JSONResponse(
                result.model_dump(mode="json"),
                status_code=503,
                headers={"Cache-Control": "no-store"},
            )
        result = assess_claims(body, store)
        return JSONResponse(result.model_dump(mode="json"), headers={"Cache-Control": "no-store"})

    @router.get(
        "/v1/claims/rules",
        response_model=ClaimsRulesResponse,
        responses={503: {"model": ClaimsRulesResponse}},
    )
    def claim_rules():
        result = ClaimsRulesResponse(
            status="ready" if store is not None else "unavailable",
            knowledge_version=store.knowledge_version if store is not None else None,
            reviewed_on=store.reviewed_on if store is not None else None,
            rules=list(store.rules.values()) if store is not None else [],
            unsupported_claims=list(UNSUPPORTED_CLAIMS),
            warnings=["numeric_criteria_only", "not_legal_certification"]
            if store is not None
            else ["reviewed_claim_knowledge_unavailable"],
        )
        return JSONResponse(
            result.model_dump(mode="json"),
            status_code=200 if store is not None else 503,
            headers={"Cache-Control": "no-store"},
        )

    @router.get(
        "/v1/evidence/{source_id}",
        response_model=EvidenceResponse,
        responses={404: {"model": EvidenceResponse}, 503: {"model": EvidenceResponse}},
    )
    def evidence(
        source_id: Annotated[
            str,
            PathParameter(min_length=1, max_length=64, pattern=r"^[a-z][a-z0-9-]*$"),
        ],
    ):
        source = store.sources.get(source_id) if store is not None else None
        status = "unavailable" if store is None else "found" if source is not None else "not_found"
        result = EvidenceResponse(
            status=status,
            requested_source_id=source_id,
            knowledge_version=store.knowledge_version if store is not None else None,
            source=source,
            warnings=[]
            if source is not None
            else [
                "reviewed_claim_knowledge_unavailable"
                if store is None
                else "evidence_source_unknown"
            ],
        )
        return JSONResponse(
            result.model_dump(mode="json"),
            status_code={"found": 200, "not_found": 404, "unavailable": 503}[status],
            headers={"Cache-Control": "no-store"},
        )

    return router
