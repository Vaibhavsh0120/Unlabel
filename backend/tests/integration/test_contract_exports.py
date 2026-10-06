import json
from pathlib import Path

from app.catalogue.facts import FactsLookup
from app.catalogue.models import CatalogLookup
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
    }.items():
        model.model_validate_json((CONTRACTS / "examples" / filename).read_text())
