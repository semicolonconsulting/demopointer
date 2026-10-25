#!/usr/bin/env bash
# Builds DemoPointer.app into ./build for local use. Needs Xcode 16 or later.
#
# Signs ad-hoc by default. macOS ties the Screen Recording permission to the signature, so an
# ad-hoc build loses the permission on every rebuild. Set SIGN_IDENTITY (and TEAM_ID) to an
# "Apple Development" identity to keep it:
#   SIGN_IDENTITY="Apple Development" TEAM_ID=ABCDE12345 ./scripts/build-app.sh
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="${CONFIG:-Release}"
DERIVED="build/DerivedData"

xcodebuild build \
    -project DemoPointer.xcodeproj \
    -scheme DemoPointer \
    -configuration "$CONFIG" \
    -derivedDataPath "$DERIVED" \
    -destination "generic/platform=macOS" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="${SIGN_IDENTITY:--}" \
    DEVELOPMENT_TEAM="${TEAM_ID:-}" \
    | grep -E "warning:|error:|BUILD (SUCCEEDED|FAILED)" || true

APP="$DERIVED/Build/Products/$CONFIG/DemoPointer.app"
[[ -d "$APP" ]] || { echo "Build failed: $APP not found" >&2; exit 1; }

rm -rf build/DemoPointer.app
ditto "$APP" build/DemoPointer.app
echo "Built build/DemoPointer.app"
