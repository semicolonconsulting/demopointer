# Releasing Demo Pointer

Demo Pointer ships two ways from the same Xcode project:

| Channel | Signing | How |
| --- | --- | --- |
| GitHub Releases (DMG) | Developer ID, notarized | `scripts/release-github.sh`, or push a `v*` tag (`.github/workflows/release.yml`) |
| Mac App Store | Apple Distribution | `scripts/release-appstore.sh`, or Xcode › Product › Archive |

Both builds are sandboxed. They differ in one way:

- **GitHub** (`Config/DemoPointer.entitlements`): adds outgoing network access for Check for Updates (`DemoPointer/Updates.swift`), which reads the latest GitHub release and offers its `.dmg`. Every release must attach `DemoPointer-<version>.dmg` and be tagged `v<version>`.
- **App Store** (`Config/DemoPointer-AppStore.entitlements`, Swift condition `APPSTORE`): no network access and no updater, since the App Store updates the app and store apps may not update themselves.

Open at Login is on by default in the GitHub build (registered on first launch from an Applications folder). The App Store build leaves it off until the user turns it on, since App Review guideline 2.4.5(iii) doesn't allow launching at login without consent. The App Store build also keeps the pointer visible, because hiding it from a background app needs an undocumented macOS setting.

The team ID `C6ZRF9KM22` (SEMICOLON CONSULTING K.K.) is set in the project. The listing text, review notes and screenshot plan are in [APP_STORE_LISTING.md](APP_STORE_LISTING.md).

## One-time setup

1. Join the [Apple Developer Program](https://developer.apple.com/programs/) and note your **Team ID** (Membership details).
2. In Xcode › Settings › Accounts, sign in with that Apple ID. Then open `DemoPointer.xcodeproj`, select the DemoPointer target › Signing & Capabilities and pick your team. This sets `DEVELOPMENT_TEAM` in the project; commit it. The Team ID is not a secret.
3. Register the bundle ID `consulting.semicolon.DemoPointer` (Xcode does this automatically with automatic signing).
4. Create certificates (Xcode › Settings › Accounts › Manage Certificates):
   - **Developer ID Application**, for GitHub builds.
   - **Apple Distribution** and **Mac Installer Distribution**, for the App Store. Automatic signing creates these during export.
5. Create an **App Store Connect API key** (Users and Access › Integrations › App Store Connect API, role *Developer* or higher). Download the `.p8`, and note the Key ID and Issuer ID. It's used for notarization and CI uploads.

To keep Screen Recording permission across local rebuilds, build with your development identity:

```sh
SIGN_IDENTITY="Apple Development" TEAM_ID=ABCDE12345 ./scripts/build-app.sh
```

## Versioning

- `MARKETING_VERSION` (`CFBundleShortVersionString`) is set in the project. The release scripts override it with `VERSION=1.2.3`.
- `CURRENT_PROJECT_VERSION` (`CFBundleVersion`) defaults to the git commit count in the release scripts, so it always increases. Override it with `BUILD_NUMBER`.

## GitHub release

Locally:

```sh
xcrun notarytool store-credentials demopointer-notary   # once; uses an app-specific password or API key
TEAM_ID=ABCDE12345 NOTARY_PROFILE=demopointer-notary VERSION=1.0.0 ./scripts/release-github.sh
gh release create v1.0.0 build/release/DemoPointer-1.0.0.dmg --generate-notes
```

From CI: add these repository secrets and set the repository variable `NOTARIZE` to `true` (Settings › Secrets and variables › Actions › Variables), then push a tag (`git tag v1.0.0 && git push origin v1.0.0`). While `NOTARIZE` isn't set, the release workflow skips itself on tag pushes.

### Unsigned release (until there's a Developer ID)

```sh
./scripts/build-app.sh                      # ad-hoc signed build/DemoPointer-<version>.dmg
git tag v1.0.0 && git push origin v1.0.0
gh release create v1.0.0 build/DemoPointer-1.0.0.dmg --title "Demo Pointer 1.0" --notes-file notes.md
```

Users then need Open Anyway in Privacy & Security on first launch (the DMG's Read Me explains it).

| Secret | Value |
| --- | --- |
| `APPLE_TEAM_ID` | Team ID |
| `DEVELOPER_ID_CERT_P12` | `base64 -i DeveloperID.p12`, exported from Keychain Access (certificate and private key) |
| `DEVELOPER_ID_CERT_PASSWORD` | password set when exporting the `.p12` |
| `ASC_KEY_ID`, `ASC_ISSUER_ID` | App Store Connect API key IDs |
| `ASC_KEY_P8` | contents of `AuthKey_XXXX.p8` |

## Mac App Store

1. In [App Store Connect](https://appstoreconnect.apple.com) › Apps › **+** › New App: platform macOS, bundle ID `consulting.semicolon.DemoPointer`, SKU e.g. `demopointer`. If the name "Demo Pointer" is taken, choose another display name; the bundle can stay the same.
2. Upload a build:
   ```sh
   TEAM_ID=ABCDE12345 VERSION=1.0.0 ./scripts/release-appstore.sh
   # or with an API key instead of the Xcode account:
   TEAM_ID=… ASC_KEY_PATH=~/keys/AuthKey_XXXX.p8 ASC_KEY_ID=… ASC_ISSUER_ID=… ./scripts/release-appstore.sh
   ```
3. Fill in the listing:
   - **Category:** Productivity (set in `Info.plist` as `LSApplicationCategoryType`).
   - **Privacy Policy URL:** `https://github.com/semicolonconsulting/demopointer/blob/main/PRIVACY.md`.
   - **App Privacy:** "Data Not Collected".
   - **Screenshots:** at least one at 1280×800, 1440×900, 2560×1600 or 2880×1800. Show the lens over a real app.
   - **Encryption:** already answered by `ITSAppUsesNonExemptEncryption = NO` in `Info.plist`.
4. **App Review notes.** Paste something like:
   > Demo Pointer is a menu bar app (no Dock icon) for presenters. Hold the Command key by itself and a magnifying lens follows the pointer; release it to hide the lens. It needs Screen Recording permission to draw the magnified pixels. Frames stay in memory and are never saved or sent. To test: grant Screen Recording in System Settings › Privacy & Security › Screen & System Audio Recording, quit and reopen Demo Pointer from its menu bar icon, then hold ⌘ over any window. Zoom and lens size are in the menu bar icon's menu.
5. Submit for review.

## Before each release

- [ ] Build and test the sandboxed app on the oldest supported macOS (13) and the newest.
- [ ] Hold ⌘ over each display, change zoom and size, and confirm the lens does not magnify itself.
- [ ] Revoke Screen Recording and confirm the app explains how to grant it.
- [ ] Open the DMG and check the install window, then install from it and check the welcome window.
- [ ] Bump `VERSION`, tag, release. The release notes' first paragraph is shown in the in-app update alert.
