"""Manually acquire pinned browser OCR assets, or verify their tracked hashes offline."""

import argparse
import base64
import gzip
import hashlib
import io
import json
import re
import tarfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "frontend/web/ocr"
MODEL_COMMIT = "87416418657359cb625c412a48b6e1d6d41c29bd"
PACKAGE_VERSION = "7.0.0"
PURPOSE = "Local English/Hindi label OCR; images and OCR text never uploaded"
MAX_MANIFEST_BYTES = 64 * 1024
MAX_ASSET_BYTES = 16 * 1024 * 1024
MODEL_HASHES = {
    "eng": "7d4322bd2a7749724879683fc3912cb542f19906c83bcc1a52132556427170b2",
    "hin": "4c73ffc59d497c186b19d1e90f5d721d678ea6b2e277b719bee4e2af12271825",
}
PACKAGES = {
    "tesseract.js": "exPBkd+z+wM1BuMkx/Bjv43OeLBxhL5kKWsz/9JY+DXcXdiBjiAch0V49QR3oAJqCaL5qURE0vx9Eo+G5YE7mA==",
    "tesseract.js-core": "WnNH518NzmbSq9zgTPeoF8c+xmilS8rFIl1YKbk/ptuuc7p6cLNELNuPAzcmsYw450ca6bLa8j3t0VAtq435Vw==",
}


def expected_sources() -> dict[str, dict]:
    base = f"https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/{MODEL_COMMIT}"
    sources = {
        package: {
            "name": package,
            "version": PACKAGE_VERSION,
            "url": f"https://registry.npmjs.org/{package}/-/{package}-{PACKAGE_VERSION}.tgz",
            "integrity": f"sha512-{integrity}",
            "license": "Apache-2.0",
        }
        for package, integrity in PACKAGES.items()
    }
    sources["tessdata_fast"] = {
        "name": "tessdata_fast",
        "revision": MODEL_COMMIT,
        "url": base,
        "license": "Apache-2.0",
    }
    for language, digest in MODEL_HASHES.items():
        name = f"{language}.traineddata"
        sources[name] = {"name": name, "url": f"{base}/{name}", "sha256": digest}
    return sources


def expected_files() -> dict[str, str]:
    sources = expected_sources()
    engine = sources["tesseract.js"]["url"]
    core = sources["tesseract.js-core"]["url"]
    files = {
        name: engine
        for name in (
            "tesseract.min.js", "worker.min.js",
            "tesseract.min.js.LICENSE.txt", "worker.min.js.LICENSE.txt",
            "licenses/tesseract.js-LICENSE.md",
        )
    }
    files["licenses/tesseract.js-core-LICENSE"] = core
    for variant in ("", "-lstm", "-simd", "-simd-lstm", "-relaxedsimd", "-relaxedsimd-lstm"):
        for extension in (".wasm", ".wasm.js"):
            files[f"core/tesseract-core{variant}{extension}"] = core
    files["licenses/tessdata_fast-LICENSE"] = sources["tessdata_fast"]["url"]
    for language in MODEL_HASHES:
        files[f"lang/{language}.traineddata.gz"] = sources[f"{language}.traineddata"]["url"]
    return files


