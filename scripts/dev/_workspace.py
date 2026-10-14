"""Local toolchain helpers. No credentials or machine-specific paths are tracked."""

import json
import os
import shutil
import subprocess
from pathlib import Path
from urllib.parse import urlsplit

from release.version_metadata import frontend_version as read_frontend_version

ROOT = Path(__file__).resolve().parents[2]


def frontend_version(root: Path = ROOT) -> tuple[str, str]:
    """Compatibility helper; canonical parsing lives in version_metadata."""
    return read_frontend_version(root)


def config(root: Path = ROOT) -> dict:
    return json.loads((root / "scripts/config/workspace.json").read_text(encoding="utf-8"))


def backend_python(root: Path = ROOT) -> Path:
    return (
        root
        / "backend/.venv"
        / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
    )


def execute(
    command: list[str | Path], *, cwd: Path, capture: bool = False
) -> subprocess.CompletedProcess:
    return subprocess.run(
        [str(part) for part in command],
        cwd=cwd,
        check=True,
        text=True,
        capture_output=capture,
    )


def sdk_version(executable: str | Path, root: Path = ROOT) -> str:
    result = execute([executable, "--version", "--machine"], cwd=root, capture=True)
    # A first invocation can print toolchain bootstrap progress before the JSON object.
    return json.loads(result.stdout[result.stdout.index("{") :])["frameworkVersion"]


def flutter_executable(root: Path = ROOT, *, install: bool = False) -> Path:
    version = config(root)["flutter_version"]
    relative = "bin/flutter.bat" if os.name == "nt" else "bin/flutter"
    local_sdk = root / ".local-tools/flutter-sdk"
    local = local_sdk / relative
    candidates = [local] if local.is_file() else []
    installed = shutil.which("flutter")
    if installed:
        candidates.append(Path(installed))
    for candidate in candidates:
        try:
            if sdk_version(candidate, root) == version:
                return candidate
        except (OSError, ValueError, KeyError, subprocess.CalledProcessError):
            continue
    if not install:
        raise ValueError(
            f"Flutter {version} is unavailable. Run scripts/setup.py first."
        )
    if local_sdk.exists():
        raise ValueError(
            "Managed Flutter SDK is incomplete or has a different version; inspect it first."
        )
    if not shutil.which("git"):
        raise ValueError(
            "Install Git before setup can download the pinned Flutter SDK."
        )
    local_sdk.parent.mkdir(parents=True, exist_ok=True)
    print(
        f"Installing Flutter {version} in .local-tools/flutter-sdk (global SDK unchanged).",
        flush=True,
    )
    execute(
        [
            "git",
            "clone",
            "--depth",
            "1",
            "--branch",
            version,
            "https://github.com/flutter/flutter.git",
            local_sdk,
        ],
        cwd=root,
    )
    if sdk_version(local, root) != version:
        raise ValueError(
            "Downloaded Flutter SDK version does not match workspace.json."
        )
    return local


def public_origin(value: str) -> str:
    try:
        parsed = urlsplit(value)
        _ = parsed.port
        if (
            parsed.scheme not in {"http", "https"}
            or not parsed.hostname
            or parsed.username
            or parsed.password
            or parsed.query
            or parsed.fragment
            or parsed.path not in {"", "/"}
            or any(c.isspace() for c in value)
            # Flutter's Windows entry point is a batch file. Origins must not
            # carry cmd expansion/operators into its command line.
            or any(c in value for c in '&|<>^%!"`\\()')
        ):
            raise ValueError
    except ValueError:
        raise ValueError(
            "Backend URL must be an HTTP(S) origin without credentials or query."
        ) from None
    return value.rstrip("/")
