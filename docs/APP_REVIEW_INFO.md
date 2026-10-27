# App Review information

Answers to App Review's "Guideline 2.1 - Information Needed" request (October 2026). Paste them as the reply in
App Store Connect, and also into App Store Connect › App Review Information › Notes, for future submissions.

## Reply

> Thank you for reviewing Demo Pointer. The requested information is below. The screen recording is attached.
>
> **1. Screen recording**
> Attached. It was recorded on a MacBook running the latest macOS, with the submitted build installed from TestFlight. It starts with launching the app and shows the whole flow: the welcome window, granting Screen Recording permission, holding ⌘ to show the magnifying lens, changing zoom, lens size and screen shade from the menu bar menu, turning the app off and on with the menu bar icon, and the optional Open at Login setting. The app has no accounts, no user-generated content and no paid content.
>
> **2. Purpose and target audience**
> Demo Pointer is a menu bar utility for people who show their Mac screen to others: presenters, teachers, sales engineers, support staff, and anyone giving product demos, screen shares or recorded tutorials. When the presenter holds the Command (⌘) key by itself, a magnifying lens follows the pointer and the rest of the screen dims. It solves a common problem in demos and video calls: viewers can't see the small pointer or the details being pointed at, especially on high-resolution screens shared at low resolution. Because the lens is drawn on screen, it appears in screen shares and recordings, so the audience sees exactly what the presenter is pointing at.
>
> **3. Setup and main features**
> No login, account or sample files are needed.
> 1. Launch Demo Pointer from Applications. It runs in the menu bar (a ring with a pointing hand) and has no Dock icon. A welcome window opens.
> 2. macOS asks for Screen Recording permission, which the app needs only to draw the magnified view. Click "Open System Settings" in the welcome window and turn on Demo Pointer under Privacy & Security › Screen & System Audio Recording.
> 3. Click "Reopen Demo Pointer" in the welcome window (macOS applies the permission after a restart).
> 4. Hold the ⌘ key by itself over any window: the lens appears and follows the pointer, and the rest of the screen dims. Release ⌘ and it fades away.
> 5. Right-click the menu bar icon for Settings, Zoom (1.5× to 4×), Lens Size, Shade Screen (Off, Light, Medium, Dark), Open at Login (off by default) and Quit. Left-click the icon to turn Demo Pointer off or on; its circle is filled while it's on.
>
> **4. External services**
> None. Demo Pointer uses only Apple's system frameworks (ScreenCaptureKit to read the pixels under the pointer, AppKit, and ServiceManagement for the optional Open at Login). It makes no network connections, has no accounts, analytics, advertising, AI services or payment processing, and captured frames never leave the Mac.
>
> **5. Regional differences**
> None. The app works the same in all regions. The interface is in English.
>
> **6. Regulated industry or third-party material**
> Not applicable. Demo Pointer doesn't operate in a regulated industry and contains no third-party protected material. The app icon and all artwork are our own.

## Making the screen recording

1. **Install the submitted build with TestFlight.** In App Store Connect › TestFlight, add yourself as an internal
   tester for the uploaded build, then install it with the TestFlight app on the Mac. Internal testing needs no
   extra review. Quit any other copy of Demo Pointer first.
2. **Start from a fresh state**, so the recording shows the first-launch flow:
   `osascript -e 'quit app "DemoPointer"'; tccutil reset ScreenCapture consulting.semicolon.DemoPointer`
3. **Start recording** with ⌘⇧5 › Record Entire Screen › Record. Show the pointer in recordings (Options › Show Mouse
   Clicks helps reviewers follow).
4. **Record the flow** (1–2 minutes):
   1. Open Demo Pointer from Applications (or TestFlight). The welcome window appears and macOS asks for Screen Recording.
   2. Click Open System Settings, turn on Demo Pointer, then click Reopen Demo Pointer.
   3. Open a window with some content (a web page or document) and hold ⌘: the lens follows the pointer, the screen dims.
   4. Right-click the menu bar icon and change Zoom, Lens Size and Shade Screen, holding ⌘ after each change to show it.
   5. Left-click the menu bar icon to turn it off, hold ⌘ to show nothing happens, then click it on again.
   6. Open Settings… and point out Open at Login (off by default).
   7. Quit from the menu.
5. **Stop recording** (the stop button in the menu bar), and attach the .mov to the reply in App Store Connect.
