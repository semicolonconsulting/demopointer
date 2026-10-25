#!/usr/bin/env bash
# Builds a Developer ID signed, notarized and stapled DemoPointer-<version>.dmg for GitHub Releases.
# Check for Updates in the app looks for the .dmg asset on the latest release.
#
# Needs:
#   TEAM_ID         Apple Developer team ID
#   A "Developer ID Application" certificate in the keychain
#   Notarization credentials, either
#     NOTARY_PROFILE  a keychain profile made with `xcrun notarytool store-credentials`, or
#     ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID  an App Store Connect API key
# Optional:
#   VERSION         marketing version, e.g. 1.0.0 (defaults to the project's MARKETING_VERSION)
#   BUILD_NUMBER    defaults to the git commit count
set -euo pipefail

cd "$(dirname "$0")/.."
: "${TEAM_ID:?Set TEAM_ID to your Apple Developer team ID}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD)}"
DERIVED="build/release/DerivedData"
OUT="build/release"

version_args=()
[[ -n "${VERSION:-}" ]] && version_args=(MARKETING_VERSION="$VERSION")

rm -rf "$OUT"
xcodebuild build \
    -project DemoPointer.xcodeproj \
    -scheme DemoPointer \
    -configuration Release \
    -derivedDataPath "$DERIVED" \
    -destination "generic/platform=macOS" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    ${version_args[@]+"${version_args[@]}"}

APP="$OUT/DemoPointer.app"
ditto "$DERIVED/Build/Products/Release/DemoPointer.app" "$APP"
codesign --verify --strict --verbose=2 "$APP"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="$OUT/DemoPointer-$VERSION.dmg"
./scripts/make-dmg.sh "$APP" "$DMG"
codesign --force --sign "Developer ID Application" --timestamp "$DMG"

# Notarizing the DMG also notarizes the app inside it.
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
else
    : "${ASC_KEY_PATH:?Set NOTARY_PROFILE or ASC_KEY_PATH/ASC_KEY_ID/ASC_ISSUER_ID}"
    xcrun notarytool submit "$DMG" --key "$ASC_KEY_PATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" --wait
fi

# Staple the ticket so the DMG opens without a network check.
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"
echo "Notarized $DMG"
