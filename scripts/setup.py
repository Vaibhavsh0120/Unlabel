"""Restore a fresh clone: dependencies, optional encrypted env and committed India data."""

import argparse
import gzip
import hashlib
import json
import os
import subprocess
import sys
import venv
from datetime import datetime
from pathlib import Path

from dev._progress import Progress
from dev._workspace import ROOT, backend_python, config, execute, flutter_executable
from env import EnvError, decrypt_env, decrypt_env_text, prompt_identity


def ensure_env(root: Path, identity: Path | None, non_interactive: bool) -> str:
    target = root / "backend/.env"
    if target.is_symlink():
        raise ValueError("Refusing a symlink at backend/.env.")
    if target.exists():
        if not target.is_file():
            raise ValueError("backend/.env must be a regular file.")
        print("Using existing backend/.env unchanged.", flush=True)
        return "existing"
    if identity is None:
        supplied = os.environ.get("AGE_IDENTITY_FILE")
        if supplied:
            identity = Path(supplied).expanduser()
    encrypted = root / "backend/.env.age"
    if identity is None and encrypted.is_file() and not non_interactive:
        if not sys.stdin.isatty():
            raise ValueError(
                "No interactive terminal: use --identity PATH or --non-interactive."
            )
        answer = input(
            "Restore env: [1] key file, [2] hidden key paste, [3/Enter] safe example: "
        ).strip()
        if answer == "1":
            identity = Path(
                input("Private age key file path: ").strip().strip('"')
            ).expanduser()
        elif answer == "2":
            decrypt_env_text(root, prompt_identity())
            print(
                "Restored backend/.env using the pasted key; no key file was saved.",
                flush=True,
            )
            return "decrypted"
        elif answer not in {"", "3"}:
            raise ValueError("Choose 1, 2 or 3 to restore the environment.")
    if identity is not None:
        decrypt_env(root, identity)
        print("Restored backend/.env from age ciphertext.", flush=True)
        return "decrypted"
    # Exclusive create also protects a file created while the prompt was open.
    content = (root / "backend/.env.example").read_bytes()
    descriptor = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "wb") as output:
        output.write(content)
    print(
        "Created backend/.env from safe example defaults; encrypted values were not restored.",
        flush=True,
    )
    return "example"


def verified_bundle(root: Path) -> tuple[dict, Path]:
    bundle_path = root / config(root)["catalogue_bundle"]
    metadata = json.loads(bundle_path.read_text(encoding="utf-8"))
    if (
        metadata["schema_version"] != "1"
        or metadata["source_file"] != "india-products.jsonl.gz"
    ):
        raise ValueError("Unsupported catalogue bundle manifest.")
    source = bundle_path.parent / metadata["source_file"]
    if source.is_symlink() or not source.is_file():
        raise ValueError("Catalogue source must be a regular committed file.")
    if not 0 < source.stat().st_size <= 100 * 1024 * 1024:
        raise ValueError("Catalogue compressed source exceeds setup budget.")
    digest = hashlib.sha256()
    with Progress(
        "Validate compressed catalogue", total_bytes=source.stat().st_size
    ) as progress:
        with source.open("rb") as compressed_stream:
            for chunk in iter(lambda: compressed_stream.read(1024 * 1024), b""):
                digest.update(chunk)
                progress.advance(len(chunk))
        if (
            digest.hexdigest() != metadata["compressed_sha256"]
            or source.stat().st_size != metadata["compressed_bytes"]
        ):
            raise ValueError("Committed catalogue compressed checksum/size mismatch.")
    digest = hashlib.sha256()
    size = 0
    with Progress(
        "Validate decoded catalogue", total_bytes=metadata["decoded_bytes"]
    ) as progress:
        with gzip.GzipFile(filename=source, mode="rb") as decoded_stream:
            for chunk in iter(lambda: decoded_stream.read(1024 * 1024), b""):
                size += len(chunk)
                if size > 100 * 1024 * 1024:
                    raise ValueError("Decoded catalogue exceeds setup budget.")
                digest.update(chunk)
                progress.advance(len(chunk))
        if (
            size != metadata["decoded_bytes"]
            or digest.hexdigest() != metadata["decoded_sha256"]
        ):
            raise ValueError("Committed catalogue decoded checksum/size mismatch.")
    return metadata, source


