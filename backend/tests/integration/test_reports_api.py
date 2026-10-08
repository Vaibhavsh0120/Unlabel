"""Useful current-label reports stay available when catalogue saving cannot run."""

import asyncio
import json
from pathlib import Path
from typing import Any, Literal, cast

import httpx
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from pydantic import SecretStr

from app.api.v1.community import CommunityRuntimeProtocol
from app.catalogue.facts import FactsLookup
from app.community.auth import AuthenticationInvalid, AuthenticationUnavailable
from app.community.models import CommunityLookup, ContributionReceipt, PreparedContribution
from app.community.service import verify_provider_references
from app.community.store import StoreConflict, StoreQuotaExceeded, StoreUnavailable
from app.core.config import Settings
from app.main import create_app
from tests.community_fixtures import CODE, NOW, candidate_revision, contribution_dict


def forbidden(request):
    raise AssertionError("Reports must use local exact sources, not live OFF")


def payload(**changes) -> dict[str, Any]:
    return {"observation": contribution_dict(**changes)}


class FakeStore:
    def __init__(self):
        self.calls = []
        self.lookups = []
        self.receipts = {}
        self.revisions = []
        self.error: Exception | None = None
        self.used_event_loop = False

    def submit(self, actor_id: str, prepared: PreparedContribution, *, baseline=None):
        try:
            asyncio.get_running_loop()
        except RuntimeError:
            pass
        else:
            self.used_event_loop = True
        if self.error is not None:
            raise self.error
        key = (actor_id, prepared.request.submission_id)
        if key in self.receipts:
            existing = self.receipts[key]
            if existing.content_sha256 != prepared.content_sha256:
                raise StoreConflict()
            return existing
        verify_provider_references(prepared.request, baseline)
        self.calls.append((actor_id, prepared, baseline))
        receipt = ContributionReceipt(
            submission_id=prepared.request.submission_id,
            revision_id="a" * 64,
            barcode=prepared.request.barcode,
            content_sha256=prepared.content_sha256,
            factual_sha256=prepared.factual_sha256,
            status="candidate" if prepared.auto_eligible else "provisional",
            submitted_at=NOW,
            expires_at=None,
        )
        self.receipts[key] = receipt
        return receipt

    def lookup(self, barcode):
        self.lookups.append(barcode)
        if self.error is not None:
            raise self.error
        return CommunityLookup(
            requested_barcode=barcode,
            status="found" if self.revisions else "not_found",
            revisions=self.revisions,
        )


class FakeRuntime:
    def __init__(self):
        self.store = FakeStore()
        self.tokens = []
        self.closed = False

    def verify_token(self, token):
        self.tokens.append(token)
        if token == "invalid":
            raise AuthenticationInvalid()
        if token == "unavailable":
            raise AuthenticationUnavailable()
        return "private-subject-" + token

    def close(self):
        self.closed = True


def client_for(runtime=None, **changes):
    settings = Settings(
        _env_file=None,
        community_enabled=runtime is not None,
        community_project_id="unlabel-india-catalogue" if runtime is not None else "",
        community_actor_secret=SecretStr("x" * 32) if runtime is not None else None,
        **changes,
    )
    return TestClient(
        create_app(
            settings,
            httpx.MockTransport(forbidden),
            community_runtime=cast(CommunityRuntimeProtocol | None, runtime),
        )
    )


def snapshot_fixture():
    path = (
        Path(__file__).resolve().parents[3] / "contracts/examples/catalogue-facts-v1.synthetic.json"
    )
    return FactsLookup.model_validate_json(path.read_text(encoding="utf-8"))


class FakeCatalogue:
    def __init__(self, status: Literal["found", "not_found", "unavailable"] = "found"):
        self.status: Literal["found", "not_found", "unavailable"] = status

    def lookup_facts(self, barcode):
        assert barcode == CODE
        return (
            snapshot_fixture()
            if self.status == "found"
            else FactsLookup(
                requested_barcode=barcode,
                status=self.status,
                manifest=snapshot_fixture().manifest if self.status == "not_found" else None,
            )
        )


