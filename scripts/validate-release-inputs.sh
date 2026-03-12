#!/bin/bash
set -euo pipefail

TAG="${1:-}"

if [ -z "$TAG" ]; then
  echo "Usage: $0 <tag>"
  exit 1
fi

required_files=(
  "CHANGELOG.md"
  "assets/banner.png"
  "scripts/build-release.sh"
  "scripts/extract-changelog.sh"
  "scripts/sign-selfsigned.sh"
  "scripts/smoke-test-macos.sh"
)

echo "==> Validating required release files"
for file in "${required_files[@]}"; do
  if [ ! -f "$file" ]; then
    echo "Missing required file for release: $file"
    exit 1
  fi
done

echo "==> Validating icon source availability"
if [ -f "assets/appicon-cropped.png" ]; then
  echo "Using primary icon source: assets/appicon-cropped.png"
elif [ -f "assets/appicon.png" ]; then
  echo "Primary icon missing, fallback icon source found: assets/appicon.png"
else
  echo "Missing required icon source. Expected one of: assets/appicon-cropped.png, assets/appicon.png"
  exit 1
fi

echo "==> Validating changelog entry for $TAG"
tmp_notes="$(mktemp -t release-notes.XXXXXX.md)"
trap 'rm -f "$tmp_notes"' EXIT
./scripts/extract-changelog.sh "$TAG" CHANGELOG.md "$tmp_notes" require-entry

echo "Release inputs look good for tag $TAG"
