#!/bin/bash
# Builds MacroPlus.app — a distributable macOS application bundle.
set -euo pipefail

APP_NAME="MacroPlus"
BUNDLE_ID="com.macroplus.app"
VERSION="1.0"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/.build/release"
APP="$ROOT/$APP_NAME.app"

echo "▶ Compiling (release)…"
swift build -c release

echo "▶ Generating icon…"
swift "$ROOT/tools/generate_icon.swift" "$ROOT/Resources/$APP_NAME.iconset" >/dev/null
iconutil -c icns "$ROOT/Resources/$APP_NAME.iconset" -o "$ROOT/Resources/$APP_NAME.icns"

echo "▶ Assembling bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/$APP_NAME.icns" "$APP/Contents/Resources/$APP_NAME.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHumanReadableCopyright</key><string>MacroPlus</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>MacroPlus sends mouse and keyboard events to automate clicks and macros.</string>
</dict>
</plist>
PLIST

echo "▶ Code signing…"
# Prefer a stable signing identity so macOS keeps Accessibility / Input Monitoring
# grants across rebuilds. Fall back to ad-hoc if none is available.
SIGN_ID="$(security find-identity -p codesigning -v 2>/dev/null | awk -F'"' '/[0-9]+\)/{print $2; exit}')"
if [ -n "$SIGN_ID" ]; then
    echo "  using identity: $SIGN_ID"
    codesign --force --deep --sign "$SIGN_ID" "$APP" 2>/dev/null \
        && echo "  signed" || { echo "  identity sign failed, using ad-hoc"; codesign --force --deep --sign - "$APP"; }
else
    echo "  no identity found, ad-hoc signing"
    codesign --force --deep --sign - "$APP" 2>/dev/null || echo "  (codesign skipped)"
fi

echo "✅ Built $APP"
echo "   Run with: open \"$APP\""
