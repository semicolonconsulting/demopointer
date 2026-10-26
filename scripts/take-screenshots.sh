#!/usr/bin/env bash
# Captures App Store screenshots of the lens and shade on your real screen.
# Usage: scripts/take-screenshots.sh [name]
#   1. Arrange the app you want to show (a browser, a spreadsheet, a design tool) and close anything private.
#   2. Run this script. Demo Pointer restarts in screenshot mode, where the lens stays up as if ⌘ were held.
#   3. Within 5 seconds, put the pointer on the spot to magnify and leave it there.
# It saves build/screenshots/<name>-2880x1800.png and <name>-1440x900.png (16:10, as App Store Connect
# accepts for Mac), cropped from the center of the main display. Needs Screen Recording for Demo Pointer.
set -euo pipefail

cd "$(dirname "$0")/.."
NAME="${1:-screenshot-$(date +%H%M%S)}"
APP="${APP:-/Applications/DemoPointer.app}"
OUT="build/screenshots"
mkdir -p "$OUT"

osascript -e 'quit app "DemoPointer"' 2>/dev/null || true
sleep 1
open -a "$APP" --args -ScreenshotMode YES
echo "Point at the spot to magnify; capturing in 5 seconds..."
sleep 5
RAW="$OUT/$NAME-raw.png"
screencapture -x -m "$RAW"

# Crop the largest centered 16:10 area, then scale to the App Store sizes.
read -r W H < <(sips -g pixelWidth -g pixelHeight "$RAW" | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w, h}')
if (( W * 10 > H * 16 )); then CW=$(( H * 16 / 10 )); CH=$H; else CW=$W; CH=$(( W * 10 / 16 )); fi
sips -c "$CH" "$CW" "$RAW" --out "$OUT/$NAME-crop.png" >/dev/null
sips -z 1800 2880 "$OUT/$NAME-crop.png" --out "$OUT/$NAME-2880x1800.png" >/dev/null
sips -z 900 1440 "$OUT/$NAME-crop.png" --out "$OUT/$NAME-1440x900.png" >/dev/null
rm "$OUT/$NAME-crop.png"

# Back to normal mode.
osascript -e 'quit app "DemoPointer"' 2>/dev/null || true
sleep 1
open -a "$APP"
echo "Saved $OUT/$NAME-2880x1800.png and $OUT/$NAME-1440x900.png (raw capture: $RAW)"
