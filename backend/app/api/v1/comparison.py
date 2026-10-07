"""Comparison resolves public references only; it never authenticates or writes."""

from collections.abc import Callable

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse

from app.catalogue.facts import FactsLookup
from app.community.models import CommunityLookup
from app.comparison.models import ComparisonRequest, ComparisonResponse
from app.comparison.service import compare


def build_router(*, snapshot_lookup: Callable[[Request, str], FactsLookup]) -> APIRouter:
    router = APIRouter(tags=["Nutrient comparison"])

    @router.post(
        "/v1/reports/compare",
        response_model=ComparisonResponse,
        responses={413: {"description": "Actual body exceeds 64 KiB"}},
    )
    def compare_reports(request: Request, body: ComparisonRequest):
        def community_lookup(barcode: str) -> CommunityLookup:
            active = request.app.state.community_runtime
            if active is None:
                return CommunityLookup(requested_barcode=barcode, status="unavailable")
            return active.store.lookup(barcode)

        result = compare(
            body,
            off_lookup=lambda barcode: snapshot_lookup(request, barcode),
            community_lookup=community_lookup,
        )
        return JSONResponse(result.model_dump(mode="json"), headers={"Cache-Control": "no-store"})

    return router
