from datetime import UTC, datetime

import pytest

from app.catalogue.status import snapshot_freshness


@pytest.mark.parametrize(
    ("exported", "due"),
    [
        ((2026, 10, 5), (2027, 7, 5)),
        ((2026, 5, 31), (2027, 2, 28)),
        ((2023, 5, 31), (2024, 2, 29)),
        ((2026, 12, 31), (2027, 9, 30)),
    ],
)
def test_refresh_uses_nine_calendar_months_and_clamps_month_end(exported, due):
    source = datetime(*exported, 12, 19, 34, tzinfo=UTC)
    result = snapshot_freshness(source, now=source)
    assert result.refresh_due_at == datetime(*due, 12, 19, 34, tzinfo=UTC)
    assert result.status == "within_refresh_window"
    assert result.age_seconds == 0


def test_exact_refresh_due_boundary_is_overdue_and_rebuild_does_not_change_age():
    source = datetime(2026, 10, 5, 12, tzinfo=UTC)
    due = datetime(2027, 7, 5, 12, tzinfo=UTC)
    result = snapshot_freshness(source, now=due)
    assert result.status == "refresh_due"
    assert result.age_seconds == int((due - source).total_seconds())


def test_future_source_date_has_unknown_age_instead_of_freshness_claim():
    result = snapshot_freshness(
        datetime(2026, 10, 6, tzinfo=UTC), now=datetime(2026, 10, 5, tzinfo=UTC)
    )
    assert result.status == "source_date_in_future"
    assert result.age_seconds is None


def test_naive_dates_are_refused():
    with pytest.raises(ValueError, match="timezone"):
        snapshot_freshness(datetime(2026, 10, 5), now=datetime(2026, 10, 6, tzinfo=UTC))


def test_timezone_offsets_are_normalized_to_utc():
    source = datetime.fromisoformat("2026-10-05T17:49:34+05:30")
    result = snapshot_freshness(source, now=datetime(2026, 10, 6, tzinfo=UTC))
    assert result.refresh_due_at == datetime(2027, 7, 5, 12, 19, 34, tzinfo=UTC)


@pytest.mark.parametrize(
    "date",
    [
        "0001-01-01T00:00:00+01:00",
        "9999-12-31T23:59:59-01:00",
        "9999-12-31T12:00:00Z",
    ],
)
def test_date_overflow_is_an_unavailable_value_not_an_uncaught_exception(date):
    with pytest.raises(ValueError, match="date range"):
        snapshot_freshness(datetime.fromisoformat(date), now=datetime(2026, 10, 6, tzinfo=UTC))
