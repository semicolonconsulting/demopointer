# How to use Demo Pointer

Hold the Command (⌘) key and a magnifying lens follows your cursor. Let go and it fades away.

## Requirements

- macOS 13 Ventura or later
- Screen Recording permission (see [Permissions](#permissions))

## Install

Get `DemoPointer-<version>.dmg` from the [Releases](https://github.com/semicolonconsulting/demopointer/releases) page. Open it, drag **DemoPointer** onto **Applications**, then open it from Applications.

Releases are notarized by Apple and open normally. If you received a copy that isn't, the first launch is blocked with a message that macOS can't verify the app. Open System Settings › Privacy & Security, scroll down to the message about DemoPointer and click **Open Anyway**. You only need to do this once. Or run `xattr -dr com.apple.quarantine /Applications/DemoPointer.app`.

## Features

- The lens is a real-time zoom of the screen under the cursor (ScreenCaptureKit, up to 60 fps).
- It shows up in screen shares and recordings (Zoom, Meet, QuickTime), so your audience sees it too.
- It only triggers on plain ⌘. ⌘ combined with Shift, Option or Control is ignored, so shortcuts like ⌘⇧4 don't pop the lens. (A quick ⌘C will flash it briefly.)
- While the lens is shown, the mouse pointer is hidden (the lens marks where it is). GitHub version only: it relies on an undocumented macOS setting the App Store doesn't allow.
- While the lens is shown, the rest of the screen is shaded so the magnified spot stands out. Pick Off, Light (default), Medium or Dark.
- Works on multiple displays; the lens follows the display the cursor is on.

## Settings

- Click the menu-bar icon to turn Demo Pointer on or off (the circle is filled while it's on). Right-click it to pick zoom (1.5×, 2×, 3×, 4×), lens size (small, medium, large) and shade. Settings are remembered.
- A welcome window on first launch explains how to use it and how to allow Screen Recording. It's also **Settings…** in the menu.
- **Open at Login** is on by default. Turn it off in Settings or the menu.
- **Check for Updates** asks GitHub for the latest release and offers to download it. It also checks automatically about once a day; turn off **Check for Updates Automatically** in Settings or the menu. (GitHub version only: the App Store version is updated by the App Store.)

## Permissions

| Permission | Needed? | Why |
| --- | --- | --- |
| **Screen Recording** (System Settings › Privacy & Security › Screen & System Audio Recording) | **Yes** | To capture the pixels under the cursor for the lens. |
| Accessibility | No | |
| Input Monitoring | No | The Command key is detected by polling the current modifier state, which needs no permission. |

On first launch macOS asks for Screen Recording access. Turn on **Demo Pointer**, then **quit and reopen** the app (macOS only applies the permission on relaunch). The menu has a **Screen Recording Settings…** shortcut.

## Troubleshooting

- While the lens is in use, macOS shows its purple screen-recording indicator in the menu bar. Demo Pointer stops capturing 30 seconds after you last held ⌘, and the indicator goes away.
- macOS 15 Sequoia and later periodically re-confirm Screen Recording access with a prompt. Choose **Allow**.
- If the lens stays blank after you allowed Screen Recording, remove Demo Pointer from the list in System Settings and add it again, or run `tccutil reset ScreenCapture consulting.semicolon.DemoPointer`, then reopen the app.

## Privacy

Demo Pointer is sandboxed and never saves or sends what it captures. Its only network access is Check for Updates in the GitHub version, which asks GitHub for the latest release. The App Store version has no network access. See [PRIVACY.md](../PRIVACY.md).
