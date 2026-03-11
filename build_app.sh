#!/bin/bash

# Configuration
APP_NAME="MacPasteNext"
BUILD_DIR=".build/release"
DEST_APP="$APP_NAME.app"
BIN_NAME="$APP_NAME"

echo "Building $APP_NAME..."
swift build -c release

if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

echo "Updating $DEST_APP/Contents/MacOS/$BIN_NAME..."
# Ensure the directory exists
mkdir -p "$DEST_APP/Contents/MacOS"

# Copy the universal binary (if created) or the default one
if [ -f ".build/apple/Products/Release/$BIN_NAME" ]; then
    cp ".build/apple/Products/Release/$BIN_NAME" "$DEST_APP/Contents/MacOS/$BIN_NAME"
else
    # Fallback to standard release build path
    cp ".build/release/$BIN_NAME" "$DEST_APP/Contents/MacOS/$BIN_NAME"
fi

chmod +x "$DEST_APP/Contents/MacOS/$BIN_NAME"

echo "Signing $DEST_APP..."
codesign --force --deep --sign - "$DEST_APP"

echo "Done! You can now run $DEST_APP"
