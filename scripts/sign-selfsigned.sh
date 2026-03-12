#!/bin/bash
set -euo pipefail

APP_PATH="${1:-dist/MacPasteNext.app}"

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

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This script must run on macOS (Darwin)."
  exit 1
fi

require_command python3
require_command security
require_command codesign

: "${MAC_CERT_P12_BASE64:?MAC_CERT_P12_BASE64 is required}"
: "${MAC_CERT_P12_PASSWORD:?MAC_CERT_P12_PASSWORD is required}"
: "${MAC_CERT_IDENTITY:?MAC_CERT_IDENTITY is required}"

KEYCHAIN_NAME="build-signing.keychain-db"
KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-temporary-ci-password}"
P12_FILE="$(mktemp -t mac-cert).p12"

cleanup() {
  rm -f "$P12_FILE"
  security delete-keychain "$KEYCHAIN_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "==> Decoding signing certificate"
export P12_FILE
python3 - <<'PY'
import base64
import binascii
import os
import pathlib
import sys

raw = os.environ["MAC_CERT_P12_BASE64"]
clean = "".join(raw.split())
try:
    decoded = base64.b64decode(clean, validate=True)
except binascii.Error:
    # Some CI secrets are stored with formatting/padding quirks.
    # Fallback keeps compatibility while still failing on unusable payloads.
    try:
        decoded = base64.b64decode(clean, validate=False)
    except binascii.Error as exc:
        print(f"Invalid MAC_CERT_P12_BASE64 payload: {exc}", file=sys.stderr)
        sys.exit(2)

if not decoded:
    print("Decoded MAC_CERT_P12_BASE64 payload is empty", file=sys.stderr)
    sys.exit(2)
pathlib.Path(os.environ["P12_FILE"]).write_bytes(decoded)
PY

echo "==> Creating temporary keychain"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
security set-keychain-settings -lut 21600 "$KEYCHAIN_NAME"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
security list-keychains -d user -s "$KEYCHAIN_NAME" login.keychain-db
security default-keychain -d user -s "$KEYCHAIN_NAME"

echo "==> Importing certificate"
security import "$P12_FILE" \
  -k "$KEYCHAIN_NAME" \
  -P "$MAC_CERT_P12_PASSWORD" \
  -T /usr/bin/codesign \
  -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"

echo "==> Checking imported signing identities"
IDENTITY_LIST="$(security find-identity -v -p codesigning "$KEYCHAIN_NAME" || true)"
echo "$IDENTITY_LIST"
if ! security find-certificate -a -c "$MAC_CERT_IDENTITY" "$KEYCHAIN_NAME" >/dev/null 2>&1; then
  echo "Expected signing certificate not found in keychain: $MAC_CERT_IDENTITY"
  exit 1
fi

echo "==> Signing app with identity: $MAC_CERT_IDENTITY"
codesign --force --deep --sign "$MAC_CERT_IDENTITY" "$APP_PATH"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | grep -E "Identifier=|TeamIdentifier=|Authority="

echo "==> Signing complete"
