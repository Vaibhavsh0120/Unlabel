import json
from pathlib import Path

from app.accounts.models import SyncFailure, SyncRequest, SyncSnapshot
from app.ai.models import ExtractedLabel, ExtractionRequest
from app.ai.router import ActivateRequest, ActivationResponse, ActiveResponse, ExtractionResponse
from app.catalogue.facts import FactsLookup
from app.catalogue.models import CatalogLookup
from app.claims.catalogue import CatalogueClaimsRequest, CatalogueClaimsResponse
from app.claims.models import (
    ClaimsRequest,
    ClaimsResponse,
    ClaimsRulesResponse,
    ClaimsUnavailable,
    EvidenceResponse,
)
from app.community.models import (
    CommunityFailure,
    CommunityLookup,
    ContributionReceipt,
    ContributionRequest,
    ResolvedProduct,
)
from app.comparison.models import ComparisonRequest, ComparisonResponse
from app.reports.glossary import GlossaryResponse
from app.reports.models import LabelReport, ReportCheckRequest, ReportFailure
from app.research_catalogue.models import (
    ResearchBarcodeLookup,
    ResearchLookup,
    ResearchSearchResult,
)
from app.schemas.nutrition import NormalizeRequest
from app.schemas.nutrition_products import NormalizeResponse, NutritionLookup
from app.schemas.products import ProductLookup

CONTRACTS = Path(__file__).resolve().parents[3] / "contracts"


def test_published_strict_product_schema_has_not_changed():
    saved = json.loads((CONTRACTS / "schemas/product-lookup-v1.schema.json").read_text())
    assert saved == ProductLookup.model_json_schema()


def test_all_examples_validate_for_teammate_consumers():
    for filename, model in {
        "nutrition-normalize-v1.request.synthetic.json": NormalizeRequest,
        "nutrition-normalize-v1.response.synthetic.json": NormalizeResponse,
        "nutrition-lookup-v1.synthetic.json": NutritionLookup,
        "catalogue-lookup-v1.synthetic.json": CatalogLookup,
        "catalogue-facts-v1.synthetic.json": FactsLookup,
        "claims-check-v1.request.synthetic.json": ClaimsRequest,
        "claims-check-v1.response.synthetic.json": ClaimsResponse,
        "claims-rules-v1.synthetic.json": ClaimsRulesResponse,
        "claims-unavailable-v1.synthetic.json": ClaimsUnavailable,
        "evidence-v1.synthetic.json": EvidenceResponse,
        "community-contribution-v1.request.synthetic.json": ContributionRequest,
        "community-provisional-v1.request.synthetic.json": ContributionRequest,
        "community-contribution-v1.receipt.synthetic.json": ContributionReceipt,
        "community-lookup-v1.synthetic.json": CommunityLookup,
        "community-failure-v1.synthetic.json": CommunityFailure,
        "resolved-product-v1.synthetic.json": ResolvedProduct,
        "report-check-v1.request.synthetic.json": ReportCheckRequest,
        "label-report-v1.current.synthetic.json": LabelReport,
        "label-report-v1.historical.synthetic.json": LabelReport,
        "report-failure-v1.synthetic.json": ReportFailure,
        "ingredient-glossary-v1.synthetic.json": GlossaryResponse,
        "personal-sync-v1.request.synthetic.json": SyncRequest,
        "personal-sync-v1.snapshot.synthetic.json": SyncSnapshot,
        "personal-sync-v1.failure.synthetic.json": SyncFailure,
        "comparison-v1.request.synthetic.json": ComparisonRequest,
        "comparison-v1.response.synthetic.json": ComparisonResponse,
    }.items():
        model.model_validate_json((CONTRACTS / "examples" / filename).read_text())


def test_current_openapi_and_all_current_schemas_match_runtime():
    from app import __version__
    from app.ai.observations import MachineContribution, MachineObservationLookup
    from app.core.config import Settings
    from app.live_products.models import LiveLookup
    from app.main import create_app

    saved = json.loads((CONTRACTS / f"schemas/backend-v{__version__}.openapi.json").read_text())
    assert saved == create_app(Settings(_env_file=None)).openapi()
    for filename, model in {
        "claims-check-request-v1.schema.json": ClaimsRequest,
        "catalogue-claims-request-v1.schema.json": CatalogueClaimsRequest,
        "catalogue-claims-response-v1.schema.json": CatalogueClaimsResponse,
        "claims-check-response-v1.schema.json": ClaimsResponse,
        "claims-rules-v1.schema.json": ClaimsRulesResponse,
        "claims-unavailable-v1.schema.json": ClaimsUnavailable,
        "evidence-v1.schema.json": EvidenceResponse,
        "community-contribution-request-v1.schema.json": ContributionRequest,
        "community-contribution-receipt-v1.schema.json": ContributionReceipt,
        "community-lookup-v1.schema.json": CommunityLookup,
        "community-failure-v1.schema.json": CommunityFailure,
        "resolved-product-v1.schema.json": ResolvedProduct,
        "report-check-request-v1.schema.json": ReportCheckRequest,
        "label-report-v1.schema.json": LabelReport,
        "report-failure-v1.schema.json": ReportFailure,
        "ingredient-glossary-v1.schema.json": GlossaryResponse,
        "personal-sync-request-v1.schema.json": SyncRequest,
        "personal-sync-snapshot-v1.schema.json": SyncSnapshot,
        "personal-sync-failure-v1.schema.json": SyncFailure,
        "comparison-request-v1.schema.json": ComparisonRequest,
        "comparison-response-v1.schema.json": ComparisonResponse,
        "research-search-v1.schema.json": ResearchSearchResult,
        "research-lookup-v1.schema.json": ResearchLookup,
        "research-barcode-lookup-v1.schema.json": ResearchBarcodeLookup,
        "ai-extraction-request-v1.schema.json": ExtractionRequest,
        "ai-extracted-label-v1.schema.json": ExtractedLabel,
        "ai-extraction-response-v1.schema.json": ExtractionResponse,
        "ai-active-v1.schema.json": ActiveResponse,
        "ai-activate-request-v1.schema.json": ActivateRequest,
        "ai-activate-response-v1.schema.json": ActivationResponse,
        "machine-label-contribution-v1.schema.json": MachineContribution,
        "machine-label-lookup-v1.schema.json": MachineObservationLookup,
        "live-product-lookup-v1.schema.json": LiveLookup,
    }.items():
        assert (
            json.loads((CONTRACTS / "schemas" / filename).read_text()) == model.model_json_schema()
        )
    response = ClaimsResponse.model_validate_json(
        (CONTRACTS / "examples/claims-check-v1.response.synthetic.json").read_text()
    )
    assert response.assessments[0].status == "supported"
