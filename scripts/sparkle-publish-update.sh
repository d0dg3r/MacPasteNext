#!/bin/bash
# Sign an update ZIP with Sparkle's sign_update tool and generate the
# appcast.xml entry that auto-updaters in the wild will consume.
#
# Usage:
#   sparkle-publish-update.sh <update_zip> <tag> [release_notes.md] [output_appcast.xml]
#
# Env:
#   SPARKLE_ED_PRIVATE_KEY      base64 EdDSA private key (required)
#   SPARKLE_VERSION             Sparkle tools version (default: 2.9.2)
#   APP_NAME                    Bundle name for the title (default: MacPasteNext)
#   MIN_OS_VERSION              sparkle:minimumSystemVersion (default: 13.0)
#   RELEASES_DOWNLOAD_BASE_URL  download URL prefix (default: GitHub releases)
set -euo pipefail

UPDATE_ZIP="${1:?usage: sparkle-publish-update.sh <update_zip> <tag> [notes.md] [appcast.xml]}"
TAG="${2:?missing tag argument}"
NOTES_FILE="${3:-}"
OUTPUT_APPCAST="${4:-appcast.xml}"

SPARKLE_VERSION="${SPARKLE_VERSION:-2.9.2}"
APP_NAME="${APP_NAME:-MacPasteNext}"
MIN_OS_VERSION="${MIN_OS_VERSION:-13.0}"
RELEASES_DOWNLOAD_BASE_URL="${RELEASES_DOWNLOAD_BASE_URL:-https://github.com/d0dg3r/MacPasteNext/releases/download}"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This script must run on macOS (Darwin)."
  exit 1
fi

if [ -z "${SPARKLE_ED_PRIVATE_KEY:-}" ]; then
  echo "SPARKLE_ED_PRIVATE_KEY is empty. Generate keys with scripts/sparkle-bootstrap.sh and set the secret."
  exit 1
fi

if [ ! -f "$UPDATE_ZIP" ]; then
  echo "Update zip not found: $UPDATE_ZIP"
  exit 1
fi

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1"
    exit 1
  fi
}

require_command curl
require_command tar
require_command python3

WORK_DIR="$(mktemp -d -t sparkle-publish.XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

TARBALL_URL="https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz"
echo "==> Downloading Sparkle $SPARKLE_VERSION tools"
curl -fSL "$TARBALL_URL" -o "$WORK_DIR/sparkle.tar.xz"
tar -xJf "$WORK_DIR/sparkle.tar.xz" -C "$WORK_DIR"

SIGN_UPDATE="$WORK_DIR/bin/sign_update"
if [ ! -x "$SIGN_UPDATE" ]; then
  echo "sign_update not found at expected path: $SIGN_UPDATE"
  find "$WORK_DIR" -maxdepth 3 -type f | sed 's,^,  ,'
  exit 1
fi

PRIVATE_KEY_FILE="$WORK_DIR/sparkle-private-key.txt"
printf '%s' "$SPARKLE_ED_PRIVATE_KEY" > "$PRIVATE_KEY_FILE"

echo "==> Signing $UPDATE_ZIP with sign_update"
# sign_update prints: sparkle:edSignature="..." length="..."
SIGN_OUTPUT="$("$SIGN_UPDATE" -f "$PRIVATE_KEY_FILE" "$UPDATE_ZIP")"
rm -f "$PRIVATE_KEY_FILE"

ED_SIGNATURE="$(printf '%s' "$SIGN_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')"
LENGTH="$(printf '%s' "$SIGN_OUTPUT" | sed -n 's/.*length="\([^"]*\)".*/\1/p')"
if [ -z "$ED_SIGNATURE" ] || [ -z "$LENGTH" ]; then
  echo "Could not parse sign_update output:"
  echo "$SIGN_OUTPUT"
  exit 1
fi
echo "sparkle:edSignature length=${LENGTH}"

VERSION_NUM="${TAG#v}"
ZIP_BASENAME="$(basename "$UPDATE_ZIP")"
DOWNLOAD_URL="${RELEASES_DOWNLOAD_BASE_URL}/${TAG}/${ZIP_BASENAME}"
PUB_DATE="$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")"

NOTES_HTML=""
if [ -n "$NOTES_FILE" ] && [ -f "$NOTES_FILE" ]; then
  # Markdown -> HTML conversion (separate file so macOS bash 3.2 does not
  # have to parse Python heredocs with embedded backticks).
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  NOTES_HTML="$(python3 "$SCRIPT_DIR/markdown-to-html.py" "$NOTES_FILE")"
fi

echo "==> Writing appcast to $OUTPUT_APPCAST"
{
  cat <<XML
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>${APP_NAME}</title>
        <item>
            <title>Version ${VERSION_NUM}</title>
            <pubDate>${PUB_DATE}</pubDate>
            <sparkle:version>${VERSION_NUM}</sparkle:version>
            <sparkle:shortVersionString>${VERSION_NUM}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>${MIN_OS_VERSION}</sparkle:minimumSystemVersion>
XML
  if [ -n "$NOTES_HTML" ]; then
    printf '            <description><![CDATA[\n%s\n]]></description>\n' "$NOTES_HTML"
  fi
  cat <<XML
            <enclosure
                url="${DOWNLOAD_URL}"
                sparkle:edSignature="${ED_SIGNATURE}"
                length="${LENGTH}"
                type="application/octet-stream" />
        </item>
    </channel>
</rss>
XML
} > "$OUTPUT_APPCAST"

echo "==> appcast ready: $OUTPUT_APPCAST"