def test_barcode_less_current_label_returns_useful_report_without_authentication():
    with client_for() as client:
        response = client.post("/v1/reports/check", json=payload(barcode=None))
    assert response.status_code == 200
    result = response.json()
    assert result["assessment_basis"] == "user_confirmed_label"
    assert result["observation"]["barcode"] is None
    assert result["nutrition"]["status"] != "needs_correction"
    assert result["storage"]["status"] == "unavailable"
    assert response.headers["cache-control"] == "no-store"
    assert "submission_id" not in result["observation"]


@pytest.mark.parametrize(
    "header",
    [
        None,
        "Basic alice",
        "Bearer",
        "Bearer invalid",
        "Bearer alice extra",
        pytest.param("Bearer " + "x" * 8193, id="oversized-token"),
    ],
)
def test_missing_or_invalid_auth_preserves_analysis_and_never_saves(header):
    runtime = FakeRuntime()
    with client_for(runtime) as client:
        response = client.post(
            "/v1/reports/check",
            json=payload(),
            headers={} if header is None else {"Authorization": header},
        )
    assert response.status_code == 200
    assert response.json()["storage"]["status"] == "authentication_required"
    assert response.json()["nutrition"] is not None
    assert runtime.store.calls == []


def test_confirmed_report_automatically_saves_without_share_flag_and_redacts_actor():
    runtime = FakeRuntime()
    with client_for(runtime) as client:
        response = client.post(
            "/v1/reports/check", json=payload(), headers={"Authorization": "Bearer alice"}
        )
    assert response.status_code == 200
    assert response.json()["storage"]["status"] == "saved"
    assert response.json()["storage"]["receipt"]["status"] == "candidate"
    assert len(runtime.store.calls) == 1
    assert len(runtime.store.calls[0][0]) == 64
    assert runtime.store.used_event_loop is False
    assert "private-subject" not in response.text and "actor_id" not in response.text
    assert runtime.closed


@pytest.mark.parametrize(
    "error,status",
    [
        (StoreUnavailable(), "unavailable"),
        (StoreQuotaExceeded(), "rate_limited"),
        (StoreConflict(), "conflict"),
    ],
)
def test_save_failures_return_typed_outcome_with_useful_report(error, status):
    runtime = FakeRuntime()
    runtime.store.error = error
    with client_for(runtime) as client:
        response = client.post(
            "/v1/reports/check", json=payload(), headers={"Authorization": "Bearer alice"}
        )
    assert response.status_code == 200
    assert response.json()["storage"]["status"] == status
    assert response.json()["storage"]["receipt"] is None
    assert response.json()["ingredients"]["text"] == "Oats, milk"


def test_authentication_provider_outage_keeps_current_report():
    runtime = FakeRuntime()
    with client_for(runtime) as client:
        response = client.post(
            "/v1/reports/check", json=payload(), headers={"Authorization": "Bearer unavailable"}
        )
    assert response.status_code == 200
    assert response.json()["storage"]["status"] == "unavailable"
    assert runtime.store.calls == []


def test_normalization_correction_is_useful_and_never_saved():
    runtime = FakeRuntime()
    rows = [
        dict(
            row_id="unknown-basis",
            table_id="back",
            nutrient="sugars",
            value=1_000_000,
            unit="g",
            basis={"kind": "quantity", "amount": 0.001, "unit": "g"},
            preparation="as_sold",
        )
    ]
    with client_for(runtime) as client:
        response = client.post(
            "/v1/reports/check", json=payload(rows=rows), headers={"Authorization": "Bearer alice"}
        )
    assert response.status_code == 200
    assert response.json()["nutrition"]["status"] == "needs_correction"
    assert response.json()["storage"]["status"] == "needs_correction"
    assert runtime.store.calls == []


