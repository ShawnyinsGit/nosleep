#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="NoSleep"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
BUNDLE_CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$BUNDLE_CONTENTS/MacOS"
RESOURCES_DIR="$BUNDLE_CONTENTS/Resources"

echo "🔨 Building NoSleep..."

# Step 1: Swift build
cd "$PROJECT_DIR"
swift build -c release 2>&1
echo "✅ Swift build complete"

# Step 2: Find the built binary
BINARY=$(swift build -c release --show-bin-path)/NoSleep
if [ ! -f "$BINARY" ]; then
    echo "❌ Binary not found at: $BINARY"
    exit 1
fi
echo "📦 Binary found: $BINARY"

# Step 3: Create .app bundle structure
echo "📁 Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Step 4: Copy binary
cp "$BINARY" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Step 5: Copy Info.plist
cp "$PROJECT_DIR/Resources/Info.plist" "$BUNDLE_CONTENTS/Info.plist"

# Step 6: Ad-hoc code signing
echo "🔑 Signing with ad-hoc identity..."
codesign --force --sign - "$APP_BUNDLE" 2>/dev/null || echo "⚠️  Ad-hoc signing skipped (no identity available)"

echo ""
echo "✅ Build complete!"
echo "📦 App bundle: $APP_BUNDLE"
echo ""
echo "To run:  open $APP_BUNDLE"
echo "To DMG:  ./package-dmg.sh"
