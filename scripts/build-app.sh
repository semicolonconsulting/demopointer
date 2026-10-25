#!/usr/bin/env bash
# Builds DemoPointer.app into ./build. Run on macOS with Xcode or the Command Line Tools installed.
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="${CONFIG:-release}"
APP="build/DemoPointer.app"

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/DemoPointer"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/DemoPointer"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature so macOS can attach the Screen Recording permission to the app.
# Set SIGN_IDENTITY to a "Developer ID Application" / "Apple Development" identity to keep
# the permission across rebuilds.
codesign --force --deep --sign "${SIGN_IDENTITY:--}" "$APP"

echo "Built $APP"
