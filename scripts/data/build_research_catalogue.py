"""Build or verify the separate read-only researched-product runtime database."""

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, default=ROOT / "data/catalogue/popular-india-v1")
    parser.add_argument(
        "--output-dir", type=Path, default=ROOT / "backend/app/research_catalogue/data"
    )
    parser.add_argument(
        "--verify", type=Path, help="Verify an existing generated database without rebuilding"
    )
    args = parser.parse_args()
    sys.path.insert(0, str(ROOT / "backend"))
    from app.research_catalogue.store import (
        build_research_bundle,
        verify_research_bundle,
    )

    try:
        receipt = (
            verify_research_bundle(args.verify)
            if args.verify is not None
            else build_research_bundle(args.source_dir, args.output_dir)
        )
    except (ValueError, OSError):
        parser.exit(1, "Research catalogue validation failed; original catalogue was preserved.\n")
    print(json.dumps(receipt, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
