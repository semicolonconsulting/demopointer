#!/usr/bin/env bash
# Installs build/DemoPointer.app into /Applications and relaunches it.
# Replacing an app in place can leave macOS showing its old icon (in the welcome window, Finder and System
# Settings) until the icon cache catches up, so this touches the bundle and re-registers it with Launch Services.
set -euo pipefail

cd "$(dirname "$0")/.."
[[ -d build/DemoPointer.app ]] || { echo "Run scripts/build-app.sh first" >&2; exit 1; }

osascript -e 'quit app "DemoPointer"' 2>/dev/null || true
sleep 1
rm -rf /Applications/DemoPointer.app
ditto build/DemoPointer.app /Applications/DemoPointer.app
touch /Applications/DemoPointer.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/DemoPointer.app
open /Applications/DemoPointer.app
echo "Installed and opened /Applications/DemoPointer.app"
