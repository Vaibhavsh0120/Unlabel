#!/usr/bin/env bash
set -euo pipefail

# Shared with native CI and local setup; component versions remain independent.
flutter_version="$(python3 ../scripts/release/version_metadata.py --component frontend --format github | sed -n 's/^flutter_version=//p')"
test -n "$flutter_version"
sdk_dir="$PWD/.vercel/flutter-sdk"
if [[ ! -x "$sdk_dir/bin/flutter" ]]; then
  git clone --depth 1 --branch "$flutter_version" https://github.com/flutter/flutter.git "$sdk_dir"
fi
export PATH="$sdk_dir/bin:$PATH"
export CI=true
flutter config --no-analytics
dart --disable-analytics
flutter --version --machine > "$sdk_dir/toolchain.json"
python3 - "$sdk_dir/toolchain.json" "$flutter_version" <<'PY'
import json
import sys
from pathlib import Path

actual = json.loads(Path(sys.argv[1]).read_text())["frameworkVersion"]
if actual != sys.argv[2]:
    raise SystemExit(f"Expected Flutter {sys.argv[2]}, got {actual}")
PY

BACKEND_BASE_URL="${BACKEND_BASE_URL:-https://unlabel.duckdns.org}"
UNLABEL_SELF_HOSTED_AUTH="${UNLABEL_SELF_HOSTED_AUTH:-true}"
python3 ../scripts/release/backend_target.py \
  "$BACKEND_BASE_URL" "$UNLABEL_SELF_HOSTED_AUTH"
flutter pub get --enforce-lockfile
python3 ../scripts/release/generate_app_icons.py --check
python3 ../scripts/release/vendor_web_ocr.py --check
flutter analyze
# Test suites run in maintenance/release CI and during affected local checks.
# Deployments only validate inputs, analyze and compile the exact source.
flutter build web --release --no-pub \
  --dart-define="BACKEND_BASE_URL=$BACKEND_BASE_URL" \
  --dart-define="UNLABEL_SELF_HOSTED_AUTH=$UNLABEL_SELF_HOSTED_AUTH" \
  --dart-define="COMMIT_SHA=${VERCEL_GIT_COMMIT_SHA:-local}"
