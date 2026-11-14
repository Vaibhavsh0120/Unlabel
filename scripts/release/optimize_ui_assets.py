"""Derive lossless auth WebP and a wordmark-only font; retain original sources."""

import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "frontend/design_sources/runtime-assets.json"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.check:
        manifest = json.loads(MANIFEST.read_text())
        for item in manifest["assets"]:
            for prefix in ("source", "runtime"):
                path = ROOT / item[prefix]
                if digest(path) != item[prefix + "_sha256"]:
                    raise SystemExit(f"Asset hash differs: {item[prefix]}")
        print("Verified retained UI sources and runtime asset hashes.")
        return
    from fontTools import subset
    from fontTools.ttLib import TTFont
    from fontTools.varLib.instancer import instantiateVariableFont
    from PIL import Image

    items = []
    for name in ("garden", "garden-dark", "mascot", "sprout"):
        source = ROOT / f"frontend/design_sources/artwork/auth/{name}.png"
        old = ROOT / f"frontend/assets/artwork/auth/{name}.png"
        source.parent.mkdir(parents=True, exist_ok=True)
        if not source.exists():
            old.rename(source)
        target = ROOT / f"frontend/assets/artwork/auth/{name}.webp"
        with Image.open(source) as original:
            original.save(target, "WEBP", lossless=True, exact=True, method=6)
            with Image.open(target) as result:
                if original.convert("RGBA").tobytes() != result.convert("RGBA").tobytes():
                    raise SystemExit("Lossless image validation failed")
        items.append((source, target, "Lossless WebP; identical RGBA pixels and dimensions"))

    source = ROOT / "frontend/assets/brand/fonts/CormorantGaramond-Variable.ttf"
    target = ROOT / "frontend/assets/brand/fonts/UnlabelStartup-Wordmark.ttf"
    font = TTFont(source, recalcTimestamp=False)
    instantiateVariableFont(font, {"wght": 400}, inplace=True)
    options = subset.Options()
    options.recalc_timestamp = False
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(text="Unlabel")
    subsetter.subset(font)
    for record in font["name"].names:
        if record.nameID in (1, 4, 6, 16, 21):
            record.string = "UnlabelStartupWordmark".encode(record.getEncoding())
    font.save(target)
    font.close()
    items.append((source, target, "Regular 400 instance; only the literal startup wordmark Unlabel; derived family renamed"))
    manifest = {"schema_version": "1", "assets": [
        {"source": str(source.relative_to(ROOT)).replace("\\", "/"),
         "runtime": str(target.relative_to(ROOT)).replace("\\", "/"),
         "source_sha256": digest(source), "runtime_sha256": digest(target),
         "source_bytes": source.stat().st_size, "runtime_bytes": target.stat().st_size,
         "derivation": note} for source, target, note in items
    ]}
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    original_bytes = sum(i["source_bytes"] for i in manifest["assets"])
    runtime_bytes = sum(i["runtime_bytes"] for i in manifest["assets"])
    print(f"Verified UI runtime assets: {original_bytes} -> {runtime_bytes} bytes; originals retained.")


if __name__ == "__main__":
    main()
