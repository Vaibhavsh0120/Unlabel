"""External-source and publication boundaries for explicit dataset maintenance."""

import importlib.util
import json
import sys
from pathlib import Path

import httpx
import pytest

SCRIPTS = Path(__file__).resolve().parents[3] / "scripts/data"
sys.path.insert(0, str(SCRIPTS))
spec = importlib.util.spec_from_file_location(
    "popular_acquisition", SCRIPTS / "acquire_popular_products.py"
)
assert spec and spec.loader
acquisition = importlib.util.module_from_spec(spec)
spec.loader.exec_module(acquisition)

CODE = "8901491101816"


def client_for(product=None, *, content=None, status=200, headers=None):
    def handler(request):
        assert request.url.host == "world.openfoodfacts.org"
        assert request.method == "GET"
        if content is not None:
            return httpx.Response(status, content=content, headers=headers)
        return httpx.Response(status, json={"product": product}, headers=headers)

    return httpx.Client(transport=httpx.MockTransport(handler), follow_redirects=False)


def product(**changes):
    return {
        "code": CODE,
        "countries_tags": ["en:india"],
        "product_name": "An exact pack",
        "brands": "A public brand",
        "quantity": "52 g",
        **changes,
    }


def test_exact_projection_strips_contributors_images_and_legacy_values():
    raw = product(
        creator="private-contributor",
        nutriments={"sugars_100g": 15},
        images={
            "uploaded": {"1": {"uploader": "private-contributor"}},
            "front_en": {"rev": 2, "uploader": "private-contributor"},
        },
        image_front_url="https://untrusted.example/image.jpg",
    )
    with client_for(raw) as client:
        result, failure = acquisition.fetch_product(client, CODE)
    assert failure is None and result
    row = result["product"]
    assert row["nutrition_legacy_present"] is True
    assert "nutriments" not in row and "nutrition" not in row
    assert "creator" not in row and "image_front_url" not in row
    assert "uploaded" not in row["images"]
    assert "private-contributor" not in json.dumps(result)


@pytest.mark.parametrize("raw", [product(code="8901491101817"), product(code=8901491101816)])
def test_mismatched_barcode_is_never_normalized_into_requested_product(raw):
    with client_for(raw) as client, pytest.raises(ValueError, match="differs"):
        acquisition.fetch_product(client, CODE)


def test_foreign_record_cannot_inherit_baseline_india_market():
    with client_for(product(countries_tags=["en:united-states"])) as client:
        result, failure = acquisition.fetch_product(client, CODE)
    assert result is None
    assert failure["reason"] == "india_market_unconfirmed"


def test_redirect_is_not_followed():
    with client_for(status=302, headers={"location": "http://127.0.0.1/private"}) as client:
        result, failure = acquisition.fetch_product(client, CODE)
    assert result is None and failure["status"] == 302


def test_declared_and_actual_response_budgets(monkeypatch):
    monkeypatch.setattr(acquisition, "MAX_RESPONSE_BYTES", 64)
    with client_for(content=b"{}", headers={"content-length": "65"}) as client:
        with pytest.raises(ValueError, match="Declared"):
            acquisition.fetch_product(client, CODE)
    with client_for(content=b" " * 65, headers={"content-length": "1"}) as client:
        with pytest.raises(ValueError, match="Response exceeds"):
            acquisition.fetch_product(client, CODE)


@pytest.mark.parametrize("content", [b'{"product":{},"product":{}}', b'{"product":{"x":NaN}}'])
def test_ambiguous_or_nonfinite_json_fails_closed(content):
    with client_for(content=content) as client, pytest.raises(ValueError):
        acquisition.fetch_product(client, CODE)


def test_direct_declared_table_retains_actual_basis_and_source():
    table = {
        "source": "packaging",
        "preparation": "as_sold",
        "per_quantity": 25,
        "per_unit": "g",
        "nutrients": {"sugars": {"value": 5, "unit": "g"}},
    }
    with client_for(product(nutrition={"input_sets": [table]})) as client:
        result, failure = acquisition.fetch_product(client, CODE)
    assert failure is None and result
    assert result["product"]["nutrition"]["input_sets"] == [table]


