#!/bin/bash
set -euo pipefail

APP_PATH="${1:-dist/MacPasteNext.app}"
OUTPUT_DIR="${2:-assets}"
BIN_PATH="$APP_PATH/Contents/MacOS/MacPasteNext"

if [ ! -d "$APP_PATH" ]; then
  echo "App bundle not found: $APP_PATH"
  exit 1
fi

if [ ! -x "$BIN_PATH" ]; then
  echo "App binary not executable: $BIN_PATH"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

cleanup() {
  osascript -e 'tell application "MacPasteNext" to quit' >/dev/null 2>&1 || true
  pkill -f "MacPasteNext.app/Contents/MacOS/MacPasteNext" >/dev/null 2>&1 || true
}
trap cleanup EXIT

capture_mode() {
  local mode="$1"
  local out_file="$2"

  cleanup
  sleep 1
  MACPASTE_FORCE_SHOW_WINDOW=1 MACPASTE_FORCE_APPEARANCE="$mode" "$BIN_PATH" >/tmp/macpastenext-screenshot.log 2>&1 &
  APP_PID=$!
  sleep 4

  # Best-effort focus to make screenshot consistent.
  osascript -e 'tell application "System Events" to tell process "MacPasteNext" to set frontmost to true' >/dev/null 2>&1 || true
  sleep 1

  screencapture -x "$out_file"

  if ps -p "$APP_PID" >/dev/null 2>&1; then
    kill "$APP_PID" >/dev/null 2>&1 || true
    wait "$APP_PID" >/dev/null 2>&1 || true
  fi
}

echo "==> Capturing dark mode screenshot"
capture_mode "dark" "$OUTPUT_DIR/screenshot-dark.png"

echo "==> Capturing light mode screenshot"
capture_mode "light" "$OUTPUT_DIR/screenshot-light.png"

echo "==> Verifying screenshots are different"
if cmp -s "$OUTPUT_DIR/screenshot-dark.png" "$OUTPUT_DIR/screenshot-light.png"; then
  echo "Dark and light screenshots are identical. Failing capture."
  exit 1
fi

echo "Screenshots written to $OUTPUT_DIR"
