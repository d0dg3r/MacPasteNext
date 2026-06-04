#!/bin/bash
# Generate the one-time Sparkle EdDSA keypair used to sign auto-update ZIPs.
# Run this ONCE on macOS. Afterwards:
#   - The PUBLIC key goes into the GitHub Actions variable SPARKLE_PUBLIC_ED_KEY
#     (Settings -> Secrets and variables -> Actions -> Variables tab).
#   - The PRIVATE key goes into the GitHub Actions secret SPARKLE_ED_PRIVATE_KEY
#     (Settings -> Secrets and variables -> Actions -> Secrets tab).
# The private key is also stored locally in your Keychain by generate_keys.
# Lose it and existing installs cannot auto-update anymore (they trust the
# old embedded public key).
set -euo pipefail

SPARKLE_VERSION="${SPARKLE_VERSION:-2.9.2}"
FORCE="${FORCE:-0}"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This script must run on macOS (Darwin)."
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

WORK_DIR="$(mktemp -d -t sparkle-bootstrap.XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

TARBALL_URL="https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz"
echo "==> Downloading Sparkle $SPARKLE_VERSION"
echo "    $TARBALL_URL"
curl -fSL "$TARBALL_URL" -o "$WORK_DIR/sparkle.tar.xz"

echo "==> Extracting Sparkle tools"
tar -xJf "$WORK_DIR/sparkle.tar.xz" -C "$WORK_DIR"

GENERATE_KEYS="$WORK_DIR/bin/generate_keys"
if [ ! -x "$GENERATE_KEYS" ]; then
  echo "generate_keys not found at expected path: $GENERATE_KEYS"
  echo "Contents of the extracted tarball:"
  find "$WORK_DIR" -maxdepth 3 -type f | sed 's,^,  ,'
  exit 1
fi

echo "==> Checking for existing Sparkle EdDSA keypair in Keychain"
set +e
EXISTING_PUBLIC="$("$GENERATE_KEYS" -p 2>/dev/null)"
set -e

if [ -n "$EXISTING_PUBLIC" ] && [ "$FORCE" != "1" ]; then
  echo "Existing Sparkle keypair found in Keychain. Reusing it."
  echo "(Re-run with FORCE=1 to generate a fresh keypair.)"
else
  if [ "$FORCE" = "1" ]; then
    echo "==> FORCE=1 set, generating new keypair (overwrites existing)"
    "$GENERATE_KEYS" -f
  else
    echo "==> Generating new keypair"
    "$GENERATE_KEYS"
  fi
fi

PRIVATE_KEY_FILE="$WORK_DIR/sparkle-private-key.txt"
echo "==> Exporting private key (for the CI secret)"
"$GENERATE_KEYS" -x "$PRIVATE_KEY_FILE"

PUBLIC_KEY="$("$GENERATE_KEYS" -p)"
PRIVATE_KEY="$(cat "$PRIVATE_KEY_FILE")"
rm -f "$PRIVATE_KEY_FILE"

cat <<EOF

================================================================================
 SPARKLE EDDSA KEYS
================================================================================

PUBLIC KEY (safe to commit; goes into GitHub Actions repository VARIABLE):

    Name:  SPARKLE_PUBLIC_ED_KEY
    Value: $PUBLIC_KEY

PRIVATE KEY (DO NOT commit; goes into GitHub Actions repository SECRET):

    Name:  SPARKLE_ED_PRIVATE_KEY
    Value: $PRIVATE_KEY

Next steps:

  1. Open https://github.com/d0dg3r/MacPasteNext/settings/variables/actions
     -> New repository variable
        Name:  SPARKLE_PUBLIC_ED_KEY
        Value: (paste the public key above)

  2. Open https://github.com/d0dg3r/MacPasteNext/settings/secrets/actions
     -> New repository secret
        Name:  SPARKLE_ED_PRIVATE_KEY
        Value: (paste the private key above, single line)

  3. Tag a new release. The release.yml workflow will sign the build
     with this private key, generate an appcast.xml referencing the
     embedded public key, and upload appcast.xml as a release asset.

  4. Keep the private key safe. It also still lives in your local
     Keychain (account "ed25519", service "https://sparkle-project.org").

================================================================================
EOF
