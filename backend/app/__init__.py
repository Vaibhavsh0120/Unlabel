"""Unlabel backend; version is independent of the Flutter client."""

import tomllib as _tomllib
from importlib.metadata import version as _installed_version
from pathlib import Path as _Path


def _release_version() -> str:
    # Source deployments (including Vercel) carry pyproject.toml. Installed
    # distributions obtain the same canonical value from package metadata.
    manifest = _Path(__file__).resolve().parents[1] / "pyproject.toml"
    if manifest.is_file():
        with manifest.open("rb") as stream:
            return _tomllib.load(stream)["project"]["version"]
    return _installed_version("unlabel-backend")


__version__ = _release_version()