def prepare_catalogue(root: Path, *, replace: bool = False) -> str:
    # This function runs under the backend venv so importer/model dependencies are available.
    sys.path.insert(0, str(root / "backend"))
    from app.catalogue.importer import build_catalogue
    from app.catalogue.store import CatalogueStore

    metadata, source = verified_bundle(root)
    directory = root / "backend/storage/runtime/india"
    directory.mkdir(parents=True, exist_ok=True)
    active = directory / "catalogue.sqlite3"
    if active.exists():
        with Progress("Validate existing catalogue"):
            store = CatalogueStore(directory)
        current = store.manifest
        same_source = (
            current.source_sha256 == metadata["decoded_sha256"]
            and current.indexed_products == metadata["indexed_products"]
            and current.source_format == metadata["source_format"]
            and current.source_url == metadata["source_url"]
            and current.exported_at == datetime.fromisoformat(metadata["exported_at"])
            # Earlier importers could index the same JSONL without rich facts.
            and (metadata["source_format"] != "off_jsonl" or store.supports_facts)
        )
        if same_source and store.supports_search:
            print(
                f"Reusing validated catalogue: {current.indexed_products} products.",
                flush=True,
            )
            return "reused"
        if not replace and not same_source:
            print(
                "Keeping a different valid local catalogue. Use --replace-catalogue to adopt the bundle.",
                flush=True,
            )
            return "preserved"
        if same_source and not store.supports_search:
            print(
                "Rebuilding the same source with the current discovery index.",
                flush=True,
            )
    with Progress("Build catalogue index"):
        manifest = build_catalogue(
            source,
            directory,
            source_url=metadata["source_url"],
            source_format=metadata["source_format"],
            exported_at=datetime.fromisoformat(metadata["exported_at"]),
            coverage=metadata["coverage"],
            expected_source_sha256=metadata["decoded_sha256"],
            expected_rows_read=metadata["expected_input_rows"],
            expected_indexed_products=metadata["indexed_products"],
        )
        if (
            manifest.source_sha256 != metadata["decoded_sha256"]
            or manifest.rows_read != metadata["expected_input_rows"]
            or manifest.indexed_products != metadata["indexed_products"]
        ):
            raise ValueError(
                "Built catalogue counts differ from the committed bundle; inspect before running."
            )
    print(
        f"Restored SQLite catalogue: {manifest.indexed_products} products, {active.stat().st_size} bytes.",
        flush=True,
    )
    return "built"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--scope", choices=["all", "backend", "frontend"], default="all"
    )
    parser.add_argument(
        "--identity", type=Path, help="Private age key file kept outside the repository"
    )
    parser.add_argument(
        "--non-interactive",
        action="store_true",
        help="Use safe example defaults if no key is supplied",
    )
    parser.add_argument(
        "--replace-catalogue",
        action="store_true",
        help="Replace a different valid local index with the committed source",
    )
    parser.add_argument("--catalogue-only", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    try:
        # Setup is a bootstrap entry point and can be invoked before the user
        # installs the supported interpreter; keep its actionable version gate.
        if sys.version_info < (3, 12):  # noqa: UP036
            raise ValueError("Install Python 3.12+ to run setup.")
        if args.catalogue_only:
            prepare_catalogue(ROOT, replace=args.replace_catalogue)
            from app.research_catalogue.store import build_research_bundle

            with Progress("Build researched product database"):
                receipt = build_research_bundle(
                    ROOT / "data/catalogue/popular-india-v1",
                    ROOT / "backend/app/research_catalogue/data",
                )
            print(
                f"Restored researched database: {receipt['observation_count']} sourced observations.",
                flush=True,
            )
            return 0
        if args.scope in {"all", "backend"}:
            ensure_env(ROOT, args.identity, args.non_interactive)
            python = backend_python()
            if not python.is_file():
                with Progress("Create backend environment"):
                    venv.EnvBuilder(with_pip=True).create(ROOT / "backend/.venv")
            with Progress("Install locked backend dependencies", animate=False):
                execute(
                    [python, "-m", "pip", "install", "-r", "requirements-dev.lock"],
                    cwd=ROOT / "backend",
                )
            with Progress("Check backend dependencies", animate=False):
                execute([python, "-m", "pip", "check"], cwd=ROOT)
            command = [python, ROOT / "scripts/setup.py", "--catalogue-only"]
            if args.replace_catalogue:
                command.append("--replace-catalogue")
            execute(command, cwd=ROOT)
        if args.scope in {"all", "frontend"}:
            with Progress("Check or download pinned Flutter SDK", animate=False):
                flutter = flutter_executable(install=True)
            with Progress("Restore locked Flutter dependencies", animate=False):
                execute(
                    [flutter, "pub", "get", "--enforce-lockfile"], cwd=ROOT / "frontend"
                )
        print("Setup complete. Start locally: python scripts/run_local.py", flush=True)
        return 0
    except (
        ValueError,
        EnvError,
        OSError,
        KeyError,
        subprocess.CalledProcessError,
    ) as error:
        if isinstance(error, subprocess.CalledProcessError):
            print(
                f"Setup stopped: a tool returned exit code {error.returncode}.",
                file=sys.stderr,
            )
        else:
            print(f"Setup stopped: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