@pytest.mark.parametrize(
    "quantities",
    [
        pytest.param([("protein", 101)], id="mass-over-100g"),
        pytest.param([("sugars", 2), ("added_sugars", 3)], id="added-sugars-over-total"),
        pytest.param([("fat", 2), ("saturated_fat", 3)], id="saturated-fat-over-total"),
    ],
)
def test_inconsistent_quantities_require_correction_before_automatic_save(quantities):
    runtime = FakeRuntime()
    rows = [
        {
            "row_id": nutrient,
            "table_id": "back-table",
            "nutrient": nutrient,
            "value": value,
            "unit": "g",
            "basis": {"kind": "quantity", "amount": 100, "unit": "g"},
            "preparation": "as_sold",
        }
        for nutrient, value in quantities
    ]
    with client_for(runtime) as client:
        response = client.post(
            "/v1/reports/check",
            json=payload(rows=rows),
            headers={"Authorization": "Bearer alice"},
        )
    assert response.status_code == 200
    result = response.json()
    assert result["observation"]["rows"] == rows
    assert result["status"] == "partial"
    assert "nutrition_quantities_need_review" in result["warnings"]
    assert result["storage"]["status"] == "needs_correction"
    assert result["storage"]["receipt"] is None
    assert runtime.store.calls == []


def test_confirmed_barcode_less_report_stages_automatically_for_authenticated_user():
    runtime = FakeRuntime()
    with client_for(runtime) as client:
        response = client.post(
            "/v1/reports/check",
            json=payload(barcode=None),
            headers={"Authorization": "Bearer alice"},
        )
    assert response.status_code == 200
    assert response.json()["storage"]["receipt"]["status"] == "provisional"
    assert runtime.store.calls[0][2] is None


def test_report_retries_reuse_receipt_when_reference_source_disappears(tmp_path):
    runtime = FakeRuntime()
    body = payload(
        provider_references=[
            {
                "provider": "off_snapshot",
                "source_id": "synthetic-catalogue",
                "barcode": CODE,
                "fields": ["identity.name"],
            }
        ]
    )
    with client_for(runtime, catalogue_directory=str(tmp_path)) as client:
        cast(FastAPI, client.app).state.catalogue = FakeCatalogue()
        first = client.post(
            "/v1/reports/check", json=body, headers={"Authorization": "Bearer alice"}
        )
        cast(FastAPI, client.app).state.catalogue = None
        retry = client.post(
            "/v1/reports/check", json=body, headers={"Authorization": "Bearer alice"}
        )
    assert first.status_code == retry.status_code == 200
    assert first.json()["storage"] == retry.json()["storage"]
    assert first.json()["storage"]["status"] == "saved"
    assert len(runtime.store.calls) == 1


def test_historical_community_report_is_read_only_without_current_claim_verdict():
    runtime = FakeRuntime()
    runtime.store.revisions = [candidate_revision()]
    with client_for(runtime) as client:
        response = client.get(f"/v1/products/{CODE}/report")
    assert response.status_code == 200
    result = response.json()
    assert result["assessment_basis"] == "catalogue_historical"
    assert result["storage"]["status"] == "read_only"
    assert all(item["assessment"] is None for item in result["claims"])
    assert runtime.store.calls == [] and runtime.tokens == []


@pytest.mark.parametrize("community_outage", [False, True])
def test_snapshot_report_survives_disabled_or_unavailable_community(tmp_path, community_outage):
    runtime = FakeRuntime() if community_outage else None
    if runtime is not None:
        runtime.store.error = StoreUnavailable()
    with client_for(runtime, catalogue_directory=str(tmp_path)) as client:
        cast(FastAPI, client.app).state.catalogue = FakeCatalogue()
        response = client.get(f"/v1/products/{CODE}/report")
    assert response.status_code == 200
    assert response.json()["resolved"]["off_snapshot"]["status"] == "found"
    assert response.json()["storage"]["status"] == "read_only"


