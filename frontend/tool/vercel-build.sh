#!/usr/bin/env bash
set -euo pipefail

# This toolchain must match the manual native-release workflow.
flutter_version="3.47.4"
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
app_version="$(awk '$1 == "version:" {print $2; exit}' pubspec.yaml)"
test -n "$app_version"
flutter pub get --enforce-lockfile
python3 ../scripts/generate_app_icons.py --check
python3 ../scripts/vendor_web_ocr.py --check
node --test test/local_ocr_web_test.cjs
flutter analyze
flutter test
flutter build web --release \
  --dart-define="BACKEND_BASE_URL=$BACKEND_BASE_URL" \
  --dart-define="APP_VERSION=${app_version%%+*}" \
  --dart-define="BUILD_NUMBER=${app_version#*+}" \
  --dart-define="COMMIT_SHA=${VERCEL_GIT_COMMIT_SHA:-local}"
