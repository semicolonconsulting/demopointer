# Demo Pointer

A tiny macOS menu-bar app for product demos: **hold the Command (⌘) key and a magnifying lens follows your cursor.** Let go and it disappears.

- Lens is a real-time zoom of the screen under the cursor (ScreenCaptureKit, up to 60 fps).
- Shows up in screen shares and recordings (Zoom, Meet, QuickTime), so your audience sees it too.
- Only triggers on plain ⌘. ⌘ combined with Shift, Option or Control is ignored, so shortcuts like ⌘⇧4 don't pop the lens. (A quick ⌘C will flash it briefly.)
- Menu-bar icon lets you toggle it, pick zoom (1.5×, 2×, 3×, 4×) and lens size (small, medium, large). Settings are remembered.
- Works on multiple displays; the lens follows the display the cursor is on.

## Requirements

- macOS 13 Ventura or later
- Xcode 15+ or the Xcode Command Line Tools (`xcode-select --install`)

## Build and run

```sh
./scripts/build-app.sh
open build/DemoPointer.app
```

The script runs `swift build -c release`, wraps the binary in `build/DemoPointer.app` (menu-bar only, no Dock icon) and ad-hoc signs it. Move the app to `/Applications` if you want to keep it.

You can also open `Package.swift` in Xcode to edit and debug, but run the bundled `.app` for real use so macOS attributes the Screen Recording permission to Demo Pointer rather than to Xcode or Terminal.

Every push also builds the app in GitHub Actions; the zipped `.app` is attached to the workflow run as the `DemoPointer` artifact. A downloaded build is unsigned for Gatekeeper, so the first time, right-click the app and choose **Open** (or run `xattr -dr com.apple.quarantine DemoPointer.app`).

## Permissions

| Permission | Needed? | Why |
| --- | --- | --- |
| **Screen Recording** (System Settings › Privacy & Security › Screen & System Audio Recording) | **Yes** | To capture the pixels under the cursor for the lens. |
| Accessibility | No | |
| Input Monitoring | No | The Command key is detected by polling the current modifier state, which needs no permission. |

On first launch macOS asks for Screen Recording access. Turn on **Demo Pointer**, then **quit and reopen** the app (macOS only applies the permission on relaunch). The menu has a **Screen Recording Settings…** shortcut.

Notes:

- While the lens is in use, macOS shows its purple screen-recording indicator in the menu bar. Demo Pointer stops capturing 30 seconds after you last held ⌘, and the indicator goes away.
- macOS 15 Sequoia and later periodically re-confirm Screen Recording access with a prompt. Choose **Allow**.
- With the default ad-hoc signature, macOS may treat each rebuild as a new app and ask for permission again. To avoid that, sign with your own identity: `SIGN_IDENTITY="Apple Development: you@example.com" ./scripts/build-app.sh`. If the permission gets stuck, remove Demo Pointer from the list in System Settings and add it again, or run `tccutil reset ScreenCapture consulting.semicolon.DemoPointer`.

## How it works

- `MagnifierController` polls `NSEvent.modifierFlags` and `NSEvent.mouseLocation` 60 times a second. While ⌘ is held it crops the area under the cursor from the latest captured frame and hands it to the lens.
- `ScreenCapturer` runs an `SCStream` of the display under the cursor, excluding Demo Pointer's own windows so the lens never magnifies itself.
- `LensWindow` is a borderless, transparent, click-through window above everything else (including full-screen apps) that draws the circular lens with a white ring and shadow. The real cursor stays visible on top at the lens center.
