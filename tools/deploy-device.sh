#!/usr/bin/env bash
#
# Build, install and launch on a paired iPhone.
#
# Exists because doing this inline once installed a STALE bundle after a failed compile and
# reported success: the build failed, the previous .app was still on disk, `test -d` found it,
# and the phone silently received the old code.
#
# The effective guard is that xcodebuild's EXIT STATUS decides whether to install -- never the
# presence of a bundle. Verified by deliberately breaking a source file: the script exits 1 and
# installs nothing. Deleting the old bundle first is belt-and-braces only; Xcode recreates the
# .app directory before it fails compiling, so its existence proves nothing either way.
set -euo pipefail
cd "$(dirname "$0")/.."

# No default. A device UDID is a hardware identifier for one specific phone, so it belongs in
# your environment rather than in a public repository. Find yours with:
#
#     xcrun devicectl list devices
#
DEVICE_ID="${ASCEND_DEVICE_ID:-}"
BUNDLE_ID="com.foggylulu.Ascend"
DD="${ASCEND_DERIVED_DATA:-/tmp/ascend-device-dd}"
APP="$DD/Build/Products/Debug-iphoneos/Ascend.app"

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; DIM=$'\033[2m'; OFF=$'\033[0m'
fail() { echo "${RED}FAIL${OFF} $1"; exit 1; }
ok()   { echo "${GREEN}ok${OFF}   $1"; }

if [ -z "$DEVICE_ID" ]; then
  fail "set ASCEND_DEVICE_ID first -- find yours with: xcrun devicectl list devices"
fi

# Belt-and-braces. Not load-bearing: Xcode recreates this directory even on failure.
rm -rf "$APP"

echo "${DIM}-- xcodegen${OFF}"
command -v xcodegen >/dev/null 2>&1 && xcodegen generate --quiet
ok "project generated"

echo "${DIM}-- xcodebuild (device)${OFF}"
LOG=$(mktemp)
# THE guard: the build's own exit status decides, not the presence of a file.
if ! xcodebuild -project Ascend.xcodeproj -scheme Ascend \
      -destination "platform=iOS,id=$DEVICE_ID" \
      -allowProvisioningUpdates -derivedDataPath "$DD" -quiet build > "$LOG" 2>&1; then
  grep -E "error:" "$LOG" | head -20
  fail "build failed -- nothing was installed"
fi
[ -d "$APP" ] || fail "build reported success but produced no app bundle"
ok "built $(defaults read "$APP/Info.plist" CFBundleShortVersionString 2>/dev/null || echo '?') ($(date -r "$APP" '+%H:%M:%S'))"

echo "${DIM}-- install${OFF}"
INSTALLED=0
for _ in $(seq 1 40); do
  if xcrun devicectl device install app --device "$DEVICE_ID" "$APP" > "$LOG" 2>&1; then
    INSTALLED=1; break
  fi
  if grep -q "maximum number of installed apps" "$LOG"; then
    grep -o '"[A-Z0-9]*\.[^"]*"' "$LOG" | sort -u
    fail "free-profile 3-app limit reached -- remove one of the apps listed above"
  fi
  # Anything else is usually just a locked device; keep retrying.
  sleep 3
done
[ "$INSTALLED" = 1 ] || { tail -6 "$LOG"; fail "install failed (is the phone unlocked?)"; }
ok "installed $BUNDLE_ID"

echo "${DIM}-- launch${OFF}"
xcrun devicectl device process launch --device "$DEVICE_ID" \
  --terminate-existing "$BUNDLE_ID" >/dev/null 2>&1 || fail "launch failed"
ok "launched"

echo
echo "${GREEN}Live on device.${OFF}"