def test_oversized_publication_preserves_existing_owned_file(tmp_path, monkeypatch):
    output = tmp_path / "observations.json"
    output.write_text("original")
    monkeypatch.setattr(acquisition, "MAX_OUTPUT_BYTES", 8)
    with pytest.raises(ValueError, match="output exceeds"):
        acquisition.write_atomic(output, {"new": "x" * 30})
    assert output.read_text() == "original"
    assert list(tmp_path.iterdir()) == [output]


def test_target_duplicates_and_unsupported_codes_reject(tmp_path):
    source = tmp_path / "targets.json"
    source.write_text(json.dumps({"targets": [{"code": CODE}, {"code": CODE}]}))
    with pytest.raises(ValueError, match="Duplicate"):
        acquisition.load_targets(source, 10)
    source.write_text(json.dumps({"targets": [{"code": "12"}]}))
    with pytest.raises(ValueError, match="barcode"):
        acquisition.load_targets(source, 10)


def test_resume_preserves_decimal_types_and_reprojects_public_fields(tmp_path):
    table = {
        "source": "packaging",
        "preparation": "as_sold",
        "per": "serving",
        "per_quantity": 25.0,
        "per_unit": "g",
        "nutrients": {"sugars": {"value": 1.5, "unit": "g"}},
    }
    with client_for(product(nutrition={"input_sets": [table]})) as client:
        row, _ = acquisition.fetch_product(client, CODE)
    row["product"]["creator"] = "private-contributor"
    row["source"]["email"] = "private-identity"
    output = tmp_path / "observations.json"
    acquisition.write_atomic(output, {"observations": [row]})
    resumed = acquisition.load_resume(output, [{"code": CODE}])
    values = resumed[0]["product"]["nutrition"]["input_sets"][0]
    assert values["per_quantity"] == 25.0 and type(values["per_quantity"]) is float
    assert values["nutrients"]["sugars"]["value"] == 1.5
    assert type(values["nutrients"]["sugars"]["value"]) is float
    assert "private-" not in json.dumps(resumed)


def main_inputs(tmp_path, monkeypatch, codes, transport):
    targets, output = tmp_path / "targets.json", tmp_path / "observations.json"
    targets.write_text(json.dumps({"targets": [{"code": code} for code in codes]}))
    monkeypatch.setattr(
        sys, "argv", ["acquire", "--targets", str(targets), "--output", str(output)]
    )
    mock_client = httpx.Client(transport=httpx.MockTransport(transport))
    monkeypatch.setattr(acquisition.httpx, "Client", lambda **_kwargs: mock_client)
    return output


def test_main_429_stops_without_retry_and_marks_remaining_targets(tmp_path, monkeypatch):
    calls = []

    def handler(request):
        calls.append(request.url)
        return httpx.Response(429)

    output = main_inputs(tmp_path, monkeypatch, [CODE, "8901491101817"], handler)
    monkeypatch.setattr(acquisition.time, "sleep", lambda _delay: pytest.fail("429 cannot retry"))
    assert acquisition.main() == 0
    state = json.loads(output.read_text())
    assert len(calls) == 1 and state["attempted"] == 1
    assert state["failures"][1]["reason"] == "not_attempted_after_rate_limit"


def test_main_checkpoints_each_completed_read_before_interruption(tmp_path, monkeypatch):
    calls = 0

    def handler(_request):
        nonlocal calls
        calls += 1
        if calls == 2:
            raise KeyboardInterrupt
        return httpx.Response(200, json={"product": product()})

    output = main_inputs(tmp_path, monkeypatch, [CODE, "8901491101817"], handler)
    monkeypatch.setattr(acquisition.time, "sleep", lambda _delay: None)
    with pytest.raises(KeyboardInterrupt):
        acquisition.main()
    state = json.loads(output.read_text())
    assert len(state["observations"]) == 1 and state["attempted"] == 1


def test_main_retries_respect_request_delay(tmp_path, monkeypatch):
    calls, delays = [], []

    def handler(request):
        calls.append(request.url)
        return (
            httpx.Response(503)
            if len(calls) == 1
            else httpx.Response(200, json={"product": product()})
        )

    main_inputs(tmp_path, monkeypatch, [CODE], handler)
    monkeypatch.setattr(acquisition.time, "sleep", delays.append)
    assert acquisition.main() == 0
    assert len(calls) == 2 and delays[0] >= 2.5
