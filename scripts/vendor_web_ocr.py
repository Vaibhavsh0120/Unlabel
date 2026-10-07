"""Manually acquire pinned browser OCR assets, or verify their tracked hashes offline."""

import argparse
import base64
import gzip
import hashlib
import io
import json
import tarfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "frontend/web/ocr"
MODEL_COMMIT = "87416418657359cb625c412a48b6e1d6d41c29bd"
PACKAGES = {
    "tesseract.js": "exPBkd+z+wM1BuMkx/Bjv43OeLBxhL5kKWsz/9JY+DXcXdiBjiAch0V49QR3oAJqCaL5qURE0vx9Eo+G5YE7mA==",
    "tesseract.js-core": "WnNH518NzmbSq9zgTPeoF8c+xmilS8rFIl1YKbk/ptuuc7p6cLNELNuPAzcmsYw450ca6bLa8j3t0VAtq435Vw==",
}


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
        url = f"https://registry.npmjs.org/{package}/-/{package}-7.0.0.tgz"
        data = download(url)
        if hashlib.sha512(data).digest() != base64.b64decode(integrity):
            raise ValueError("npm integrity does not match the pinned package")
        sources.append(
            {
                "name": package,
                "version": "7.0.0",
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
                    and (name.endswith(".wasm") or name.endswith(".wasm.js"))
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
        "purpose": "Local English/Hindi label OCR; images and OCR text never uploaded",
        "sources": sources,
        "files": sorted(files, key=lambda item: item["path"]),
    }
    (TARGET / "provenance.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )


def check() -> None:
    manifest = json.loads((TARGET / "provenance.json").read_text(encoding="utf-8"))
    for entry in manifest["files"]:
        path = (TARGET / entry["path"]).resolve()
        if not path.is_relative_to(TARGET.resolve()):
            raise ValueError("Acquired path escapes OCR asset directory")
        data = path.read_bytes()
        if (
            len(data) != entry["bytes"]
            or hashlib.sha256(data).hexdigest() != entry["sha256"]
        ):
            raise ValueError(f"OCR asset mismatch: {entry['path']}")
    print(f"Verified {len(manifest['files'])} pinned local OCR assets")


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