def test_definitive_missing_report_is_404_but_source_outage_is_503(tmp_path):
    runtime = FakeRuntime()
    with client_for(runtime, catalogue_directory=str(tmp_path)) as client:
        cast(FastAPI, client.app).state.catalogue = FakeCatalogue("not_found")
        missing = client.get(f"/v1/products/{CODE}/report")
        cast(FastAPI, client.app).state.catalogue = None
        unavailable = client.get(f"/v1/products/{CODE}/report")
    assert missing.status_code == 404 and missing.json()["status"] == "not_found"
    assert unavailable.status_code == 503 and unavailable.json()["status"] == "unavailable"


def test_report_body_limit_strict_numbers_redaction_and_cors():
    with client_for(cors_origins=["https://unlabel.example"]) as client:
        for content in (b"x" * 32769, iter([b"x" * 20000, b"x" * 20000])):
            response = client.post(
                "/v1/reports/check",
                content=content,
                headers={"Content-Type": "application/json", "Origin": "https://unlabel.example"},
            )
            assert response.status_code == 413
            assert response.headers["access-control-allow-origin"] == "https://unlabel.example"
        for value in ("NaN", "Infinity", "1e999", "1e-400"):
            response = client.post(
                "/v1/reports/check",
                content='{"private":"SECRET", "value":' + value + "}",
                headers={"Content-Type": "application/json"},
            )
            assert response.status_code == 422
            assert response.json()["detail"][0]["type"] == "invalid_json_number"
            assert "SECRET" not in response.text
        invalid = client.post("/v1/reports/check", json={"SECRET-field": "SECRET-value"})
        assert invalid.status_code == 422 and "SECRET" not in invalid.text
        assert all("input" not in item for item in invalid.json()["detail"])
        preflight = client.options(
            "/v1/reports/check",
            headers={
                "Origin": "https://unlabel.example",
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "Authorization,Content-Type",
            },
        )
        assert preflight.status_code == 200


def test_report_metadata_advertises_qualified_analysis_and_separate_comparison_without_ai():
    with client_for() as client:
        meta = client.get("/v1/meta").json()
    assert meta["report_version"] == "label-report-v1"
    assert meta["capabilities"]["label_reports"] is True
    assert meta["capabilities"]["nutrition_analysis"] is True
    assert meta["capabilities"]["ai_explanations"] is False
    assert meta["capabilities"]["comparison"] is True


def test_reviewed_glossary_is_public_and_versioned_without_external_requests():
    with client_for() as client:
        response = client.get("/v1/ingredients/glossary")
    assert response.status_code == 200
    result = response.json()
    assert result["status"] == "ready"
    assert result["glossary_version"] == "ingredients-2026-10-08.1"
    assert result["artifact"]["entry_count"] == len(result["entries"]) == 6
    assert len(result["sources"]) == 6
    assert response.headers["cache-control"] == "no-store"


def test_expanded_functions_work_for_corrected_current_labels_without_identity_or_cloud():
    text = "Unknown spice, ग्वार गम, INS 211, potassium sorbate"
    body = payload(
        barcode=None,
        ingredients={
            "status": "present",
            "text": text,
            "completeness": "partial",
            "origin": "independently_transcribed_package",
        },
    )
    with client_for() as client:
        response = client.post("/v1/reports/check", json=body)
        glossary = client.get("/v1/ingredients/glossary").json()
        meta = client.get("/v1/meta").json()
    assert response.status_code == 200
    result = response.json()
    assert result["ingredients"]["text"] == text
    assert [match["entry"]["entry_id"] for match in result["ingredient_insights"]] == [
        "guar_gum", "sodium_benzoate", "potassium_sorbate"
    ]
    sources = {source["source_id"] for source in result["glossary_sources"]}
    for match in result["ingredient_insights"]:
        assert text[match["start"] : match["end"]] == match["matched_text"]
        assert set(match["entry"]["source_ids"]) <= sources
    assert result["storage"]["status"] == "unavailable"
    assert result["glossary_artifact"] == glossary["artifact"] == meta["glossary"]["artifact"]
    assert result["glossary_version"] == meta["glossary"]["version"]
    assert response.headers["cache-control"] == "no-store"
    assert "ingredients_partial_capture" in result["missing_inputs"]
    assert "allergen_safety_not_assessed" in result["warnings"]


