import importlib.util
import subprocess
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parents[3] / "scripts/env.py"
RECIPIENT = "age19ml0m6z9prakmc2jfhtpu4d8gn8kyn7t3g2td79gl30l7cs97qsqspu45g"


def module():
    spec = importlib.util.spec_from_file_location("env_tool", SCRIPT)
    assert spec is not None and spec.loader is not None
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


@pytest.fixture
def repository(tmp_path):
    (tmp_path / "backend").mkdir()
    (tmp_path / "scripts/config").mkdir(parents=True)
    (tmp_path / "scripts/config/age-recipient.txt").write_text(RECIPIENT + "\n")
    return tmp_path


def mock_age(implementation, monkeypatch, *, returncode=0, output=b"generated"):
    monkeypatch.setattr(implementation.shutil, "which", lambda name: "age.exe")
    calls = []

    def run(command, **kwargs):
        calls.append((command, kwargs))
        Path(command[command.index("-o") + 1]).write_bytes(output)
        return subprocess.CompletedProcess(command, returncode, b"PRIVATE_STDOUT", b"SECRET_STDERR")

    monkeypatch.setattr(implementation.subprocess, "run", run)
    return calls


def test_failed_encrypt_preserves_plaintext_and_previous_ciphertext(repository, monkeypatch):
    implementation = module()
    plaintext = repository / "backend/.env"
    ciphertext = repository / "backend/.env.age"
    plaintext.write_bytes(b"PRIVATE_ENV=value\n")
    ciphertext.write_bytes(b"previous ciphertext")
    mock_age(implementation, monkeypatch, returncode=1, output=b"partial ciphertext")

    with pytest.raises(implementation.EnvError) as raised:
        implementation.encrypt_env(repository)

    assert "PRIVATE" not in str(raised.value)
    assert "SECRET" not in str(raised.value)
    assert plaintext.read_bytes() == b"PRIVATE_ENV=value\n"
    assert ciphertext.read_bytes() == b"previous ciphertext"
    assert sorted(path.name for path in plaintext.parent.iterdir()) == [".env", ".env.age"]


def test_encrypt_uses_fixed_recipient_and_atomically_replaces_ciphertext(repository, monkeypatch):
    implementation = module()
    (repository / "backend/.env").write_bytes(b"fixture plaintext")
    (repository / "backend/.env.age").write_bytes(b"old")
    calls = mock_age(implementation, monkeypatch, output=b"new ciphertext")

    result = implementation.encrypt_env(repository)

    assert result.read_bytes() == b"new ciphertext"
    assert (repository / "backend/.env").read_bytes() == b"fixture plaintext"
    assert calls[0][0][1:3] == ["-r", RECIPIENT]
    assert calls[0][1] == {"capture_output": True, "check": False, "timeout": 120}


def test_decrypt_does_not_overwrite_an_existing_env(repository, monkeypatch):
    implementation = module()
    (repository / "backend/.env").write_bytes(b"existing")
    (repository / "backend/.env.age").write_bytes(b"ciphertext")
    calls = mock_age(implementation, monkeypatch)

    with pytest.raises(implementation.EnvError, match="already exists"):
        implementation.decrypt_env(repository, repository / "private-key.txt")

    assert calls == []
    assert (repository / "backend/.env").read_bytes() == b"existing"


def test_failed_forced_decrypt_preserves_env_and_cleans_partial_output(repository, monkeypatch):
    implementation = module()
    identity = repository / "private-key.txt"
    identity.write_bytes(b"Never open the private identity in Python")
    (repository / "backend/.env").write_bytes(b"existing")
    (repository / "backend/.env.age").write_bytes(b"ciphertext")
    calls = mock_age(implementation, monkeypatch, returncode=1, output=b"partial plaintext")

    with pytest.raises(implementation.EnvError) as raised:
        implementation.decrypt_env(repository, identity, overwrite=True)

    assert "SECRET" not in str(raised.value)
    assert "PRIVATE" not in str(raised.value)
    assert calls[0][0][1:4] == ["--decrypt", "-i", str(identity)]
    assert sorted(path.name for path in (repository / "backend").iterdir()) == [".env", ".env.age"]
    assert (repository / "backend/.env").read_bytes() == b"existing"


def test_successful_decrypt_promotes_private_output_without_reading_identity(
    repository, monkeypatch
):
    implementation = module()
    identity = repository / "private-key.txt"
    identity.write_bytes(b"private identity fixture")
    (repository / "backend/.env.age").write_bytes(b"ciphertext")
    mock_age(implementation, monkeypatch, output=b"restored plaintext")
    original_read = Path.read_bytes

    def read_bytes(path):
        assert path != identity, "Identity contents belong exclusively to age"
        return original_read(path)

    monkeypatch.setattr(Path, "read_bytes", read_bytes)
    result = implementation.decrypt_env(repository, identity)

    assert result.read_bytes() == b"restored plaintext"
    assert sorted(path.name for path in result.parent.iterdir()) == [".env", ".env.age"]


