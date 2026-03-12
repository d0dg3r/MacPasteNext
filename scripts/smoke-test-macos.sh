#!/bin/bash
set -euo pipefail

APP_PATH="${1:-dist/MacPasteNext.app}"
EXPECTED_BUNDLE_ID="${EXPECTED_BUNDLE_ID:-io.github.joemild.macpastenext}"
EXPECTED_IDENTITY="${EXPECTED_IDENTITY:-}"
BIN_PATH="$APP_PATH/Contents/MacOS/MacPasteNext"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
APP_PID=""
LOG_FILE="$(mktemp -t macpastenext-smoke.XXXXXX.log)"

if [ ! -d "$APP_PATH" ]; then
  echo "App bundle not found: $APP_PATH"
  exit 1
fi

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd"
    exit 1
  fi
}

cleanup() {
  if [ -n "$APP_PID" ] && ps -p "$APP_PID" >/dev/null 2>&1; then
    kill "$APP_PID" >/dev/null 2>&1 || true
    wait "$APP_PID" >/dev/null 2>&1 || true
  fi
  rm -f "$LOG_FILE"
}
trap cleanup EXIT

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This script must run on macOS (Darwin)."
  exit 1
fi

require_command plutil
require_command codesign
require_command spctl

if [ ! -x "$BIN_PATH" ]; then
  echo "Executable not found: $BIN_PATH"
  exit 1
fi

if [ ! -f "$INFO_PLIST" ]; then
  echo "Info.plist not found: $INFO_PLIST"
  exit 1
fi

echo "==> Checking bundle identifier"
BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw "$INFO_PLIST")"
echo "Bundle identifier: $BUNDLE_ID"
if [ "$BUNDLE_ID" != "$EXPECTED_BUNDLE_ID" ]; then
  echo "Unexpected bundle identifier. Expected '$EXPECTED_BUNDLE_ID', got '$BUNDLE_ID'"
  exit 1
fi

echo "==> Checking release metadata"
SHORT_VERSION="$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")"
BUILD_VERSION="$(plutil -extract CFBundleVersion raw "$INFO_PLIST")"
if [ -z "$SHORT_VERSION" ] || [ -z "$BUILD_VERSION" ]; then
  echo "Missing CFBundleShortVersionString or CFBundleVersion"
  exit 1
fi
echo "Version: $SHORT_VERSION ($BUILD_VERSION)"

echo "==> Checking required app resources"
for resource in "banner.png" "appicon.png" "AppIcon.icns"; do
  if [ ! -f "$APP_PATH/Contents/Resources/$resource" ]; then
    echo "Missing resource: $resource"
    exit 1
  fi
done

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
"$BIN_PATH" >"$LOG_FILE" 2>&1 &
APP_PID=$!
sleep 5

if ! ps -p "$APP_PID" >/dev/null 2>&1; then
  echo "App process exited too early. Recent output:"
  sed -n '1,200p' "$LOG_FILE" || true
  exit 1
fi

echo "App is running (pid=$APP_PID), stopping now"
kill "$APP_PID"
wait "$APP_PID" || true
APP_PID=""

echo "==> Running spctl assessment (informational for self-signed builds)"
spctl -a -vv "$APP_PATH" || true

echo "==> Smoke test passed"
