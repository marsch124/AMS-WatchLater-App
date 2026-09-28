#!/bin/bash
# Builds AMS WatchLater.   tools/build.sh [build|test] [iphone|mac] [icloud]
#
# "icloud" builds with the iCloud entitlements and WATCHLATER_USES_ICLOUD=YES —
# the build that syncs. It needs his Apple ID in Xcode (automatic signing
# registers the app and its container on first use), so it is for THIS Mac.
#
# Two traps this script exists for (both met first on AMS Coffee):
#  1. Anything under ~/Documents picks up macOS extended attributes, and
#     codesign refuses them ("resource fork ... detritus not allowed").
#     So: clear them first — but never inside .git, whose objects are
#     read-only and would fail the sweep.
#  2. Derived data must land OUTSIDE ~/Documents for the same reason.
set -e
cd "$(dirname "$0")/.."
DD="${TMPDIR:-/tmp}/AMSWatchLater-build"

find . -path ./.git -prune -o -print0 | xargs -0 xattr -c 2>/dev/null || true
xcodegen generate

if [ "${2:-iphone}" = "mac" ]; then
  DEST='platform=macOS'
  OUT="$DD/Build/Products/Debug/AMSWatchLater.app"
else
  DEST="${WL_DEST:-platform=iOS Simulator,name=iPhone 17 Pro}"
  OUT="$DD/Build/Products/Debug-iphonesimulator/AMSWatchLater.app"
fi

# After a RED test xcodebuild otherwise sits "collecting diagnostics" for ten
# minutes and looks hung; and no single test may run away with the suite.
EXTRA=()
if [ "${1:-build}" = "test" ]; then
  EXTRA=(-collect-test-diagnostics never -test-timeouts-enabled YES
         -maximum-test-execution-time-allowance 300)
fi

if [ "${3:-}" = "icloud" ]; then
  EXTRA+=(-allowProvisioningUpdates -allowProvisioningDeviceRegistration
          WL_ENT=-iCloud
          WATCHLATER_USES_ICLOUD=YES)
fi

xcodebuild \
  -project AMSWatchLater.xcodeproj \
  -scheme AMSWatchLater \
  -destination "$DEST" \
  -derivedDataPath "$DD" \
  "${EXTRA[@]}" \
  "${1:-build}"

echo
echo "App: $OUT"
