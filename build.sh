#!/usr/bin/env bash
# Builds MacThemes.app (and the macthemes CLI) into ./dist.
#
#     ./build.sh              release build into dist/
#     ./build.sh --install    also copy the app to /Applications, the CLI to
#                             ~/.local/bin, and seed ~/.config/macthemes
#                             (existing files are never overwritten)
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --product MacThemesApp
swift build -c release --product macthemes
BIN="$(swift build -c release --show-bin-path)"

APP=dist/MacThemes.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/themes"
cp "$BIN/MacThemesApp" "$APP/Contents/MacOS/MacThemes"
cp "$BIN/macthemes" dist/macthemes
cp themes/*.theme "$APP/Contents/Resources/themes/"
cp config.example "$APP/Contents/Resources/config.example"
# Regenerate with: swift tools/make-icon.swift
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>               <string>MacThemes</string>
    <key>CFBundleDisplayName</key>        <string>MacThemes</string>
    <key>CFBundleIdentifier</key>         <string>io.github.paulbeavers.macthemes</string>
    <key>CFBundleExecutable</key>         <string>MacThemes</string>
    <key>CFBundleIconFile</key>           <string>AppIcon</string>
    <key>CFBundlePackageType</key>        <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>0.1.0</string>
    <key>CFBundleVersion</key>            <string>1</string>
    <key>LSMinimumSystemVersion</key>     <string>14.0</string>
    <key>LSApplicationCategoryType</key>  <string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key>    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>MacThemes switches between light and dark mode through System Events.</string>
</dict>
</plist>
PLIST

# Ad-hoc signature, so macOS remembers the Automation permission between launches.
codesign --force --sign - "$APP" >/dev/null
echo "built $APP and dist/macthemes"

if [[ ${1:-} == --install ]]; then
    CFG="${XDG_CONFIG_HOME:-$HOME/.config}/macthemes"
    mkdir -p "$CFG/themes" "$HOME/.local/bin"
    cp -n themes/*.theme "$CFG/themes/" 2>/dev/null || true
    [[ -e $CFG/config ]] || cp config.example "$CFG/config"
    rm -rf /Applications/MacThemes.app
    cp -R "$APP" /Applications/
    cp dist/macthemes "$HOME/.local/bin/macthemes"
    echo "installed /Applications/MacThemes.app, ~/.local/bin/macthemes, themes in $CFG"
fi
