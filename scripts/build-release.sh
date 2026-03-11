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
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SOURCE_ICON_PNG="${APP_ICON_SOURCE:-assets/appicon-cropped.png}"
APP_ICON_NAME="AppIcon"

generate_icns_from_png() {
  local source_png="$1"
  local output_icns="$2"
  local iconset_dir

  iconset_dir="$(mktemp -d "${TMPDIR:-/tmp}/appicon.XXXXXX.iconset")"

  sips -z 16 16 "$source_png" --out "$iconset_dir/icon_16x16.png" >/dev/null
  sips -z 32 32 "$source_png" --out "$iconset_dir/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$source_png" --out "$iconset_dir/icon_32x32.png" >/dev/null
  sips -z 64 64 "$source_png" --out "$iconset_dir/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$source_png" --out "$iconset_dir/icon_128x128.png" >/dev/null
  sips -z 256 256 "$source_png" --out "$iconset_dir/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$source_png" --out "$iconset_dir/icon_256x256.png" >/dev/null
  sips -z 512 512 "$source_png" --out "$iconset_dir/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$source_png" --out "$iconset_dir/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$source_png" --out "$iconset_dir/icon_512x512@2x.png" >/dev/null

  iconutil -c icns "$iconset_dir" -o "$output_icns"
  rm -rf "$iconset_dir"
}

echo "==> Building $APP_NAME ($VERSION)"
swift build -c release

echo "==> Preparing app bundle in $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$BUILD_DIR/$BIN_NAME" "$MACOS_DIR/$BIN_NAME"
chmod +x "$MACOS_DIR/$BIN_NAME"

if [ ! -f "$SOURCE_ICON_PNG" ]; then
  if [ -f "assets/appicon.png" ]; then
    SOURCE_ICON_PNG="assets/appicon.png"
    echo "Using fallback icon source: $SOURCE_ICON_PNG"
  else
    echo "Required icon file missing: $SOURCE_ICON_PNG"
    exit 1
  fi
fi

echo "==> Copying app icon resources"
cp "$SOURCE_ICON_PNG" "$RESOURCES_DIR/appicon.png"
generate_icns_from_png "$SOURCE_ICON_PNG" "$RESOURCES_DIR/$APP_ICON_NAME.icns"

if [ -f "assets/banner.png" ]; then
  cp "assets/banner.png" "$RESOURCES_DIR/banner.png"
fi

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
    <key>CFBundleIconFile</key>
    <string>$APP_ICON_NAME</string>
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
