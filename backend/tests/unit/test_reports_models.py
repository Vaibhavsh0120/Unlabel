import importlib.util

import pytest
from pydantic import ValidationError

from tests.community_fixtures import contribution_dict


def models():
    assert importlib.util.find_spec("app.reports") is not None, "Report package missing"
    from app.reports import models

    return models


def test_report_input_reuses_confirmed_barcode_less_observation_without_share_action():
    request = models().ReportCheckRequest.model_validate(
        {"observation": contribution_dict(barcode=None), "selected_table_id": "back-table"}
    )
    assert request.observation.barcode is None
    assert request.context is None
    assert "permission_to_share" not in request.observation.model_dump()
    assert models().ReportCheckRequest.model_validate_json(request.model_dump_json()) == request


def test_unconfirmed_input_cannot_be_presented_as_current_label_report():
    with pytest.raises(ValidationError):
        models().ReportCheckRequest.model_validate(
            {
                "observation": contribution_dict(
                    observation_state="provisional",
                    confirmed=False,
                    capture_method="ocr_unconfirmed",
                )
            }
        )


@pytest.mark.parametrize(
    "extra",
    [
        {"photo": "private"},
        {"health_score": 90},
        {"storage": {"status": "saved"}},
        {
            "context": {
                "food_category": "ordinary_general_food",
                "form": "powder",
                "preparation": "as_sold",
            }
        },
        {"selected_table_id": "x" * 65},
    ],
)
def test_report_request_rejects_unowned_or_unbounded_fields(extra):
    with pytest.raises(ValidationError):
        models().ReportCheckRequest.model_validate({"observation": contribution_dict(), **extra})


def test_storage_outcome_does_not_claim_success_without_receipt():
    assert models().StorageOutcome(status="unavailable").receipt is None
    with pytest.raises(ValidationError):
        models().StorageOutcome(status="saved")
    with pytest.raises(ValidationError):
        models().StorageOutcome(status="unavailable", warnings=["x"] * 101)


def test_report_failure_is_typed_bounded_and_contains_no_exception_details():
    assert (
        models()
        .ReportFailure(status="unavailable", code="ingredient_glossary_unavailable")
        .warnings
        == []
    )
    with pytest.raises(ValidationError):
        models().ReportFailure(status="unavailable", code="private exception detail")


def test_current_report_retains_public_input_without_exposing_transport_or_private_profile():
    assert importlib.util.find_spec("app.reports.service") is not None, "Report service missing"
    from app.reports.service import report_from_observation

    report = report_from_observation(
        models().ReportCheckRequest.model_validate({"observation": contribution_dict()})
    )
    payload = report.model_dump(mode="json")
    assert "submission_id" not in payload["observation"]
    assert not {"profile", "raw_ocr", "photo", "health_score", "winner"} & payload.keys()
    assert models().LabelReport.model_validate_json(report.model_dump_json()) == report
