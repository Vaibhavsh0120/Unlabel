import importlib.util
from pathlib import Path
from types import SimpleNamespace

import pytest

ROOT = Path(__file__).resolve().parents[3]


@pytest.fixture
def tool():
    spec = importlib.util.spec_from_file_location(
        "community_tool", ROOT / "scripts/community_catalogue.py"
    )
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_operator_requires_explicit_target_and_hash(tool):
    for arguments in (
        ["pending"],
        ["--project", "synthetic", "approve", "a" * 64],
        ["--project", "synthetic", "inspect", "private-secret"],
    ):
        with pytest.raises(SystemExit):
            tool.parser().parse_args(arguments)


def test_operator_passes_exact_hash_and_supersession(tool):
    calls = []

    class Store:
        def review(self, revision, decision, expected_hash, supersedes):
            calls.append((revision, decision, expected_hash, supersedes))
            return SimpleNamespace(model_dump=lambda **_: {"status": "approved"})

    args = tool.parser().parse_args(
        [
            "--project",
            "synthetic",
            "approve",
            "a" * 64,
            "--expected-hash",
            "b" * 64,
            "--supersedes",
            "c" * 64,
        ]
    )
    assert tool.execute(args, SimpleNamespace(store=Store())) == {"status": "approved"}
    assert calls == [("a" * 64, "approve", "b" * 64, ["c" * 64])]


def test_operator_target_mismatch_never_initializes_credentials(tool, monkeypatch, capsys):
    from app.community import auth
    from app.core import config

    monkeypatch.setattr(
        config,
        "Settings",
        lambda: SimpleNamespace(community_enabled=True, community_project_id="intended"),
    )
    monkeypatch.setattr(
        auth, "create_runtime", lambda *args: pytest.fail("Wrong target must not initialize")
    )
    assert tool.main(["--project", "other", "pending"]) == 1
    assert "Community operation failed" in capsys.readouterr().err


def test_operator_closes_runtime_and_redacts_provider_failure(tool, monkeypatch, capsys):
    from app.community import auth
    from app.community.store import StoreUnavailable
    from app.core import config

    closed = []
    monkeypatch.setattr(
        config,
        "Settings",
        lambda: SimpleNamespace(
            community_enabled=True,
            community_project_id="intended",
            community_database_id="unlabel",
            community_service_account_json=SimpleNamespace(
                get_secret_value=lambda: "synthetic-private"
            ),
        ),
    )
    runtime = SimpleNamespace(store=None, close=lambda: closed.append(True))
    monkeypatch.setattr(auth, "create_runtime", lambda *args: runtime)
    monkeypatch.setattr(tool, "execute", lambda *args: (_ for _ in ()).throw(StoreUnavailable()))
    assert tool.main(["--project", "intended", "pending"]) == 1
    output = capsys.readouterr()
    assert "synthetic-private" not in output.err + output.out
    assert closed == [True]
