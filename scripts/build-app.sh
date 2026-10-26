#!/usr/bin/env bash
# Builds DemoPointer.app into ./build for local use, plus build/DemoPointer-<version>.dmg.
# Needs Xcode 16 or later. Set NO_DMG=1 to skip the disk image.
#
# Signs with your "Apple Development" certificate when the keychain has one, so macOS keeps the Screen
# Recording permission across rebuilds. Otherwise signs ad-hoc, and every rebuild needs the permission
# granted again (scripts/fix-permission.sh). Override with SIGN_IDENTITY, e.g. SIGN_IDENTITY=- for ad-hoc.
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="${CONFIG:-Release}"
TEAM_ID="${TEAM_ID:-C6ZRF9KM22}"
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
    if security find-identity -v -p codesigning | grep -q "Apple Development"; then
        SIGN_IDENTITY="Apple Development"
    else
        SIGN_IDENTITY="-"
    fi
fi
echo "Signing with: $SIGN_IDENTITY"
DERIVED="build/DerivedData"

mkdir -p build
LOG="build/xcodebuild.log"
if ! xcodebuild build \
    -project DemoPointer.xcodeproj \
    -scheme DemoPointer \
    -configuration "$CONFIG" \
    -derivedDataPath "$DERIVED" \
    -destination "generic/platform=macOS" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    > "$LOG" 2>&1; then
    grep -E "error|failed|Failed" "$LOG" | tail -40 >&2
    echo "Build failed; full log in $LOG" >&2
    exit 1
fi
grep -E "warning:|BUILD SUCCEEDED" "$LOG" | grep -v "Metadata extraction skipped" || true

APP="$DERIVED/Build/Products/$CONFIG/DemoPointer.app"
[[ -d "$APP" ]] || { echo "Build failed: $APP not found" >&2; exit 1; }

rm -rf build/DemoPointer.app
ditto "$APP" build/DemoPointer.app
echo "Built build/DemoPointer.app"

if [[ "${NO_DMG:-}" != "1" ]]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" build/DemoPointer.app/Contents/Info.plist)
    ./scripts/make-dmg.sh build/DemoPointer.app "build/DemoPointer-$VERSION.dmg"
fi
