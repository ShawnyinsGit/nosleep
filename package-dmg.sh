#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/LidFlow.app"
DMG_PATH="$BUILD_DIR/LidFlow.dmg"
APP_NAME="LidFlow"

# Verify app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ App bundle not found. Run ./build.sh first."
    exit 1
fi

echo "📀 Creating DMG for $APP_NAME..."

# Remove old DMG if exists
rm -f "$DMG_PATH"

# Fallback function: use native hdiutil
create_dmg_fallback() {
    local TEMP_DIR
    TEMP_DIR=$(mktemp -d)
    local DMG_STAGING="$TEMP_DIR/staging"
    mkdir -p "$DMG_STAGING"

    # Copy app and create Applications symlink
    cp -R "$APP_BUNDLE" "$DMG_STAGING/"
    ln -s /Applications "$DMG_STAGING/Applications"

    # Create DMG with hdiutil
    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$DMG_STAGING" \
        -ov \
        -format UDZO \
        "$DMG_PATH"

    # Cleanup
    rm -rf "$TEMP_DIR"

    echo "✅ DMG created (basic): $DMG_PATH"
}

# Check if create-dmg is installed
if command -v create-dmg &> /dev/null; then
    echo "Using create-dmg for professional DMG..."

    create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 128 \
        --icon "$APP_NAME.app" 130 190 \
        --app-drop-link 450 190 \
        --no-internet-enable \
        "$DMG_PATH" \
        "$APP_BUNDLE" \
    && echo "✅ DMG created: $DMG_PATH" \
    || {
        echo "⚠️  create-dmg failed, falling back to hdiutil..."
        create_dmg_fallback
    }
else
    echo "⚠️  create-dmg not found. Using hdiutil fallback..."
    echo "   Install create-dmg for better DMGs: brew install create-dmg"
    create_dmg_fallback
fi
