#!/usr/bin/env bash
# Archives DemoPointer and uploads it to App Store Connect.
# The App Store build is compiled with APPSTORE, which leaves out Check for Updates (the App Store
# updates the app), and signed with DemoPointer-AppStore.entitlements, which has no network access.
#
# Needs:
#   TEAM_ID         Apple Developer team ID
#   An app record for consulting.semicolon.DemoPointer in App Store Connect
#   Either Xcode signed in to your Apple account (Settings > Accounts), or an App Store Connect
#   API key in ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID
# Optional:
#   VERSION         marketing version, e.g. 1.0.0 (defaults to the project's MARKETING_VERSION)
#   BUILD_NUMBER    must increase with every upload; defaults to the git commit count
#   EXPORT_ONLY=1   export a signed .pkg into build/appstore instead of uploading
set -euo pipefail

cd "$(dirname "$0")/.."
: "${TEAM_ID:?Set TEAM_ID to your Apple Developer team ID}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD)}"
OUT="build/appstore"
ARCHIVE="$OUT/DemoPointer.xcarchive"

auth_args=()
if [[ -n "${ASC_KEY_PATH:-}" ]]; then
    auth_args=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi
version_args=()
[[ -n "${VERSION:-}" ]] && version_args=(MARKETING_VERSION="$VERSION")

rm -rf "$OUT"
mkdir -p "$OUT"

xcodebuild archive \
    -project DemoPointer.xcodeproj \
    -scheme DemoPointer \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates \
    ${auth_args[@]+"${auth_args[@]}"} \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) APPSTORE' \
    CODE_SIGN_ENTITLEMENTS=Config/DemoPointer-AppStore.entitlements \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    ${version_args[@]+"${version_args[@]}"}

destination="upload"
[[ "${EXPORT_ONLY:-}" == "1" ]] && destination="export"

cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>$destination</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$OUT/ExportOptions.plist" \
    -exportPath "$OUT" \
    -allowProvisioningUpdates \
    ${auth_args[@]+"${auth_args[@]}"}

if [[ "$destination" == "upload" ]]; then
    echo "Uploaded build $BUILD_NUMBER to App Store Connect"
else
    echo "Exported $OUT/DemoPointer.pkg"
fi
