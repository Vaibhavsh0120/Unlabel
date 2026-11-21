from types import SimpleNamespace
from unittest.mock import MagicMock, Mock

import pytest
from app.selfhost.resources import Resources


def resources(version):
    value = Resources.__new__(Resources)
    value.pool = MagicMock()
    value.settings = SimpleNamespace(community_enabled=False)
    value.catalogue = SimpleNamespace(manifest=SimpleNamespace(indexed_products=24641))
    value.research = Mock()
    value.research.status.return_value = {"observation_count": 243}
    value.mongo, value.cache, value.identity = Mock(), Mock(), Mock()
    value.identity.get.return_value.json.return_value = {"version": version}
    return value


def test_account_health_requires_the_patched_identity_policy_and_profile_migration():
    value = resources("v2.197.0-unlabel.1")
    with pytest.raises(ValueError, match="account policy"):
        value.health()
    value.identity.get.return_value.json.return_value = {"version": "v2.197.0-unlabel.2"}
    value.health()
    statements = value.pool.connection.return_value.__enter__.return_value.execute.call_args_list
    assert any("avatar_preference" in call.args[0] for call in statements)


def test_missing_profile_migration_cannot_advertise_compatible_account_health():
    value = resources("v2.197.0-unlabel.2")
    value.pool.connection.return_value.__enter__.return_value.execute.side_effect = RuntimeError("missing column")
    with pytest.raises(RuntimeError, match="missing column"):
        value.health()
