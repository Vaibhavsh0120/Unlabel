"""Preview and upsert reviewed packet research; keep one active snapshot and recovery history."""

import argparse
import base64
import gzip
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT), str(ROOT / "backend")]

from app.research_catalogue.images import load_images  # noqa: E402
from app.research_catalogue.models import ResearchImage, ResearchObservation  # noqa: E402

from scripts.data.build_popular_dataset import (  # noqa: E402
    _canonical,
    _manifest,
    _normalise,
    verify_dataset,
)

BASE = ROOT / "data/catalogue/popular-india-v1"
BATCHES = ROOT / "data/catalogue/research-batches"


def read_json(path):
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 8 * 1024**2:
        raise ValueError("Expected a bounded regular JSON file")

    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError("Duplicate JSON field")
            result[key] = value
        return result

    return json.loads(
        path.read_text(encoding="utf-8"),
        object_pairs_hook=pairs,
        parse_constant=lambda _: (_ for _ in ()).throw(ValueError("Non-finite number")),
    )


def snapshot(directory):
    manifest = verify_dataset(directory)
    # verify_dataset returns a manifest after checking every observation/hash.
    decoded = gzip.decompress((directory / "observations.jsonl.gz").read_bytes())
    return manifest, [json.loads(line) for line in decoded.splitlines()]


def product_key(item):
    identity = item["identity"]
    if identity["barcode"]:
        return ("barcode", identity["barcode"])
    fields = tuple(
        (identity.get(k) or "").strip().casefold()
        for k in ["name", "brand", "variant", "quantity", "market"]
    )
    if not all(fields[i] for i in [0, 1, 2, 3]) or fields[4] != "india":
        raise ValueError(
            "Without a barcode, specify name, brand, variant, pack quantity and India market"
        )
    return ("identity", *fields)


def changed_fields(old, new, prefix=""):
    if isinstance(old, dict) and isinstance(new, dict):
        return [
            path
            for key in sorted(old.keys() | new.keys())
            if key != "observation_id"
            for path in changed_fields(old.get(key), new.get(key), prefix + key + ".")
        ]
    return [] if old == new else [prefix.rstrip(".")]


def merge_records(existing, incoming):
    """Full-record replacement: omissions remain unknown, never inherit stale facts."""
    result, plan, seen = list(existing), [], set()
    for entry in incoming:
        if not isinstance(entry, dict) or set(entry) - {
            "observation",
            "replace_entry_ids",
            "image",
        }:
            raise ValueError(
                "Each entry needs observation, optional image and optional replace_entry_ids"
            )
        raw = dict(entry["observation"])
        raw.pop("observation_id", None)
        observation = _normalise(raw)
        ResearchObservation.model_validate(observation)
        key = product_key(observation)
        if key in seen:
            raise ValueError("Duplicate product in incoming batch")
        seen.add(key)
        ids = entry.get("replace_entry_ids", [])
        if not isinstance(ids, list) or any(
            not isinstance(x, str) or not re.fullmatch(r"[a-f0-9]{64}", x) for x in ids
        ):
            raise ValueError("Replacement IDs must be exact observation hashes")
        if not set(ids) <= {x["observation_id"] for x in existing}:
            raise ValueError("Replacement ID is absent from the selected base")
        matched = [
            x
            for x in result
            if x["observation_id"] in ids
            or (
                x["identity"].get("barcode") == key[1]
                if key[0] == "barcode"
                else all(
                    (x["identity"].get(k) or "").strip().casefold() == value
                    for k, value in zip(
                        ["name", "brand", "variant", "quantity", "market"], key[1:], strict=True
                    )
                )
            )
        ]
        for previous in matched:
            if previous["observation_id"] in ids:
                continue
            for field in ["brand", "variant", "quantity", "market"]:
                a, b = previous["identity"].get(field), observation["identity"].get(field)
                if a and b and str(a).casefold().strip() != str(b).casefold().strip():
                    raise ValueError(
                        "Product identity differs; review the exact variant or explicit replacement IDs"
                    )
        removed = {x["observation_id"] for x in matched}
        result = [x for x in result if x["observation_id"] not in removed]
        result.append(observation)
        plan.append(
            {
                "name": observation["identity"]["name"],
                "barcode": observation["identity"]["barcode"],
                "action": "unchanged"
                if len(matched) == 1 and matched[0] == observation
                else "replace"
                if matched
                else "add",
                "previous_entry_ids": sorted(removed),
                "entry_id": observation["observation_id"],
                "changed_fields": sorted(
                    {p for x in matched for p in changed_fields(x, observation)}
                ),
            }
        )
    return sorted(result, key=lambda x: x["observation_id"]), plan


