#!/bin/zsh
# Builds "Gmail Keys.app" in ./build. Pass --install to copy it to /Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Gmail Keys.app"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/GmailKeys"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/GmailKeys"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc sign so macOS can remember the Accessibility permission.
codesign --force --sign - "$APP"

if [[ "${1:-}" == "--install" ]]; then
    rm -rf "/Applications/Gmail Keys.app"
    cp -R "$APP" /Applications/
    echo "Installed to /Applications/Gmail Keys.app"
else
    echo "Built $APP"
fi
