"""The front-photo claim route reads existing sources and accepts no caller nutrition."""

from app.claims.catalogue import CatalogueClaimsResponse
from tests.integration.test_claims_api import make_client
from tests.unit.test_catalogue_facts import build, raw_product

CODE = "8901764051258"


def test_claim_route_reads_actual_catalogue_without_confirmation_or_provider_calls(tmp_path):
    catalogue = build(tmp_path, [raw_product(code=CODE, brands="Synthetic", quantity="300 g")])[0]
    with make_client() as client:
        client.app.state.catalogue = catalogue
        client.app.state.research_catalogue = None
        response = client.post("/v1/claims/catalogue-check", json={
            "barcode": CODE, "claims": ["Low sugar", "No added sugar"],
        })
        assert response.status_code == 200
        assert response.headers["cache-control"] == "no-store"
        result = CatalogueClaimsResponse.model_validate_json(response.content)
        assert result.status == "ready" and result.barcode == CODE
        assert result.source_ids[0].startswith("off:")
        assert result.assessments[0].comparisons[0].value == 0
        assert result.assessments[0].comparisons[0].outcome == "pass"
        assert result.assessments[0].status == "insufficient_information"
        assert not result.assessments[1].comparisons
        assert '"confirmed"' not in response.text


def test_claim_route_rejects_injected_tables_and_bounds_requests():
    with make_client() as client:
        base = {"barcode": CODE, "claims": ["Low sugar"]}
        for body in ({**base, "confirmed": True}, {**base, "rows": []},
                     {**base, "claims": ["Low sugar"] * 17},
                     {**base, "claims": ["private label " * 100]}):
            response = client.post("/v1/claims/catalogue-check", json=body)
            assert response.status_code == 422
            assert "private label" not in response.text
