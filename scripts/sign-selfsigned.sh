#!/bin/bash
set -euo pipefail

APP_PATH="${1:-dist/MacPasteNext.app}"

if [ ! -d "$APP_PATH" ]; then
  echo "App bundle not found: $APP_PATH"
  exit 1
fi

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
echo "$MAC_CERT_P12_BASE64" | base64 -D > "$P12_FILE"

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

echo "==> Signing app with identity: $MAC_CERT_IDENTITY"
codesign --force --deep --sign "$MAC_CERT_IDENTITY" "$APP_PATH"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | rg "Identifier=|TeamIdentifier=|Authority="

echo "==> Signing complete"
