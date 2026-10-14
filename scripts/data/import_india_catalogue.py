"""Build a local bounded India catalogue from existing plain/gzip JSONL data."""

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY_ROOT / "backend"))

from app.catalogue.importer import build_catalogue
from app.catalogue.store import DATABASE_FILENAME


def aware_datetime(value: str) -> datetime:
    try:
        result = datetime.fromisoformat(value)
        if result.utcoffset() is None:
            raise ValueError("timezone is required")
        return result
    except ValueError as error:
        raise argparse.ArgumentTypeError(
            "Use an ISO 8601 datetime with a timezone"
        ) from error


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--input", required=True, type=Path, help="Existing local JSONL/gzip file"
    )
    parser.add_argument(
        "--directory",
        type=Path,
        default=REPOSITORY_ROOT / "backend" / "storage" / "runtime" / "india",
        help="Existing catalogue directory (created by the operator)",
    )
    parser.add_argument(
        "--source-url", required=True, help="Official upstream source provenance"
    )
    parser.add_argument("--exported-at", required=True, type=aware_datetime)
    parser.add_argument(
        "--coverage", choices=["sample", "unverified"], default="sample"
    )
    parser.add_argument(
        "--source-format",
        choices=["off_jsonl", "off_csv_projection"],
        default="off_jsonl",
    )
    args = parser.parse_args()
    try:
        manifest = build_catalogue(
            args.input,
            args.directory,
            source_url=args.source_url,
            exported_at=args.exported_at,
            coverage=args.coverage,
            source_format=args.source_format,
        )
        size = (args.directory.resolve() / DATABASE_FILENAME).stat().st_size
    except (ValueError, OSError) as error:
        parser.error(str(error))
    print(
        json.dumps(
            {"manifest": manifest.model_dump(mode="json"), "artifact_bytes": size}
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
