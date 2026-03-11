#!/bin/bash
set -euo pipefail

APP_PATH="${1:-dist/MacPasteNext.app}"
EXPECTED_BUNDLE_ID="${EXPECTED_BUNDLE_ID:-io.github.joemild.macpastenext}"
EXPECTED_IDENTITY="${EXPECTED_IDENTITY:-}"
BIN_PATH="$APP_PATH/Contents/MacOS/MacPasteNext"

if [ ! -d "$APP_PATH" ]; then
  echo "App bundle not found: $APP_PATH"
  exit 1
fi

if [ ! -x "$BIN_PATH" ]; then
  echo "Executable not found: $BIN_PATH"
  exit 1
fi

echo "==> Checking bundle identifier"
BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw "$APP_PATH/Contents/Info.plist")"
echo "Bundle identifier: $BUNDLE_ID"
if [ "$BUNDLE_ID" != "$EXPECTED_BUNDLE_ID" ]; then
  echo "Unexpected bundle identifier. Expected '$EXPECTED_BUNDLE_ID', got '$BUNDLE_ID'"
  exit 1
fi

echo "==> Verifying codesign signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
SIGN_INFO="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1)"
echo "$SIGN_INFO" | grep -E "Identifier=|TeamIdentifier=|Authority="

if [ -n "$EXPECTED_IDENTITY" ]; then
  if ! echo "$SIGN_INFO" | grep -q "$EXPECTED_IDENTITY"; then
    echo "Expected signing identity fragment not found: $EXPECTED_IDENTITY"
    exit 1
  fi
fi

echo "==> Launching app binary for smoke test"
"$BIN_PATH" >/tmp/macpastenext-smoke.log 2>&1 &
APP_PID=$!
sleep 5

if ! ps -p "$APP_PID" >/dev/null 2>&1; then
  echo "App process exited too early. Recent output:"
  sed -n '1,200p' /tmp/macpastenext-smoke.log || true
  exit 1
fi

echo "App is running (pid=$APP_PID), stopping now"
kill "$APP_PID"
wait "$APP_PID" || true

echo "==> Running spctl assessment (informational for self-signed builds)"
spctl -a -vv "$APP_PATH" || true

echo "==> Smoke test passed"
