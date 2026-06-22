#!/bin/bash
#  Build QwenBridgeBar.app — a macOS menu bar controller for the BLE bridge.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="QwenBridgeBar"
APP_DIR="$SCRIPT_DIR/$APP_NAME.app"

echo "Compiling $APP_NAME.swift …"
swiftc -o "$SCRIPT_DIR/$APP_NAME" \
    -framework Cocoa \
    -framework SwiftUI \
    -target arm64-apple-macos12.0 \
    -suppress-warnings \
    "$SCRIPT_DIR/$APP_NAME.swift"

echo "Bundling $APP_DIR …"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$SCRIPT_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/"
cp "$SCRIPT_DIR/capybara_icon.png" "$APP_DIR/Contents/Resources/"
cp "$SCRIPT_DIR/capybara_icon@2x.png" "$APP_DIR/Contents/Resources/"
cp "$SCRIPT_DIR/avatar.png" "$APP_DIR/Contents/Resources/"
cp "$SCRIPT_DIR/menubar_icon.png" "$APP_DIR/Contents/Resources/"

# Generate AppIcon.icns from capybara.png if not present
if [ ! -f "$SCRIPT_DIR/AppIcon.icns" ]; then
    echo "Generating AppIcon.icns from capybara.png …"
    ICONSET="$SCRIPT_DIR/.tmp.iconset"
    rm -rf "$ICONSET" && mkdir "$ICONSET"
    sips -z 16 16   "$SCRIPT_DIR/capybara.png" --out "$ICONSET/icon_16x16.png" >/dev/null
    sips -z 32 32   "$SCRIPT_DIR/capybara.png" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
    sips -z 32 32   "$SCRIPT_DIR/capybara.png" --out "$ICONSET/icon_32x32.png" >/dev/null
    sips -z 64 64   "$SCRIPT_DIR/capybara.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
    sips -z 128 128 "$SCRIPT_DIR/capybara.png" --out "$ICONSET/icon_128x128.png" >/dev/null
    sips -z 256 256 "$SCRIPT_DIR/capybara.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
    sips -z 256 256 "$SCRIPT_DIR/capybara.png" --out "$ICONSET/icon_256x256.png" >/dev/null
    sips -z 512 512 "$SCRIPT_DIR/capybara.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
    sips -z 512 512 "$SCRIPT_DIR/capybara.png" --out "$ICONSET/icon_512x512.png" >/dev/null
    iconutil -c icns "$ICONSET" -o "$SCRIPT_DIR/AppIcon.icns"
    rm -rf "$ICONSET"
fi
cp "$SCRIPT_DIR/AppIcon.icns" "$APP_DIR/Contents/Resources/"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>QwenBridgeBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.pomelo.qwen-bridge-bar</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
PLIST

rm "$SCRIPT_DIR/$APP_NAME"
echo "✓ Built: $APP_DIR"
echo "  Open with: open $APP_DIR"

# --- DMG packaging (optional) ---
# Usage: ./build.sh dmg
if [ "${1:-}" = "dmg" ]; then
    DMG="$SCRIPT_DIR/$APP_NAME.dmg"
    echo "Creating $DMG …"
    rm -f "$DMG"
    # Create a temporary DMG, copy the app, then convert to compressed read-only
    TMP_DMG="$SCRIPT_DIR/${APP_NAME}-tmp.dmg"
    hdiutil create -ov -volname "$APP_NAME" -fs HFS+ -srcfolder "$APP_DIR" "$TMP_DMG"
    hdiutil convert -ov -format UDZO -imagekey zlib-level=9 "$TMP_DMG" -o "$DMG"
    rm -f "$TMP_DMG"
    echo "✓ DMG: $DMG"
fi
