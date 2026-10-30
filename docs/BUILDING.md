# Building Demo Pointer

## Requirements

- macOS 13 Ventura or later to run
- Xcode 16 or later to build (CI uses Xcode 26 on macOS 26)

## Build and run

Open `DemoPointer.xcodeproj` in Xcode and run the **DemoPointer** scheme, or from the command line:

```sh
./scripts/build-app.sh
open build/DemoPointer-*.dmg
```

The script builds the Release configuration with `xcodebuild`, signs it ad-hoc, copies it to `build/DemoPointer.app` (menu bar only, no Dock icon) and packs it into `build/DemoPointer-<version>.dmg` with `scripts/make-dmg.sh`. Laying out the DMG window uses Finder, so the first run asks to let your terminal control Finder; set `NO_DMG=1` to skip the DMG.

With the default ad-hoc signature, macOS treats each rebuild as a new app, and the Screen Recording switch you turned on stops working. To avoid that, sign with your own identity: `SIGN_IDENTITY="Apple Development" TEAM_ID=ABCDE12345 ./scripts/build-app.sh`. If the permission gets stuck, remove Demo Pointer from the list in System Settings and add it again, or run `tccutil reset ScreenCapture consulting.semicolon.DemoPointer`.

Every push also builds the app in GitHub Actions; the zipped `.app` is attached to the workflow run as the `DemoPointer` artifact.

Releasing to GitHub (Developer ID, notarized) and the Mac App Store is described in [RELEASING.md](RELEASING.md). The app icon is drawn by `scripts/make-icon.swift` (`swift scripts/make-icon.swift` regenerates it).

## How it works

- `MagnifierController` polls `NSEvent.modifierFlags` and `NSEvent.mouseLocation` 60 times a second. While ⌘ is held it crops the area under the cursor from the latest captured frame and hands it to the lens.
- `ScreenCapturer` runs an `SCStream` of the display under the cursor, excluding Demo Pointer's own windows so the lens never magnifies itself.
- `LensWindow` is a borderless, transparent, click-through window above everything else (including full-screen apps) that draws the circular lens with a white ring and shadow. The real cursor stays visible on top at the lens center.
