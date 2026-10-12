import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "scripts/version_metadata.py"


def module():
    spec = importlib.util.spec_from_file_location("version_metadata_test", SCRIPT)
    assert spec is not None and spec.loader is not None
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


@pytest.fixture
def manifests(tmp_path):
    (tmp_path / "frontend").mkdir()
    (tmp_path / "backend").mkdir()
    (tmp_path / "scripts").mkdir()
    (tmp_path / "frontend/pubspec.yaml").write_text("name: unlabel\nversion: 1.2.3+42\n")
    (tmp_path / "backend/pyproject.toml").write_text('[project]\nversion = "4.5.6"\n')
    (tmp_path / "scripts/workspace.json").write_text('{"flutter_version": "3.47.4"}')
    return tmp_path


def test_component_manifests_are_independent(manifests):
    tool = module()
    assert tool.metadata("frontend", manifests) == {
        "component": "frontend",
        "version": "1.2.3",
        "build_number": "42",
        "pubspec_version": "1.2.3+42",
        "flutter_version": "3.47.4",
    }
    assert tool.metadata("backend", manifests) == {"component": "backend", "version": "4.5.6"}
    (manifests / "frontend/pubspec.yaml").write_text("version: 9.8.7+100\n")
    assert tool.backend_version(manifests) == "4.5.6"


@pytest.mark.parametrize(
    "version",
    ["1.2.3", "01.2.3+1", "1.2.3+0", "1.2.3+2147483648", "1.2.3+1\nversion: 4.5.6+7"],
)
def test_invalid_or_ambiguous_frontend_metadata_is_rejected(manifests, version):
    (manifests / "frontend/pubspec.yaml").write_text(f"version: {version}\n")
    with pytest.raises(ValueError):
        module().frontend_version(manifests)


def test_metadata_cli_is_cwd_independent_and_outputs_canonical_github_values(tmp_path):
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--component", "frontend", "--format", "github"],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        check=True,
    )
    values = dict(line.split("=", 1) for line in result.stdout.splitlines())
    expected = module().metadata("frontend")
    assert values == expected
    backend = subprocess.run(
        [sys.executable, str(SCRIPT), "--component", "backend"],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        check=True,
    )
    from app import __version__

    assert json.loads(backend.stdout)["version"] == __version__


def test_installed_backend_without_source_manifest_uses_distribution_metadata(
    tmp_path, monkeypatch
):
    import app

    monkeypatch.setattr(app, "__file__", str(tmp_path / "app/__init__.py"))
    looked_up = []
    monkeypatch.setattr(app, "_installed_version", lambda name: looked_up.append(name) or "2.3.4")
    assert app._release_version() == "2.3.4"
    assert looked_up == ["unlabel-backend"]
