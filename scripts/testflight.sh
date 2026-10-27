#!/bin/bash
# Bump the build number, archive, and upload to App Store Connect (TestFlight).
# Usage: scripts/testflight.sh
set -euo pipefail
cd "$(dirname "$0")/.."

current=$(sed -n 's/.*CURRENT_PROJECT_VERSION: "\([0-9]*\)".*/\1/p' project.yml)
next=$((current + 1))
sed -i '' "s/CURRENT_PROJECT_VERSION: \"$current\"/CURRENT_PROJECT_VERSION: \"$next\"/" project.yml
xcodegen generate >/dev/null
echo "Build number: $current -> $next"

mkdir -p build
rm -rf build/DRTimer.xcarchive build/export
cat > build/ExportOptions.plist <<'P'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>app-store-connect</string>
<key>destination</key><string>upload</string>
<key>teamID</key><string>675JQKFZ8G</string>
<key>signingStyle</key><string>automatic</string>
<key>uploadSymbols</key><true/>
</dict></plist>
P

xcodebuild archive -project DRTimer.xcodeproj -scheme DRTimer \
  -destination 'generic/platform=iOS' -archivePath build/DRTimer.xcarchive \
  -allowProvisioningUpdates > build/archive.log 2>&1
xcodebuild -exportArchive -archivePath build/DRTimer.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist -exportPath build/export \
  -allowProvisioningUpdates > build/export.log 2>&1

git add project.yml
git commit -q -m "Bump build number to $next for TestFlight" || true
echo "Uploaded build $next. Processing takes ~10-30 min."
