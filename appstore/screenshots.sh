#!/usr/bin/env bash
# Draws the Mac App Store screenshots (appstore/Screenshots.swift) into build/appstore-screenshots.
# Run scripts/build-app.sh first: the app icon and version come from the built app.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/DemoPointer.app"
[[ -d "$APP" ]] || { echo "Run scripts/build-app.sh first" >&2; exit 1; }
OUT="build/appstore-screenshots"
mkdir -p "$OUT"

# The built Info.plist is embedded so the welcome window shows the app's version. -D APPSTORE matches the App Store
# build: no Check for Updates.
plutil -convert xml1 -o build/screenshots-Info.plist "$APP/Contents/Info.plist"
swiftc -O -swift-version 5 -D APPSTORE -o build/screenshots appstore/Screenshots.swift \
    DemoPointer/Settings.swift DemoPointer/SettingsWindow.swift DemoPointer/LoginItem.swift DemoPointer/StatusIcon.swift \
    -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker build/screenshots-Info.plist
build/screenshots "$OUT" "$PWD/$APP"
rm build/screenshots build/screenshots-Info.plist
echo "Screenshots in $OUT"
