from unittest.mock import Mock

import pytest
from app.selfhost import migration_runner


@pytest.mark.parametrize("change", [
    "host=unexpected.invalid", "user=unlabel_api", "dbname=unlabel_auth",
])
def test_migrator_refuses_an_unexpected_destination_before_connecting(monkeypatch, change):
    monkeypatch.setattr("sys.argv", ["migration-runner", "--hold-seconds", "0"])
    monkeypatch.setenv("UNLABEL_MIGRATION_DATABASE_URL",
        "host=lbhz7c20afhuzadjkpsmwmaj user=unlabel_migrator dbname=unlabel_app " + change)
    connect = Mock()
    monkeypatch.setattr(migration_runner.psycopg, "connect", connect)
    with pytest.raises(ValueError, match="Unexpected migration destination"):
        migration_runner.main()
    connect.assert_not_called()