def test_tampered_reviewed_projection_disables_only_explanations(monkeypatch, tmp_path):
    from app.reports.glossary import GlossaryStore

    origin = Path(__file__).resolve().parents[2] / "app/reports/glossary-v2.json"
    value = json.loads(origin.read_text(encoding="utf-8"))
    value["entries"][0]["function_en"] = "Synthetic unreviewed content"
    (tmp_path / "glossary-v2.json").write_text(json.dumps(value), encoding="utf-8")
    monkeypatch.setattr("app.main.GlossaryStore", lambda: GlossaryStore(tmp_path))
    with client_for() as client:
        glossary = client.get("/v1/ingredients/glossary")
        report = client.post("/v1/reports/check", json=payload())
        meta = client.get("/v1/meta").json()
    assert glossary.status_code == 503
    assert glossary.headers["cache-control"] == "no-store"
    assert report.status_code == 200
    assert report.json()["ingredient_insights"] == []
    assert "reviewed_ingredient_glossary_unavailable" in report.json()["warnings"]
    assert meta["glossary"] == {"status": "unavailable", "version": None, "artifact": None}
    assert meta["capabilities"]["label_reports"] is True
    assert meta["capabilities"]["comparison"] is True
    assert "Synthetic unreviewed content" not in glossary.text


def test_long_ins_spacing_stays_a_useful_partial_report_without_match_overflow():
    body = payload(
        ingredients={
            "status": "present",
            "text": "Oats, INS" + " " * 500 + "330",
            "completeness": "partial",
            "origin": "independently_transcribed_package",
        }
    )
    with client_for() as client:
        response = client.post("/v1/reports/check", json=body)
    assert response.status_code == 200
    assert response.json()["ingredient_insights"] == []
    assert response.json()["nutrition"] is not None


@pytest.mark.parametrize(
    "text", ["E330\u00a0(i)", "INS 412\u202f(i)", "E211\u2003(ii)", "lecithin\u2060ase"]
)
def test_unicode_spacing_and_format_controls_cannot_expose_partial_ingredient_matches(text):
    body = payload(
        ingredients={
            "status": "present",
            "text": text,
            "completeness": "partial",
            "origin": "independently_transcribed_package",
        }
    )
    with client_for() as client:
        response = client.post("/v1/reports/check", json=body)
    assert response.status_code == 200
    assert response.json()["ingredients"]["text"] == text
    assert response.json()["ingredient_insights"] == []


def test_invalid_glossary_disables_explanations_without_disabling_reports(monkeypatch):
    def invalid():
        raise ValueError("synthetic-private-path")

    monkeypatch.setattr("app.main.GlossaryStore", invalid)
    with client_for() as client:
        glossary = client.get("/v1/ingredients/glossary")
        report = client.post("/v1/reports/check", json=payload())
        meta = client.get("/v1/meta").json()
    assert glossary.status_code == 503
    assert glossary.json()["code"] == "ingredient_glossary_unavailable"
    assert "synthetic-private-path" not in glossary.text
    assert report.status_code == 200
    assert report.json()["ingredient_insights"] == []
    assert meta["capabilities"]["ingredient_explanations"] is False
    assert meta["capabilities"]["label_reports"] is True


def test_unconfirmed_observation_cannot_get_current_report_or_save():
    runtime = FakeRuntime()
    with client_for(runtime) as client:
        response = client.post(
            "/v1/reports/check",
            json=payload(observation_state="provisional", confirmed=False),
            headers={"Authorization": "Bearer alice"},
        )
    assert response.status_code == 422
    assert runtime.store.calls == []


def test_new_unavailable_provider_reference_has_safe_save_conflict_but_useful_analysis():
    runtime = FakeRuntime()
    body = payload(
        provider_references=[
            {
                "provider": "off_snapshot",
                "source_id": "unavailable-source",
                "barcode": CODE,
                "fields": ["identity.name"],
            }
        ]
    )
    with client_for(runtime) as client:
        response = client.post(
            "/v1/reports/check", json=body, headers={"Authorization": "Bearer alice"}
        )
    assert response.status_code == 200
    assert response.json()["storage"]["status"] == "conflict"
    assert response.json()["nutrition"] is not None
    assert runtime.store.calls == []


