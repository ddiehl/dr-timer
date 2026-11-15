#!/bin/bash
# Captures App Store screenshots from the simulator.
#
# Each scenario seeds the app's container with demo flights (and, where the
# screen needs one, a run already in progress) and then runs the UI test that
# navigates to it. Seeding rather than tapping through the UI keeps the shots
# identical from run to run, and lets the countdown screens show a flight
# already under way.
#
# Repeated once per device, because App Store Connect keeps a separate
# screenshot slot per iPhone display size and rejects a file sized for a
# different slot ("File dimensions are invalid"). The defaults are the two
# slots offered for a Dynamic Island iPhone, captured at their native sizes so
# nothing is ever rescaled:
#
#   iPhone 16 Pro Max -> 1320x2868   drop into "iPhone 6.9" Display"
#   iPhone 16 Pro     -> 1206x2622   drop into "iPhone 6.1" Display"
#
# Shots land in <output-dir>/<width>x<height>/, so the directory name says
# which slot they belong to.
#
# Usage: scripts/screenshots.sh [output-dir]
#        SCREENSHOT_DEVICES=$'iPhone 15 Pro Max' scripts/screenshots.sh
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="${1:-build/screenshots}"
BUNDLE_ID="com.spartatechnology.drtimer"
# Newline-separated, since device names contain spaces.
DEVICES="${SCREENSHOT_DEVICES:-$'iPhone 16 Pro Max\niPhone 16 Pro'}"

rm -rf "$OUT" build/screenshot-work
mkdir -p "$OUT"

run_scenario() { # udid, work, dest, name, test-method, seconds-until-time-up
  local udid="$1" work="$2" dest="$3" name="$4" test="$5" seconds="$6"
  echo "--- $name"
  # The previous scenario's app keeps ticking in the background and saves the
  # run as it goes, which would overwrite the seed moments after it is written.
  xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
  # Re-resolved per scenario: reinstalling can hand the app a new container.
  local container
  container=$(xcrun simctl get_app_container "$udid" "$BUNDLE_ID" data)
  mkdir -p "$container/Documents"
  "$work/seedtool" "$container/Documents" "$seconds" >/dev/null
  xcodebuild test-without-building -project DRTimer.xcodeproj -scheme Screenshots \
    -destination "id=$udid" -derivedDataPath "$work/dd" \
    -resultBundlePath "$work/$name.xcresult" \
    -only-testing:"DRTimerUITests/ScreenshotTests/$test" \
    > "$work/$name.log" 2>&1 || { tail -25 "$work/$name.log"; exit 1; }
  xcrun xcresulttool export attachments \
    --path "$work/$name.xcresult" --output-path "$work/$name-att" >/dev/null
  python3 scripts/collect-screenshots.py "$work/$name-att" "$dest"
}

capture_device() {
  local device="$1"
  local work="build/screenshot-work/${device// /-}"
  local staging="$work/out"
  mkdir -p "$work" "$staging"

  local udid
  udid=$(xcrun simctl list devices available \
    | grep -F "$device (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
  [ -n "$udid" ] || { echo "No simulator named '$device'"; exit 1; }
  echo "=== $device ($udid)"

  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b

  # Built once per device; each scenario then reuses the same build.
  echo "Building..."
  xcodegen generate >/dev/null
  xcodebuild build-for-testing -project DRTimer.xcodeproj -scheme Screenshots \
    -destination "id=$udid" -derivedDataPath "$work/dd" > "$work/build.log" 2>&1 \
    || { tail -30 "$work/build.log"; exit 1; }

  local app
  app=$(find "$work/dd/Build/Products" -name "DRTimer.app" -maxdepth 2 | head -1)
  xcrun simctl install "$udid" "$app"

  # Compiled against the real DRCore sources, so the seeded JSON is
  # byte-identical to what the app itself would write.
  # (Top-level code only compiles in a file named main.swift, hence scripts/seed/.)
  swiftc -O -o "$work/seedtool" DRCore/Sources/DRCore/*.swift scripts/seed/main.swift

  # The marketing convention: 9:41, full bars, charged.
  xcrun simctl status_bar "$udid" override \
    --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3

  # 400s leaves a realistic few minutes on the clock by the time the app is up,
  # and still cannot expire mid-test; 25s puts the time-up scenario at the alert.
  run_scenario "$udid" "$work" "$staging" counting testCounting           400
  run_scenario "$udid" "$work" "$staging" timeup   testTimeUp             25
  run_scenario "$udid" "$work" "$staging" planning testPickerPlanAndAbout none

  xcrun simctl status_bar "$udid" clear

  # Named from a captured file rather than a table of device sizes, so the
  # directory always states the dimensions App Store Connect will actually see.
  local shot size
  shot=$(find "$staging" -name '*.png' | head -1)
  [ -n "$shot" ] || { echo "No screenshots captured for $device"; exit 1; }
  size=$(sips -g pixelWidth -g pixelHeight "$shot" \
    | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w"x"h}')
  mkdir -p "$OUT/$size"
  mv "$staging"/*.png "$OUT/$size/"
  echo "-> $OUT/$size"
}

while IFS= read -r device; do
  [ -n "$device" ] && capture_device "$device"
done <<< "$DEVICES"

echo
echo "Screenshots in $OUT:"
find "$OUT" -name '*.png' | sort
