"""Exercise real age encryption with throwaway keys, never the operator identity."""

import importlib.util
import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

SCRIPTS = Path(__file__).resolve().parents[3] / "scripts"


@pytest.fixture
def tool(monkeypatch):
    monkeypatch.syspath_prepend(str(SCRIPTS))
    spec = importlib.util.spec_from_file_location("project_secrets", SCRIPTS / "project_secrets.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture
def repository(tmp_path):
    subprocess.run(["git", "init", "--quiet", str(tmp_path)], check=True)
    (tmp_path / "secrets").mkdir()
    (tmp_path / "scripts/config").mkdir(parents=True)
    (tmp_path / "backend").mkdir()
    (tmp_path / "secrets/local").mkdir()
    (tmp_path / "secrets/manifest.json").write_text(
        json.dumps(
            {
                "schema_version": 1,
                "files": ["backend/.env"],
                "required": ["backend/.env"],
                "patterns": [],
                "directories": ["secrets/local"],
            }
        )
    )
    (tmp_path / ".gitignore").write_text(
        ".env\nsecrets/local/\n.secrets-work-*\n.secrets-work.lock\n"
    )
    (tmp_path / "backend/.env").write_bytes(b"SYNTHETIC_TOKEN=example\r\n")
    (tmp_path / "secrets/local/binary").write_bytes(bytes(range(256)))
    return tmp_path


@pytest.fixture
def identity():
    if not shutil.which("age") or not shutil.which("age-keygen"):
        pytest.skip("Real age executables are required for this integration gate")
    generated = subprocess.run(["age-keygen"], check=True, capture_output=True)
    key = next(
        line
        for line in generated.stdout.decode().splitlines()
        if line.startswith("AGE-SECRET-KEY-1")
    )
    public = (
        subprocess.run(
            ["age-keygen", "-y"], input=(key + "\n").encode(), check=True, capture_output=True
        )
        .stdout.decode()
        .strip()
    )
    return key, public


@pytest.mark.parametrize(
    "agel",
    [
        False,
        pytest.param(
            True,
            marks=pytest.mark.skipif(
                os.name != "nt" or not shutil.which("pwsh"),
                reason="Requires Windows PowerShell profile agel",
            ),
        ),
    ],
)
def test_real_age_roundtrip_fresh_clone_and_preserved_bytes(tool, repository, identity, agel):
    key, public = identity
    originals = {
        name: (repository / name).read_bytes() for name in ["backend/.env", "secrets/local/binary"]
    }
    names = tool.encrypt(repository, recipient=public, agel=agel)
    assert set(names) == set(originals)
    assert (repository / "secrets/project.age").read_bytes().startswith(b"age-encryption.org/v1\n")
    assert key.encode() not in (repository / "secrets/project.age").read_bytes()
    assert tool.verify(repository, private_key=key) == names
    for name in originals:
        (repository / name).unlink()
    assert tool.restore(repository, private_key=key) == names
    for name, value in originals.items():
        assert (repository / name).read_bytes() == value
    # Legacy backend-only setup remains recoverable with the same identity.
    legacy = subprocess.run(
        ["age", "--decrypt", "-i", "-", str(repository / "backend/.env.age")],
        input=(key + "\n").encode(),
        check=True,
        capture_output=True,
    )
    assert legacy.stdout == originals["backend/.env"]
    assert not list(repository.glob(".secrets-work-*"))


def test_restore_preflight_and_force(tool, repository, identity):
    key, public = identity
    tool.encrypt(repository, recipient=public)
    (repository / "backend/.env").write_bytes(b"KEEP_NEW_CONFIG")
    (repository / "secrets/local/binary").unlink()
    with pytest.raises(tool.SecretError, match="differs"):
        tool.restore(repository, private_key=key)
    assert not (repository / "secrets/local/binary").exists()
    assert (repository / "backend/.env").read_bytes() == b"KEEP_NEW_CONFIG"
    tool.restore(repository, private_key=key, overwrite=True)
    assert (repository / "backend/.env").read_bytes() == b"SYNTHETIC_TOKEN=example\r\n"


def test_refresh_cannot_silently_drop_missing_secret(tool, repository, identity):
    _, public = identity
    tool.encrypt(repository, recipient=public)
    before = (repository / "secrets/project.age").read_bytes()
    (repository / "secrets/local/binary").unlink()
    with pytest.raises(tool.SecretError, match="Previously backed-up"):
        tool.encrypt(repository, recipient=public)
    assert (repository / "secrets/project.age").read_bytes() == before


def test_tampered_ciphertext_never_publishes_partial_plaintext(tool, repository, identity):
    key, public = identity
    tool.encrypt(repository, recipient=public)
    path = repository / "secrets/project.age"
    value = bytearray(path.read_bytes())
    value[-1] ^= 1
    path.write_bytes(value)
    (repository / "backend/.env").unlink()
    with pytest.raises(tool.SecretError):
        tool.restore(repository, private_key=key)
    assert not (repository / "backend/.env").exists()
    assert not list(repository.glob(".secrets-work-*"))


@pytest.mark.parametrize(
    "name",
    [
        "../outside",
        "/absolute",
        "backend/../escape",
        "a//b",
        "a\\b",
        "C:/outside",
        "backend/CON",
        "backend/name.",
    ],
)
def test_rejects_unsafe_paths(tool, name):
    with pytest.raises(tool.SecretError):
        tool.relative_name(name)


def test_undeclared_paths_in_backup_index_are_rejected(tool, repository, identity):
    key, public = identity
    tool.encrypt(repository, recipient=public)
    path = repository / "secrets/index.json"
    metadata = json.loads(path.read_text())
    metadata["files"].append(".git/config")
    path.write_text(json.dumps(metadata))
    with pytest.raises(tool.SecretError, match="manifest and index"):
        tool.restore(repository, private_key=key)


def test_failed_second_encryption_preserves_all_previous_backups(
    tool, repository, identity, monkeypatch
):
    _, public = identity
    tool.encrypt(repository, recipient=public)
    original = {
        name: (repository / name).read_bytes()
        for name in [tool.BUNDLE, tool.INDEX, "backend/.env.age"]
    }
    seal = tool.seal
    calls = 0

    def fail_second(*args, **kwargs):
        nonlocal calls
        calls += 1
        if calls == 2:
            raise tool.SecretError("Synthetic encryption failure")
        return seal(*args, **kwargs)

    monkeypatch.setattr(tool, "seal", fail_second)
    with pytest.raises(tool.SecretError):
        tool.encrypt(repository, recipient=public)
    assert all((repository / name).read_bytes() == value for name, value in original.items())


def test_git_exclusion_is_required(tool, repository, identity):
    _, public = identity
    (repository / ".gitignore").write_text("")
    with pytest.raises(tool.SecretError, match="not ignored"):
        tool.encrypt(repository, recipient=public)


def test_failed_restore_publication_rolls_back_new_files(tool, repository, monkeypatch):
    names = {"secrets/local/first": b"one", "secrets/local/second": b"two"}
    original_link = tool.os.link
    calls = 0

    def fail_second(*args):
        nonlocal calls
        calls += 1
        if calls == 2:
            raise OSError("Synthetic filesystem failure")
        return original_link(*args)

    monkeypatch.setattr(tool.os, "link", fail_second)
    with tool.workspace(repository) as staging:
        with pytest.raises(tool.SecretError, match="rolled back"):
            tool.publish(repository, names, staging)
    assert all(not (repository / name).exists() for name in names)


def test_operator_key_is_stdin_only_and_errors_are_sanitized(
    tool, repository, identity, monkeypatch
):
    key, public = identity
    tool.encrypt(repository, recipient=public)

    def failure(command, **options):
        assert key not in " ".join(command)
        assert options["input"] == (key + "\n").encode()
        return subprocess.CompletedProcess(command, 1, b"PRIVATE_PARTIAL", b"SENSITIVE_ERROR")

    monkeypatch.setattr(tool.subprocess, "run", failure)
    with pytest.raises(tool.SecretError) as error:
        tool.restore(repository, private_key=key)
    assert "PRIVATE" not in str(error.value) and "SENSITIVE" not in str(error.value)
