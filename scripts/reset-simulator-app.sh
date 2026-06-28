#!/usr/bin/env bash
# Reset Splick on the iOS Simulator when Xcode Run fails with
# FBSOpenApplicationServiceErrorDomain / launchd spawn failed (code 163).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
BUNDLE_ID="com.splick.app"
SCHEME="${SCHEME:-SplickApp}"

pick_booted_device() {
  xcrun simctl list devices booted -j \
    | python3 -c '
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for device in devices:
        if device.get("state") == "Booted":
            print(device["udid"])
            raise SystemExit(0)
raise SystemExit(1)
'
}

DEVICE_UDID="${DEVICE_UDID:-}"
if [[ -z "$DEVICE_UDID" ]]; then
  DEVICE_UDID="$(pick_booted_device)" || true
fi

if [[ -z "$DEVICE_UDID" ]]; then
  echo "No booted simulator found. Boot one in Xcode (e.g. iPhone 17 Pro), then rerun."
  exit 1
fi

echo "→ Using simulator $DEVICE_UDID"
echo "→ Terminating $BUNDLE_ID (if running)"
xcrun simctl terminate "$DEVICE_UDID" "$BUNDLE_ID" 2>/dev/null || true

echo "→ Uninstalling $BUNDLE_ID"
xcrun simctl uninstall "$DEVICE_UDID" "$BUNDLE_ID" 2>/dev/null || true

echo "→ Cleaning Xcode build for $SCHEME"
xcodebuild -scheme "$SCHEME" -destination "id=$DEVICE_UDID" clean >/dev/null

echo "→ Building and installing $SCHEME"
xcodebuild -scheme "$SCHEME" -destination "id=$DEVICE_UDID" -configuration Debug build

APP_PATH="$(xcodebuild -scheme "$SCHEME" -destination "id=$DEVICE_UDID" -configuration Debug -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/TARGET_BUILD_DIR/ {dir=$2} /WRAPPER_NAME/ {name=$2} END {print dir "/" name}')"
if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: Built app not found at $APP_PATH"
  exit 1
fi

xcrun simctl install "$DEVICE_UDID" "$APP_PATH"
PID="$(xcrun simctl launch "$DEVICE_UDID" "$BUNDLE_ID" | awk '{print $2}')"
echo "✓ Installed and launched $BUNDLE_ID (pid $PID)"
echo ""
echo "If Xcode ▶ Run still fails, use scheme 'SplickApp-Run' (no debugger) or"
echo "Edit Scheme → Run → uncheck 'Debug executable'."
