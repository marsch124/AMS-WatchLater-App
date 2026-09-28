#!/bin/bash
# Builds "Add to WatchLater.app" into ~/Applications, where Raycast ranks it.
#   tools/launcher/build.sh
# The traps this handles, all learned on the old web app's launchers:
#  - osacompile leaves CFBundleIdentifier EMPTY, and macOS keys permissions on
#    it: with none, the Safari question can never be remembered and the app
#    hangs. So it gets a real id and an ad-hoc signature.
#  - osacompile bakes a generic icon into Assets.car and points CFBundleIconName
#    at it, which beats the loose .icns — both are removed.
#  - codesign refuses Finder "detritus" (xattrs) now and then: clean and retry.
set -e
cd "$(dirname "$0")"
APP="$HOME/Applications/Add to WatchLater.app"
TMP="$(mktemp -d)/Add to WatchLater.app"
/usr/bin/osacompile -o "$TMP" add-to-watchlater.applescript
P="$TMP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.ams.watchlater.add" "$P" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.ams.watchlater.add" "$P"
/usr/libexec/PlistBuddy -c "Add :CFBundleName string Add to WatchLater" "$P" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :NSAppleEventsUsageDescription string WatchLater reads the address of the page you are on, so one keystroke saves it." "$P" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :NSAppleEventsUsageDescription WatchLater reads the address of the page you are on, so one keystroke saves it." "$P"
rm -f "$TMP/Contents/Resources/Assets.car"
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$P" 2>/dev/null || true
cp watchlater-add.icns "$TMP/Contents/Resources/applet.icns"
xattr -cr "$TMP"
codesign --force --deep --sign - "$TMP" 2>/dev/null || { sleep 1; xattr -cr "$TMP"; codesign --force --deep --sign - "$TMP"; }
codesign --verify --deep "$TMP"
mkdir -p "$HOME/Applications"
rm -rf "$APP"
ditto "$TMP" "$APP"
echo "installed $APP"