def test_barcode_less_confirmed_front_back_context_can_check_numeric_claim():
    body = payload(
        barcode=None,
        rows=[
            {
                "row_id": "fibre",
                "table_id": "back-table",
                "nutrient": "fibre",
                "value": 8,
                "unit": "g",
                "basis": {"kind": "quantity", "amount": 100, "unit": "g"},
                "preparation": "as_sold",
            }
        ],
    )
    body["selected_table_id"] = "back-table"
    body["context"] = {
        "food_category": "ordinary_general_food",
        "form": "solid",
        "preparation": "as_sold",
    }
    with client_for() as client:
        response = client.post("/v1/reports/check", json=body)
    assert response.status_code == 200
    assert response.json()["claims"][0]["assessment"]["status"] == "supported"
    assert response.json()["assessment_basis"] == "user_confirmed_label"


def test_incomplete_front_back_pairing_never_returns_supported_claim():
    body = payload(
        back_confirmed=False,
        rows=[
            {
                "row_id": "fibre",
                "table_id": "back-table",
                "nutrient": "fibre",
                "value": 8,
                "unit": "g",
                "basis": {"kind": "quantity", "amount": 100, "unit": "g"},
                "preparation": "as_sold",
            }
        ],
    )
    body["selected_table_id"] = "back-table"
    body["context"] = {
        "food_category": "ordinary_general_food",
        "form": "solid",
        "preparation": "as_sold",
    }
    with client_for() as client:
        response = client.post("/v1/reports/check", json=body)
    assert response.status_code == 200
    assert all(
        item["assessment"] is None or item["assessment"]["status"] == "insufficient_information"
        for item in response.json()["claims"]
    )


def test_bounded_maximum_rows_claims_and_long_text_do_not_produce_server_error():
    rows = [
        {
            "row_id": f"r{i}",
            "table_id": f"t{i}",
            "nutrient": "sugars",
            "value": 0,
            "unit": "g",
            "basis": {"kind": "quantity", "amount": 100, "unit": "g"},
            "preparation": "as_sold",
        }
        for i in range(64)
    ]
    body = payload(
        rows=rows,
        front_claims=[f"Claim {i}: " + "x" * 240 for i in range(16)],
        ingredients={
            "status": "present",
            "text": "Oats, " + "x" * 12000,
            "completeness": "partial",
            "origin": "independently_transcribed_package",
        },
    )
    encoded = json.dumps(body, separators=(",", ":")).encode()
    assert len(encoded) < 32768
    with client_for() as client:
        response = client.post(
            "/v1/reports/check", content=encoded, headers={"Content-Type": "application/json"}
        )
    assert response.status_code == 200
    assert len(response.json()["nutrition"]["tables"]) == 64
    assert len(response.json()["claims"]) == 16
    assert response.json()["sugar"] is None
    assert "selected_table_required" in response.json()["missing_inputs"]


@pytest.mark.parametrize(
    "changes",
    [
        {
            "ingredients": {
                "status": "present",
                "text": "SECRET-copied-provider",
                "completeness": "complete",
                "origin": "open_food_facts",
            }
        },
        {
            "provider_references": [
                {
                    "provider": "generic_food",
                    "source_id": "SECRET-source",
                    "barcode": CODE,
                    "fields": ["nutrition"],
                }
            ]
        },
        {"front_claims": ["SECRET-control\u0000"]},
        {"identity": {"name": "SECRET-name", "language": "unknown"}},
    ],
)
def test_unsupported_origins_controls_and_context_are_sanitized_validation_failures(changes):
    with client_for() as client:
        response = client.post("/v1/reports/check", json=payload(**changes))
    assert response.status_code == 422
    assert "SECRET" not in response.text
    assert all("input" not in item for item in response.json()["detail"])
