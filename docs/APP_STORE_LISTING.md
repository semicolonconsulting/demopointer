# App Store listing

Ready-to-paste fields for App Store Connect. Character limits are Apple's; the counts in brackets are for
the text as written.

The App Store build differs from the GitHub build. It has **no Check for Updates** (the App Store updates it),
**doesn't hide the pointer** (that uses an undocumented macOS setting the App Store doesn't allow), and
**Open at Login is off until the user turns it on** (guideline 2.4.5). The text below only describes what the App
Store build does.

## App information

| Field | Value |
| --- | --- |
| Name (30) | **Demo Pointer** [12] |
| Alternative names, if taken | Demo Pointer – Zoom Lens [24] · Demo Pointer: Screen Magnifier [30] |
| Subtitle (30) | **Hold ⌘ to magnify your screen** [29] |
| Alternative subtitle | A zoom lens for live demos [26] |
| Bundle ID | `consulting.semicolon.DemoPointer` |
| SKU | `demopointer` |
| Primary category | Productivity |
| Secondary category | Business |
| Content rights | Doesn't contain, show, or access third-party content |
| Age rating | 4+ (answer "None" or "No" to every question) |
| Copyright | 2026 Semicolon Consulting |
| Price | Free (suggested; paid apps need the Paid Apps agreement, tax and banking in App Store Connect) |

"Demo Pointer" doesn't appear in a Mac App Store search (US, 2026-10-26), but app names are unique across all
of App Store Connect, including unreleased apps, so creating the app record is the real check.

## URLs

| Field | Value |
| --- | --- |
| Support URL | https://github.com/semicolonconsulting/demopointer/issues |
| Marketing URL | https://github.com/semicolonconsulting/demopointer |
| Privacy Policy URL | https://github.com/semicolonconsulting/demopointer/blob/main/PRIVACY.md |

## Promotional text (170)

> Hold the Command key and a smooth magnifying lens follows your pointer, while the rest of the screen dims. Your audience sees exactly what you're pointing at. [158]

## Description (4000)

> Demo Pointer makes your pointer easy to follow in product demos, screen shares, teaching and recordings.
>
> Hold the Command (⌘) key by itself and a magnifying lens follows your pointer. Let go and it fades away. The rest of the screen dims while the lens is up, so the spot you're talking about stands out. Because the lens is drawn on screen, it shows up in screen shares and recordings in apps like Zoom, Google Meet, Microsoft Teams and QuickTime, so your audience sees it too.
>
> FEATURES
> • Real-time magnifying lens that follows the pointer, at up to 60 frames per second
> • Zoom 1.5×, 2×, 3× or 4×, with a small, medium or large lens
> • Screen shade: Off, Light, Medium or Dark
> • Only plain ⌘ shows the lens, so shortcuts like ⌘C or ⌘⇧4 don't get in the way
> • Click the menu bar icon to turn Demo Pointer on or off; right-click it for settings
> • Works across multiple displays
> • Optional Open at Login
>
> PRIVACY
> Demo Pointer needs Screen Recording permission to draw the magnified view. Captured frames stay in memory on your Mac and are never saved or sent anywhere. The app has no network access, no analytics and no tracking.
>
> Requires macOS 13 Ventura or later.

## Keywords (100)

```
magnifier,zoom,presentation,screen share,spotlight,cursor,highlight,lens,webinar,teaching,tutorial
```
[98] Don't repeat words already in the name or subtitle ("demo", "pointer", "magnify" is covered by "magnifier").

## What's New (version 1.0)

> First release on the Mac App Store.

## App Privacy

**Data Not Collected.** The App Store build makes no network connections, and Screen Recording frames never
leave the Mac. The privacy manifest (`DemoPointer/PrivacyInfo.xcprivacy`) declares no tracking, no collected data
and UserDefaults access for reason CA92.1 (the app's own settings).

## Export compliance

The app uses no encryption. `ITSAppUsesNonExemptEncryption` is `NO` in `Config/Info.plist`, so App Store Connect
doesn't ask.

## App Review information

Notes for the reviewer (paste into "Notes"):

> Demo Pointer is a menu bar app (no Dock icon) for presenters. Hold the Command (⌘) key by itself and a magnifying lens follows the pointer; the rest of the screen dims. Release ⌘ and the lens fades away.
>
> It needs Screen Recording permission only to draw the magnified pixels under the pointer. Frames are kept in memory, never written to disk or sent anywhere, and the app has no network access.
>
> To test:
> 1. Launch Demo Pointer. A welcome window opens, and macOS asks for Screen Recording permission.
> 2. Click "Open System Settings" and turn on Demo Pointer under Privacy & Security › Screen & System Audio Recording.
> 3. Click "Reopen Demo Pointer" in the welcome window (macOS applies the permission after a restart).
> 4. Hold ⌘ by itself over any window: the lens appears and follows the pointer.
> 5. Click the menu bar icon (a ring with a pointing hand) to turn Demo Pointer off or on. Right-click it for Zoom, Lens Size, Shade Screen, Open at Login and Quit.
>
> Open at Login is off by default and only turned on by the user, from the welcome window or the menu.

No sign-in is needed, so leave "Sign-in required" unchecked.

## Screenshots

Mac screenshots must be 16:10 at **1280×800, 1440×900, 2560×1600 or 2880×1800**, one to ten of them.

`appstore/screenshots.sh` (after `scripts/build-app.sh`) draws five 2880×1800 screenshots into
`build/appstore-screenshots/`, in upload order. The desktop, the demo apps and their numbers are made up, so nothing
real appears. The menu bar icon and the welcome window come from the app's own code, as in the App Store build
(pointer visible, no Check for Updates):

| File | Caption |
| --- | --- |
| `1-magnify.png` | Hold ⌘ to magnify. The lens over a sales dashboard, with Light shade. |
| `2-small-text.png` | Small details, big and clear. 3× on spreadsheet numbers, with Medium shade. |
| `3-screen-share.png` | Your audience sees it too. The lens in a video call's shared screen. |
| `4-welcome.png` | Set up in seconds. The welcome window. |
| `5-menu.png` | One click away. The menu bar menu with Shade Screen open. |

To capture real screenshots instead, `scripts/take-screenshots.sh <name>` restarts Demo Pointer in screenshot mode
(the lens stays up as if ⌘ were held, via the `-ScreenshotMode YES` launch argument) and saves 16:10 crops of the
main display in `build/screenshots/`. Use a Retina display resolution for sharp results.
