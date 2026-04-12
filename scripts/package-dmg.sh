#!/usr/bin/env bash
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────
APP_NAME="devtail"
BUNDLE_ID="com.leerosen.devtail"
EXECUTABLE="devtail"
VERSION="${VERSION:-1.0.0}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Lee Rosen (RQ4599WP39)}"

# ── Paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/release"
STAGING_DIR="$PROJECT_DIR/.build/package"
APP_BUNDLE="$STAGING_DIR/$APP_NAME.app"
DMG_DIR="$STAGING_DIR/dmg"
DMG_OUTPUT="$STAGING_DIR/$APP_NAME-$VERSION.dmg"

# ── Clean previous packaging artifacts ───────────────────────────────
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# ── Step 1: Build release binary ─────────────────────────────────────
echo "▸ Building release binary…"
swift build -c release --package-path "$PROJECT_DIR"

if [ ! -f "$BUILD_DIR/$EXECUTABLE" ]; then
  echo "✗ Build failed — binary not found at $BUILD_DIR/$EXECUTABLE" >&2
  exit 1
fi

# ── Step 2: Assemble .app bundle ─────────────────────────────────────
echo "▸ Assembling $APP_NAME.app bundle…"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE"

# Compile Liquid Glass app icon
if [ -d "$PROJECT_DIR/icon.icon" ]; then
  echo "▸ Compiling Liquid Glass icon…"
  ICON_INFO_PLIST="${TMPDIR:-/tmp}/devtail-icon-info.$$.plist"
  actool "$PROJECT_DIR/icon.icon" --compile "$APP_BUNDLE/Contents/Resources" \
    --output-format human-readable-text --notices --warnings --errors \
    --output-partial-info-plist "$ICON_INFO_PLIST" \
    --app-icon icon --include-all-app-icons \
    --enable-on-demand-resources NO \
    --development-region en \
    --target-device mac \
    --minimum-deployment-target 26.0 \
    --platform macosx
  rm -f "$ICON_INFO_PLIST"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>icon</string>
    <key>CFBundleIconName</key>
    <string>icon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# ── Step 3: Code sign ───────────────────────────────────────────────
echo "▸ Signing with \"$SIGNING_IDENTITY\"…"
codesign --force --options runtime --timestamp \
  --sign "$SIGNING_IDENTITY" \
  "$APP_BUNDLE"

echo "▸ Verifying signature…"
codesign --verify --verbose=2 "$APP_BUNDLE"

# ── Step 4: Create DMG ──────────────────────────────────────────────
echo "▸ Creating DMG…"
mkdir -p "$DMG_DIR"
cp -R "$APP_BUNDLE" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_DIR" \
  -ov -format UDZO \
  "$DMG_OUTPUT"

# Sign the DMG itself
codesign --force --timestamp \
  --sign "$SIGNING_IDENTITY" \
  "$DMG_OUTPUT"

# ── Done ─────────────────────────────────────────────────────────────
echo ""
echo "✔ $DMG_OUTPUT"
echo ""
echo "To notarize (required for Gatekeeper on other machines):"
echo "  xcrun notarytool submit \"$DMG_OUTPUT\" \\"
echo "    --apple-id YOUR_APPLE_ID \\"
echo "    --team-id RQ4599WP39 \\"
echo "    --password YOUR_APP_SPECIFIC_PASSWORD \\"
echo "    --wait"
echo "  xcrun stapler staple \"$DMG_OUTPUT\""