def test_decrypt_refuses_to_clobber_env_created_during_decryption(repository, monkeypatch):
    implementation = module()
    identity = repository / "private-key.txt"
    identity.write_bytes(b"fixture identity")
    (repository / "backend/.env.age").write_bytes(b"ciphertext")
    monkeypatch.setattr(implementation.shutil, "which", lambda name: "age.exe")

    def run(command, **kwargs):
        Path(command[command.index("-o") + 1]).write_bytes(b"decrypted")
        (repository / "backend/.env").write_bytes(b"concurrent env")
        return subprocess.CompletedProcess(command, 0, b"", b"")

    monkeypatch.setattr(implementation.subprocess, "run", run)

    with pytest.raises(implementation.EnvError, match="already exists"):
        implementation.decrypt_env(repository, identity)

    assert (repository / "backend/.env").read_bytes() == b"concurrent env"
    assert sorted(path.name for path in (repository / "backend").iterdir()) == [".env", ".env.age"]


@pytest.mark.parametrize("operation", ["encrypt", "decrypt"])
def test_age_execution_failure_is_sanitized_and_cleans_temporary_files(
    repository, monkeypatch, operation
):
    implementation = module()
    (repository / "backend/.env.age").write_bytes(b"ciphertext")
    identity = repository / "identity.txt"
    identity.write_bytes(b"fixture")
    if operation == "encrypt":
        (repository / "backend/.env").write_bytes(b"fixture")
    monkeypatch.setattr(implementation.shutil, "which", lambda name: "age.exe")

    def run(command, **kwargs):
        raise subprocess.TimeoutExpired(command, 120, output=b"PRIVATE", stderr=b"SECRET")

    monkeypatch.setattr(implementation.subprocess, "run", run)
    with pytest.raises(implementation.EnvError) as raised:
        if operation == "encrypt":
            implementation.encrypt_env(repository)
        else:
            implementation.decrypt_env(repository, identity)

    assert "PRIVATE" not in str(raised.value)
    assert "SECRET" not in str(raised.value)
    assert not list((repository / "backend").glob(".env-*.tmp"))


def test_missing_age_does_not_modify_files(repository, monkeypatch):
    implementation = module()
    (repository / "backend/.env").write_bytes(b"fixture")
    monkeypatch.setattr(implementation.shutil, "which", lambda name: None)
    with pytest.raises(implementation.EnvError, match="Install age"):
        implementation.encrypt_env(repository)
    assert not list((repository / "backend").glob(".env-*.tmp"))


def test_pasted_key_uses_stdin_not_arguments_or_key_files(repository, monkeypatch):
    implementation = module()
    (repository / "backend/.env.age").write_bytes(b"ciphertext")
    calls = mock_age(implementation, monkeypatch, output=b"restored")
    key = "AGE-SECRET-KEY-1SYNTHETICFIXTURE"
    result = implementation.decrypt_env_text(repository, key)
    command, options = calls[0]
    assert command[command.index("-i") + 1] == "-"
    assert key not in str(command)
    assert options["input"] == (key + "\n").encode()
    assert result.read_bytes() == b"restored"
    assert sorted(path.name for path in repository.iterdir()) == ["backend", "scripts"]
    assert sorted(path.name for path in result.parent.iterdir()) == [".env", ".env.age"]


def test_failed_pasted_key_decryption_leaves_no_plaintext_or_identity(repository, monkeypatch):
    implementation = module()
    (repository / "backend/.env.age").write_bytes(b"ciphertext")
    mock_age(implementation, monkeypatch, returncode=1, output=b"partial")
    with pytest.raises(implementation.EnvError):
        implementation.decrypt_env_text(repository, "AGE-SECRET-KEY-1FIXTURE")
    assert sorted(path.name for path in (repository / "backend").iterdir()) == [".env.age"]


def test_hidden_prompt_refuses_echo_fallback(monkeypatch):
    import getpass
    import sys
    import warnings

    implementation = module()
    monkeypatch.setattr(sys.stdin, "isatty", lambda: True)

    def cannot_hide(prompt):
        warnings.warn("No hidden input", getpass.GetPassWarning, stacklevel=1)
        pytest.fail("Must not continue with echoed input")

    monkeypatch.setattr(getpass, "getpass", cannot_hide)
    with pytest.raises(implementation.EnvError, match="cannot hide"):
        implementation.prompt_identity()


def test_invalid_recipient_is_rejected_before_running_age(repository, monkeypatch):
    implementation = module()
    (repository / "backend/.env").write_bytes(b"fixture")
    calls = mock_age(implementation, monkeypatch)
    with pytest.raises(implementation.EnvError, match="recipient"):
        implementation.encrypt_env(repository, "age1bad\nextra")
    assert calls == []


def test_symlink_ciphertext_cannot_redirect_encryption(repository, monkeypatch):
    implementation = module()
    (repository / "backend/.env").write_bytes(b"fixture")
    unrelated = repository / "unrelated.txt"
    unrelated.write_bytes(b"preserve")
    try:
        (repository / "backend/.env.age").symlink_to(unrelated)
    except OSError:
        pytest.skip("Creating symlinks requires Windows developer mode or elevated privileges")
    calls = mock_age(implementation, monkeypatch)
    with pytest.raises(implementation.EnvError, match="symbolic link"):
        implementation.encrypt_env(repository)
    assert calls == []
    assert unrelated.read_bytes() == b"preserve"
