"""Validate tracked source syntax, local Markdown links and private-key boundaries."""

import argparse
import ast
import json
import re
import subprocess
import sys
import tomllib
from pathlib import Path
from urllib.parse import quote, unquote

from version_metadata import backend_version, frontend_version

ROOT = Path(__file__).resolve().parents[1]
TEXT_SUFFIXES = {".py", ".json", ".md", ".yml", ".yaml", ".toml", ".txt", ".ps1", ".sh"}
LINK = re.compile(r"(?<!!)\[[^\]]+\]\((<[^>]+>|[^\s)]+)(?:\s+[^)]*)?\)")
PRIVATE_KEY = re.compile(
    r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----\s+"
    r"[A-Za-z0-9+/=\r\n]{32,}-----END (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"
    r"|AGE-SECRET-KEY-[A-Z0-9]{59}"
)


def source_files(root: Path) -> list[Path]:
    result = subprocess.run(
        ["git", "-C", str(root), "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        check=True,
        capture_output=True,
    )
    return [Path(name.decode("utf-8")) for name in result.stdout.split(b"\0") if name]


def validate(root: Path, files: list[Path]) -> dict:
    errors = []
    counts = {"python": 0, "json": 0, "toml": 0, "markdown": 0, "local_links": 0}
    root = root.resolve()
    for relative in sorted(set(files)):
        path = root / relative
        if not path.is_file():
            continue  # A staged deletion can remain in Git's cached file list.
        if not path.resolve().is_relative_to(root):
            errors.append(f"{relative.as_posix()}: source link escapes workspace")
            continue
        if path.suffix not in TEXT_SUFFIXES:
            continue
        try:
            text = path.read_text(encoding="utf-8-sig")
        except (OSError, UnicodeError):
            errors.append(f"{relative.as_posix()}: cannot read UTF-8 source")
            continue
        if PRIVATE_KEY.search(text):
            errors.append(f"{relative.as_posix()}: private key material must remain untracked")
        if path.suffix in {".py", ".json", ".toml"}:
            kind = {".py": "python", ".json": "json", ".toml": "toml"}[path.suffix]
            try:
                if kind == "python":
                    ast.parse(text, filename=relative.as_posix())
                elif kind == "json":
                    json.loads(text)
                else:
                    tomllib.loads(text)
                counts[kind] += 1
            except (SyntaxError, ValueError):
                # Parser messages can include input; report only file and kind.
                errors.append(f"{relative.as_posix()}: invalid {kind} syntax")
        if path.suffix == ".md":
            counts["markdown"] += 1
            for match in LINK.finditer(text):
                target = match.group(1).strip("<>")
                if re.match(r"^[A-Za-z][A-Za-z0-9+.-]*:|^#|^/", target):
                    continue
                target = unquote(target.split("#", 1)[0].split("?", 1)[0])
                if not target or "{" in target:
                    continue
                counts["local_links"] += 1
                if not (path.parent / target).exists():
                    errors.append(f"{relative.as_posix()}: missing local link {target}")
    return {"counts": counts, "errors": errors}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    try:
        result = validate(ROOT, source_files(ROOT))
        version, build = frontend_version(ROOT)
        backend = backend_version(ROOT)
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        for component, value in {"frontend": f"{version}+{build}", "backend": backend}.items():
            badge = f"https://img.shields.io/badge/{component}-{quote(value, safe='')}-155b4b"
            if badge not in readme:
                result["errors"].append(f"README.md: {component} badge differs from canonical version")
        if not (ROOT / f"contracts/schemas/backend-v{backend}.openapi.json").is_file():
            result["errors"].append("contracts/schemas: current backend OpenAPI export is missing")
    except (OSError, UnicodeError, ValueError, KeyError, subprocess.CalledProcessError):
        print("Unable to enumerate workspace source files.", file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2))
    return int(bool(result["errors"]))


if __name__ == "__main__":
    raise SystemExit(main())
