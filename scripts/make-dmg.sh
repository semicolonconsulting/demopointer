#!/usr/bin/env bash
# Packs an app into a drag-to-install DMG: the app, an Applications link and the read-me, laid out over a
# background picture (dmg/background.swift), with the app icon as the volume icon.
# Usage: scripts/make-dmg.sh <path/to/DemoPointer.app> <output.dmg>
# Laying out the window needs Finder: the first run asks to let your terminal control Finder. If that's not
# possible (or SKIP_DMG_LAYOUT=1, or on CI), the DMG still works, with Finder's default window instead.
set -euo pipefail

cd "$(dirname "$0")/.."
APP="$1"
DMG="$2"
VOLNAME="Demo Pointer"
VOL="/Volumes/$VOLNAME"
WORK="build/dmg-work"
APP_NAME="$(basename "$APP")"

[[ -d "$APP" ]] || { echo "No app at $APP" >&2; exit 1; }
[[ ! -e "$VOL" ]] || { echo "Eject the \"$VOLNAME\" disk first" >&2; exit 1; }

rm -rf "$WORK" "$DMG"
mkdir -p "$WORK/stage/.background"
ditto "$APP" "$WORK/stage/$APP_NAME"
ln -s /Applications "$WORK/stage/Applications"
cp "dmg/Read Me.txt" "$WORK/stage/"

swift dmg/background.swift "$WORK/background.png" 1
swift dmg/background.swift "$WORK/background@2x.png" 2
tiffutil -cathidpicheck "$WORK/background.png" "$WORK/background@2x.png" -out "$WORK/stage/.background/background.tiff" 2>/dev/null

hdiutil create -quiet -volname "$VOLNAME" -srcfolder "$WORK/stage" -fs HFS+ -format UDRW "$WORK/rw.dmg"
hdiutil attach -quiet -readwrite -noverify -noautoopen "$WORK/rw.dmg"

# Finder saves the window layout into the volume's .DS_Store. Positions are icon centers and must match
# dmg/background.swift; the window is 640 x 500 points plus a 32-point title bar.
layout_ok=0
if [[ "${SKIP_DMG_LAYOUT:-}" != "1" && -z "${CI:-}" ]]; then
    if osascript - "$VOLNAME" "$APP_NAME" >/dev/null <<'APPLESCRIPT'
on run {volName, appName}
	tell application "Finder"
		tell disk volName
			open
			set current view of container window to icon view
			set toolbar visible of container window to false
			set statusbar visible of container window to false
			set bounds of container window to {200, 120, 840, 652}
			set opts to icon view options of container window
			set arrangement of opts to not arranged
			set icon size of opts to 112
			set text size of opts to 13
			set shows icon preview of opts to false
			set background picture of opts to file ".background:background.tiff"
			set extension hidden of item appName to true
			set extension hidden of item "Read Me.txt" to true
			set position of item appName of container window to {170, 192}
			set position of item "Applications" of container window to {470, 192}
			set position of item "Read Me.txt" of container window to {470, 348}
			-- Reopening makes Finder apply the background and save the layout.
			close
			open
		end tell
		set selection to {}
		tell disk volName
			update without registering applications
			delay 1
			close
		end tell
	end tell
end run
APPLESCRIPT
    then
        for _ in {1..20}; do [[ -f "$VOL/.DS_Store" ]] && break; sleep 0.5; done
        [[ -f "$VOL/.DS_Store" ]] && layout_ok=1
    fi
    if [[ $layout_ok == 0 ]]; then
        echo "warning: couldn't lay out the DMG window, so it opens with Finder's default layout." >&2
        echo "         To fix, allow your terminal to control Finder (System Settings > Privacy & Security > Automation)." >&2
    fi
fi

# After the layout: Finder's update above deletes a volume icon that is already there.
if [[ -f "$APP/Contents/Resources/AppIcon.icns" ]]; then
    cp "$APP/Contents/Resources/AppIcon.icns" "$VOL/.VolumeIcon.icns"
    SetFile -a V "$VOL/.VolumeIcon.icns"
    SetFile -a C "$VOL"
else
    echo "warning: no AppIcon.icns in the app, so the DMG has the default volume icon." >&2
fi
rm -rf "$VOL/.fseventsd"
sync
hdiutil detach -quiet "$VOL" || { sleep 2; hdiutil detach -quiet -force "$VOL"; }

hdiutil convert -quiet "$WORK/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$DMG"
rm -rf "$WORK"
echo "Built $DMG"
