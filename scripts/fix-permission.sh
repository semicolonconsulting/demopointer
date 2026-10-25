#!/usr/bin/env bash
# After installing a new ad-hoc build: clears the stale Screen Recording permission, reopens
# Demo Pointer so macOS asks again, and opens the Screen Recording page in System Settings.
# Turn on DemoPointer there, then click "Reopen Demo Pointer" in its window.
osascript -e 'quit app "DemoPointer"' 2>/dev/null
tccutil reset ScreenCapture consulting.semicolon.DemoPointer
open /Applications/DemoPointer.app
sleep 2
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
