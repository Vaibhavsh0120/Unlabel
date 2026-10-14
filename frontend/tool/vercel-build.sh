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

: "${BACKEND_BASE_URL:?Set the public BACKEND_BASE_URL in this Vercel project}"
python3 - "$BACKEND_BASE_URL" <<'PY'
import sys
from urllib.parse import urlsplit

url = urlsplit(sys.argv[1])
if url.scheme != "https" or not url.hostname or url.username or url.password or url.query or url.fragment or url.path not in ("", "/"):
    raise SystemExit("BACKEND_BASE_URL must be a public HTTPS origin")
PY
flutter pub get --enforce-lockfile
python3 ../scripts/release/generate_app_icons.py --check
python3 ../scripts/release/vendor_web_ocr.py --check
node --test test/*_web_test.cjs ../firebase/auth-bridge.test.cjs
flutter analyze
# Keep passing negative-case test names out of the deployment error filter.
# Preserve the command's exit status and all diagnostics on an actual failure.
test_log="$PWD/.vercel/flutter-tests.log"
if flutter test --reporter expanded > "$test_log" 2>&1; then
  tail -n 1 "$test_log"
else
  cat "$test_log" >&2
  exit 1
fi
flutter build web --release \
  --dart-define="BACKEND_BASE_URL=$BACKEND_BASE_URL" \
  --dart-define="COMMIT_SHA=${VERCEL_GIT_COMMIT_SHA:-local}"
