#!/bin/bash
set -euo pipefail

APP_NAME="MacPasteNext"
BIN_NAME="MacPasteNext"
BUNDLE_ID="${APP_BUNDLE_ID:-io.github.joemild.macpastenext}"
VERSION="${APP_VERSION:-0.0.0-dev}"
BUILD_DIR=".build/release"
DIST_DIR="dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

echo "==> Building $APP_NAME ($VERSION)"
swift build -c release

echo "==> Preparing app bundle in $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"

cp "$BUILD_DIR/$BIN_NAME" "$MACOS_DIR/$BIN_NAME"
chmod +x "$MACOS_DIR/$BIN_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$BIN_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "==> Build bundle ready: $APP_DIR"