def prepare(batch, base, output):
    if set(batch) != {"schema_version", "products"} or batch["schema_version"] != "1":
        raise ValueError("Batch requires schema_version 1 and products")
    if not isinstance(batch["products"], list) or not 1 <= len(batch["products"]) <= 100:
        raise ValueError("Batch must contain 1 to 100 reviewed products")
    previous, existing = snapshot(base)
    records, plan = merge_records(existing, batch["products"])
    decoded = b"".join(_canonical(item) + b"\n" for item in records)
    compressed = gzip.compress(decoded, mtime=0)
    raw = _canonical(batch)
    inputs = [
        {
            "file": "request.json",
            "kind": "web",
            "sha256": hashlib.sha256(raw).hexdigest(),
            "bytes": len(raw),
        }
    ]
    manifest = _manifest(records, inputs, compressed, decoded)
    receipt = {
        "base_sha256": previous["decoded_sha256"],
        "snapshot_sha256": manifest["decoded_sha256"],
        "changes": plan,
    }
    if manifest["decoded_sha256"] == previous["decoded_sha256"] and not any(
        x.get("image") for x in batch["products"]
    ):
        return base, receipt
    directory = output / manifest["decoded_sha256"]
    images = load_images(
        base / "image_sources.json"
        if (base / "image_sources.json").exists()
        else ROOT / "backend/app/research_catalogue/image_sources.json"
    )
    for entry, change in zip(batch["products"], plan, strict=True):
        if entry.get("image") is None:
            observation = next(x for x in records if x["observation_id"] == change["entry_id"])
            for old_id in change["previous_entry_ids"]:
                image = images.get(old_id)
                if (
                    image is not None
                    and image.source_url == observation["source"]["url"]
                    and image.provider == observation["source"]["provider"]
                ):
                    images[change["entry_id"]] = ResearchImage.model_validate(
                        dict(image.model_dump(), observation_id=change["entry_id"])
                    )
                    break
        if entry.get("image") is not None:
            value = dict(entry["image"], observation_id=change["entry_id"])
            image = ResearchImage.model_validate(value)
            observation = next(x for x in records if x["observation_id"] == change["entry_id"])
            if (
                image.source_url != observation["source"]["url"]
                or image.provider != observation["source"]["provider"]
            ):
                raise ValueError("Image provenance differs from the researched product")
            images[image.observation_id] = image
    files = {
        "observations.jsonl.gz": compressed,
        "manifest.json": _canonical(manifest),
        "request.json": raw,
        "plan.json": _canonical(receipt),
        "image_sources.json": _canonical(
            {
                "schema_version": "1",
                "images": [images[k].model_dump(mode="json") for k in sorted(images)],
            }
        ),
    }
    directory.mkdir(parents=True, exist_ok=True)
    for name, content in files.items():
        target = directory / name
        if target.exists() and target.read_bytes() != content:
            raise ValueError("Existing recovery bundle differs; do not overwrite it")
        if not target.exists():
            target.write_bytes(content)
    verify_dataset(directory)
    return directory, receipt