def download(url: str) -> bytes:
    request = urllib.request.Request(
        url, headers={"User-Agent": "Unlabel-source-vendor"}
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read(100 * 1024 * 1024 + 1)
    if len(data) > 100 * 1024 * 1024:
        raise ValueError("Source exceeds the acquisition byte limit")
    return data


def acquire() -> None:
    TARGET.mkdir(parents=True, exist_ok=True)
    files = []
    sources = []

    def save(name: str, data: bytes, source: str) -> None:
        path = TARGET / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        files.append(
            {
                "path": name,
                "bytes": len(data),
                "sha256": hashlib.sha256(data).hexdigest(),
                "source": source,
            }
        )

    for package, integrity in PACKAGES.items():
        url = f"https://registry.npmjs.org/{package}/-/{package}-{PACKAGE_VERSION}.tgz"
        data = download(url)
        if hashlib.sha512(data).digest() != base64.b64decode(integrity):
            raise ValueError("npm integrity does not match the pinned package")
        sources.append(
            {
                "name": package,
                "version": PACKAGE_VERSION,
                "url": url,
                "integrity": f"sha512-{integrity}",
                "license": "Apache-2.0",
            }
        )
        with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
            for entry in archive.getmembers():
                if not entry.isfile():
                    continue
                name = Path(entry.name).name
                selected = (
                    package == "tesseract.js"
                    and entry.name.startswith("package/dist/")
                    and name
                    in {
                        "tesseract.min.js",
                        "worker.min.js",
                        "tesseract.min.js.LICENSE.txt",
                        "worker.min.js.LICENSE.txt",
                    }
                ) or (
                    package == "tesseract.js-core"
                    and entry.name.startswith("package/")
                    and name.endswith((".wasm", ".wasm.js"))
                )
                license_file = name.upper().startswith(("LICENSE", "NOTICE"))
                if selected or license_file:
                    stream = archive.extractfile(entry)
                    if stream is None:
                        raise ValueError("Missing acquired source member")
                    destination = (
                        f"licenses/{package}-{name}"
                        if license_file
                        else f"core/{name}"
                        if package.endswith("-core")
                        else name
                    )
                    save(destination, stream.read(), url)
    model_base = (
        f"https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/{MODEL_COMMIT}"
    )
    sources.append(
        {
            "name": "tessdata_fast",
            "revision": MODEL_COMMIT,
            "url": model_base,
            "license": "Apache-2.0",
        }
    )
    save(
        "licenses/tessdata_fast-LICENSE", download(f"{model_base}/LICENSE"), model_base
    )
    for language in ("eng", "hin"):
        url = f"{model_base}/{language}.traineddata"
        raw = download(url)
        save(f"lang/{language}.traineddata.gz", gzip.compress(raw, mtime=0), url)
        sources.append(
            {
                "name": f"{language}.traineddata",
                "url": url,
                "sha256": hashlib.sha256(raw).hexdigest(),
            }
        )
    manifest = {
        "schema_version": 1,
        "purpose": PURPOSE,
        "sources": sources,
        "files": sorted(files, key=lambda item: item["path"]),
    }
    (TARGET / "provenance.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )


def bounded_file(path: Path, limit: int) -> bytes:
    if path.is_symlink() or not path.is_file() or not 0 < path.stat().st_size <= limit:
        raise ValueError("OCR source must be a bounded regular file")
    with path.open("rb") as stream:
        data = stream.read(limit + 1)
    if not 0 < len(data) <= limit:
        raise ValueError("OCR source exceeds its byte budget")
    return data


def unique_object(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("OCR manifest contains duplicate JSON keys")
        result[key] = value
    return result


def check() -> None:
    if TARGET.is_symlink() or not TARGET.is_dir():
        raise ValueError("OCR asset directory must be a regular directory")
    manifest = json.loads(
        bounded_file(TARGET / "provenance.json", MAX_MANIFEST_BYTES),
        object_pairs_hook=unique_object,
    )
    if (
        not isinstance(manifest, dict)
        or set(manifest) != {"schema_version", "purpose", "sources", "files"}
        or type(manifest["schema_version"]) is not int
        or manifest["schema_version"] != 1
        or manifest["purpose"] != PURPOSE
    ):
        raise ValueError("Unsupported OCR manifest schema")
    trusted_sources = expected_sources()
    sources = manifest["sources"]
    if not isinstance(sources, list) or len(sources) != len(trusted_sources):
        raise ValueError("OCR manifest must identify every pinned source")
    seen_sources = set()
    for source in sources:
        if (
            not isinstance(source, dict)
            or not isinstance(source.get("name"), str)
            or source["name"] in seen_sources
            or source != trusted_sources.get(source["name"])
        ):
            raise ValueError("OCR manifest source differs from the pinned version")
        seen_sources.add(source["name"])
    trusted_files = expected_files()
    files = manifest["files"]
    if not isinstance(files, list) or len(files) != len(trusted_files):
        raise ValueError("OCR manifest must contain all 21 required assets")
    seen_paths = set()
    for entry in files:
        if (
            not isinstance(entry, dict)
            or set(entry) != {"path", "bytes", "sha256", "source"}
            or not isinstance(entry["path"], str)
            or entry["path"] not in trusted_files
            or entry["path"] in seen_paths
            or entry["source"] != trusted_files[entry["path"]]
            or type(entry["bytes"]) is not int
            or not 0 < entry["bytes"] <= MAX_ASSET_BYTES
            or not isinstance(entry["sha256"], str)
            or re.fullmatch(r"[0-9a-f]{64}", entry["sha256"]) is None
        ):
            raise ValueError("OCR manifest contains an invalid or untrusted asset")
        seen_paths.add(entry["path"])
    root = TARGET.resolve()
    for entry in files:
        source = TARGET / entry["path"]
        if not source.resolve().is_relative_to(root):
            raise ValueError("Acquired path escapes OCR asset directory")
        data = bounded_file(source, MAX_ASSET_BYTES)
        if (
            len(data) != entry["bytes"]
            or hashlib.sha256(data).hexdigest() != entry["sha256"]
        ):
            raise ValueError(f"OCR asset mismatch: {entry['path']}")
    print(f"Verified {len(files)} pinned local OCR assets")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="Verify existing tracked files without network access",
    )
    args = parser.parse_args()
    if not args.check:
        acquire()
    check()


if __name__ == "__main__":
    main()
