"""Build the packaged catalogue using only existing source and runtime dependencies."""

import argparse
import json
from pathlib import Path

from app.catalogue.bundle import build_bundle

BACKEND_DIRECTORY = Path(__file__).resolve().parent


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source-directory",
        type=Path,
        default=BACKEND_DIRECTORY.parent / "data" / "catalogue",
        help="Existing acquired source bundle directory",
    )
    parser.add_argument(
        "--output-directory",
        type=Path,
        default=BACKEND_DIRECTORY / "app" / "catalogue" / "data",
        help="Generated deployment catalogue directory",
    )
    args = parser.parse_args()
    try:
        receipt = build_bundle(args.source_directory, args.output_directory)
    except (ValueError, OSError):
        # Validation exceptions can carry input values; print no source rows or
        # private paths from an artifact assembled in an operator's environment.
        parser.exit(1, "Catalogue build failed: source or generated bundle did not validate.\n")
    print(json.dumps(receipt, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