REMOTE = """import base64,json,sys,tempfile
from pathlib import Path
import psycopg
from pymongo import MongoClient
from app.selfhost.import_sources import import_research
p=json.load(sys.stdin)
try:
 with tempfile.TemporaryDirectory() as work:
  d=Path(work)
  for name,data in p['files'].items():
   if name not in {'manifest.json','observations.jsonl.gz','image_sources.json'}: raise ValueError()
   (d/name).write_bytes(base64.b64decode(data,validate=True))
  with psycopg.connect(p['postgres']) as c, MongoClient(p['mongo'],serverSelectionTimeoutMS=5000) as m:
   result=import_research(c,m.get_database('unlabel_evidence'),Path('/app'),directory=d,expected_base_sha=p['base'])
  print(json.dumps(result))
except Exception:
 print('Research import rejected; credentials and internal diagnostics withheld.',file=sys.stderr)
 sys.exit(1)
"""


def apply_snapshot(directory, receipt, *, ssh=None):
    resources = read_json(ROOT / "infrastructure/production/resources.json")
    payload = {
        "files": {
            name: base64.b64encode((directory / name).read_bytes()).decode()
            for name in ["manifest.json", "observations.jsonl.gz", "image_sources.json"]
        },
        "base": receipt["base_sha256"],
    }
    if ssh:
        protected = ROOT / "infrastructure/production/.secrets"
        pg = quote((protected / "pg-app-importer").read_text().strip(), safe="")
        mongo = quote((protected / "mongo-writer").read_text().strip(), safe="")
        payload["postgres"] = (
            f"postgresql://unlabel_importer:{pg}@{resources['databases']['app']}:5432/unlabel_app"
        )
        payload["mongo"] = (
            f"mongodb://unlabel_writer:{mongo}@{resources['databases']['evidence']}:27017/unlabel_evidence?authSource=unlabel_evidence"
        )
        prefix = [
            "ssh",
            "-o",
            "RemoteCommand=none",
            "-o",
            "RequestTTY=no",
            "-o",
            "BatchMode=yes",
            ssh,
        ]
        app = resources["applications"]["api_service_uuid"]
        container = subprocess.run(
            prefix + [f"docker ps --filter name={shlex.quote(app)} --format '{{{{.Names}}}}'"],
            capture_output=True,
            text=True,
            check=True,
            timeout=30,
        ).stdout.splitlines()[0]
        command = prefix + [
            "docker exec -i " + shlex.quote(container) + " python -c " + shlex.quote(REMOTE)
        ]
    else:
        payload["postgres"] = os.environ["UNLABEL_RESEARCH_DATABASE_URL"]
        payload["mongo"] = os.environ["UNLABEL_RESEARCH_MONGO_URL"]
        command = [sys.executable, "-c", REMOTE]
    result = subprocess.run(
        command, input=json.dumps(payload), text=True, capture_output=True, timeout=180
    )
    if result.returncode:
        raise ValueError(
            "Research import failed; active snapshot not confirmed. Credentials withheld."
        )
    return json.loads(result.stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("batch", type=Path)
    parser.add_argument("--base", type=Path)
    parser.add_argument("--output", type=Path, default=BATCHES)
    parser.add_argument(
        "--apply", action="store_true", help="Publish the reviewed replacement snapshot"
    )
    parser.add_argument("--ssh", help="SSH alias for private production import, e.g. Volcanica")
    args = parser.parse_args()
    pointer = args.output / "current.json"
    base = args.base or (
        args.output / read_json(pointer)["snapshot_sha256"] if pointer.exists() else BASE
    )
    try:
        directory, receipt = prepare(read_json(args.batch), base, args.output)
        print(json.dumps(receipt, ensure_ascii=False, indent=2))
        print("Prepared:", directory)
        if receipt["snapshot_sha256"] == receipt["base_sha256"] and all(
            x["action"] == "unchanged" for x in receipt["changes"]
        ):
            print("Current facts already match; no database write.")
            return 0
        if args.apply:
            print("Imported:", apply_snapshot(directory, receipt, ssh=args.ssh))
            temporary = pointer.with_suffix(".tmp")
            temporary.write_bytes(_canonical({"snapshot_sha256": receipt["snapshot_sha256"]}))
            temporary.replace(pointer)
    except (ValueError, OSError, KeyError, subprocess.SubprocessError) as error:
        print(
            "Research batch failed:",
            type(error).__name__,
            "- check the reviewed input, current snapshot and private configuration.",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
