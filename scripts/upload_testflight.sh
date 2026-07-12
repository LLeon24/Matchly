#!/bin/bash
# Archive Matchly and upload to App Store Connect (TestFlight).
#
# Develop with Xcode 27 beta, but upload with Xcode 26.6 CLI — Apple rejects
# iphoneos27.0 beta SDK uploads (error 90534). Stable Xcode CLI works on macOS 27 beta.
#
# Usage: ./scripts/upload_testflight.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Stable Xcode for App Store upload (beta SDK is rejected)
XCODE="${UPLOAD_DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ARCHIVE="$ROOT/build/Matchly.xcarchive"
EXPORT_DIR="$ROOT/build/export"
EXPORT_PLIST="$ROOT/ExportOptions.plist"

echo "Using Xcode at: $XCODE"
"$XCODE/usr/bin/xcodebuild" -version

rm -rf "$ARCHIVE" "$EXPORT_DIR"
mkdir -p "$ROOT/build"

echo "Archiving Matchly (Release, device)..."
"$XCODE/usr/bin/xcodebuild" \
  -project "$ROOT/Matchly.xcodeproj" \
  -scheme Matchly \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  archive

echo "Exporting and uploading to App Store Connect..."
"$XCODE/usr/bin/xcodebuild" \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -allowProvisioningUpdates

echo "Done. Check App Store Connect → TestFlight for build processing."
