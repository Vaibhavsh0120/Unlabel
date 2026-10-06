import json
from pathlib import Path

from app.catalogue.facts import FactsLookup
from app.catalogue.models import CatalogLookup
from app.claims.models import (
    ClaimsRequest,
    ClaimsResponse,
    ClaimsRulesResponse,
    ClaimsUnavailable,
    EvidenceResponse,
)
from app.schemas.nutrition import NormalizeRequest
from app.schemas.nutrition_products import NormalizeResponse, NutritionLookup
from app.schemas.products import ProductLookup

CONTRACTS = Path(__file__).resolve().parents[3] / "contracts"


def test_published_strict_product_schema_has_not_changed():
    saved = json.loads((CONTRACTS / "schemas/product-lookup-v1.schema.json").read_text())
    assert saved == ProductLookup.model_json_schema()


def test_nutrition_examples_validate_for_teammate_consumers():
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
    }.items():
        model.model_validate_json((CONTRACTS / "examples" / filename).read_text())


def test_current_openapi_and_all_new_claim_schemas_match_runtime():
    from app import __version__
    from app.core.config import Settings
    from app.main import create_app

    saved = json.loads((CONTRACTS / f"schemas/backend-v{__version__}.openapi.json").read_text())
    assert saved == create_app(Settings(_env_file=None)).openapi()
    for filename, model in {
        "claims-check-request-v1.schema.json": ClaimsRequest,
        "claims-check-response-v1.schema.json": ClaimsResponse,
        "claims-rules-v1.schema.json": ClaimsRulesResponse,
        "claims-unavailable-v1.schema.json": ClaimsUnavailable,
        "evidence-v1.schema.json": EvidenceResponse,
    }.items():
        assert (
            json.loads((CONTRACTS / "schemas" / filename).read_text()) == model.model_json_schema()
        )
    response = ClaimsResponse.model_validate_json(
        (CONTRACTS / "examples/claims-check-v1.response.synthetic.json").read_text()
    )
    assert response.assessments[0].status == "supported"
