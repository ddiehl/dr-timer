#!/bin/bash
# Captures App Store screenshots from the simulator.
#
# Each scenario seeds the app's container with demo flights (and, where the
# screen needs one, a run already in progress) and then runs the UI test that
# navigates to it. Seeding rather than tapping through the UI keeps the shots
# identical from run to run, and lets the countdown screens show a flight
# already under way.
#
# Usage: scripts/screenshots.sh [output-dir]
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="${1:-build/screenshots}"
DEVICE="${SCREENSHOT_DEVICE:-iPhone 15 Pro Max}"
BUNDLE_ID="com.spartatechnology.drtimer"
WORK="build/screenshot-work"

rm -rf "$OUT" "$WORK"
mkdir -p "$OUT" "$WORK"

UDID=$(xcrun simctl list devices available \
  | grep -F "$DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[ -n "$UDID" ] || { echo "No simulator named '$DEVICE'"; exit 1; }
echo "Device: $DEVICE ($UDID)"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b

# Built once; each scenario then reuses the same build.
echo "Building..."
xcodegen generate >/dev/null
xcodebuild build-for-testing -project DRTimer.xcodeproj -scheme Screenshots \
  -destination "id=$UDID" -derivedDataPath "$WORK/dd" > "$WORK/build.log" 2>&1 \
  || { tail -30 "$WORK/build.log"; exit 1; }

APP=$(find "$WORK/dd/Build/Products" -name "DRTimer.app" -maxdepth 2 | head -1)
xcrun simctl install "$UDID" "$APP"
CONTAINER=$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)
echo "Container: $CONTAINER"

# Compiled against the real DRCore sources, so the seeded JSON is byte-identical
# to what the app itself would write.
# (Top-level code only compiles in a file named main.swift, hence scripts/seed/.)
swiftc -O -o "$WORK/seedtool" DRCore/Sources/DRCore/*.swift scripts/seed/main.swift

# The marketing convention: 9:41, full bars, charged.
xcrun simctl status_bar "$UDID" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3

run_scenario() { # name, test-method, seconds-until-time-up (or "none")
  local name="$1" test="$2" seconds="$3"
  echo "--- $name"
  # The previous scenario's app keeps ticking in the background and saves the
  # run as it goes, which would overwrite the seed moments after it is written.
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  # Re-resolved per scenario: reinstalling can hand the app a new container.
  CONTAINER=$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)
  mkdir -p "$CONTAINER/Documents"
  "$WORK/seedtool" "$CONTAINER/Documents" "$seconds" >/dev/null
  xcodebuild test-without-building -project DRTimer.xcodeproj -scheme Screenshots \
    -destination "id=$UDID" -derivedDataPath "$WORK/dd" \
    -resultBundlePath "$WORK/$name.xcresult" \
    -only-testing:"DRTimerUITests/ScreenshotTests/$test" \
    > "$WORK/$name.log" 2>&1 || { tail -25 "$WORK/$name.log"; exit 1; }
  xcrun xcresulttool export attachments \
    --path "$WORK/$name.xcresult" --output-path "$WORK/$name-att" >/dev/null
  python3 scripts/collect-screenshots.py "$WORK/$name-att" "$OUT"
}

# 400s leaves a realistic few minutes on the clock by the time the app is up,
# and still cannot expire mid-test; 25s puts the time-up scenario at the alert.
run_scenario counting testCounting           400
run_scenario timeup   testTimeUp             25
run_scenario planning testPickerPlanAndAbout none

xcrun simctl status_bar "$UDID" clear
echo
echo "Screenshots in $OUT:"
ls -1 "$OUT"
