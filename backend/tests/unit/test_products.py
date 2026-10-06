import httpx
import pytest

from app.core.config import Settings
from app.providers.products.open_food_facts import OpenFoodFactsProvider


def payload(**fields):
    return {
        "status": "success",
        "result": {"id": "product_found"},
        "product": {"code": "0123456789012", "product_name": "Synthetic oats", **fields},
    }


async def lookup(response: httpx.Response | None = None, exception: Exception | None = None):
    def handle(request: httpx.Request) -> httpx.Response:
        assert request.url.host == "world.openfoodfacts.org"
        assert request.url.path == "/api/v3.6/product/0123456789012.json"
        assert request.headers["User-Agent"].startswith("Unlabel/")
        if exception:
            raise exception
        assert response is not None
        return response

    async with httpx.AsyncClient(transport=httpx.MockTransport(handle)) as client:
        return await OpenFoodFactsProvider(client, Settings(_env_file=None)).lookup("0123456789012")


@pytest.mark.asyncio
async def test_found_preserves_origin_missing_information_and_provider_insights():
    result = await lookup(
        httpx.Response(
            200,
            json=payload(
                ingredients_text="Oats, milk",
                allergens_tags=["en:milk"],
                traces_tags=["en:nuts"],
                nutriscore_grade="b",
                nova_group=2,
            ),
        )
    )
    assert result.status == "found"
    assert result.requested_barcode == "0123456789012"
    assert result.product is not None
    assert result.product.name == "Synthetic oats"
    assert result.product.insights.nutri_score_grade == "b"
    assert result.product.allergen_tags == ["en:milk"]
    assert result.product.trace_tags == ["en:nuts"]
    assert result.source.provider == "open_food_facts"
    assert result.source.retrieved_at.tzinfo is not None
    assert "allergen_safety_not_assessed" in result.warnings
    assert "health_score" not in result.product.model_dump()


@pytest.mark.asyncio
async def test_sparse_product_does_not_invent_missing_fields():
    result = await lookup(httpx.Response(200, json=payload()))
    assert result.status == "found"
    assert result.product is not None
    assert result.product.ingredients_text is None
    assert result.product.insights.nutri_score_grade is None
    assert "ingredients_missing" in result.warnings


@pytest.mark.parametrize(
    ("response", "expected"),
    [
        (httpx.Response(404), "not_found"),
        (httpx.Response(429), "rate_limited"),
        (httpx.Response(503), "unavailable"),
        (httpx.Response(302, headers={"Location": "http://127.0.0.1"}), "unavailable"),
        (httpx.Response(200, text="not json"), "incompatible_response"),
        (httpx.Response(200, json={"status": "success", "product": []}), "incompatible_response"),
        (httpx.Response(200, json=payload(code="9876543210987")), "incompatible_response"),
        (httpx.Response(200, content=b"x" * 600_000), "incompatible_response"),
    ],
)
@pytest.mark.asyncio
async def test_provider_failures_are_explicit_and_have_no_product(response, expected):
    result = await lookup(response)
    assert result.status == expected
    assert result.product is None


@pytest.mark.asyncio
async def test_timeout_is_recoverable():
    result = await lookup(exception=httpx.ReadTimeout("private detail"))
    assert result.status == "unavailable"
    assert "private detail" not in result.model_dump_json()


@pytest.mark.asyncio
async def test_leading_zero_normalization_is_allowed_but_retained():
    result = await lookup(httpx.Response(200, json=payload(code="123456789012")))
    assert result.product is not None
    assert result.product.barcode == "123456789012"
    assert result.requested_barcode == "0123456789012"


@pytest.mark.asyncio
async def test_invalid_optional_values_are_unknown_not_truthy_or_fabricated():
    result = await lookup(
        httpx.Response(
            200,
            json=payload(
                ingredients_text=123,
                allergens_tags="milk",
                nutriscore_grade="unknown",
                nova_group=True,
            ),
        )
    )
    assert result.status == "found"
    assert result.product is not None
    assert result.product.ingredients_text is None
    assert result.product.allergen_tags == []
    assert result.product.insights.nova_group is None
