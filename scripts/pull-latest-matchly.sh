#!/bin/zsh
# Pull the latest Matchly cloud-agent commits into THIS local checkout,
# then print a short verification checklist for Xcode.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Repo: $ROOT"
echo "Branch before: $(git branch --show-current 2>/dev/null || echo '(none)')"

BEFORE="$(git rev-parse HEAD)"
git fetch origin
git checkout cursor/dashboard-overview-polish
git pull --ff-only origin cursor/dashboard-overview-polish
AFTER="$(git rev-parse HEAD)"

# If git pull updated files (including this script), re-run so checks use the latest version.
if [[ "$BEFORE" != "$AFTER" && -z "${MATCHLY_PULL_RERUN:-}" ]]; then
  export MATCHLY_PULL_RERUN=1
  exec "$0" "$@"
fi

echo
echo "Latest commit:"
git log -1 --oneline
echo
echo "Build-fix checks (must all pass before opening Xcode):"
FAIL=0

if grep -q "static func arial" Matchly/Extensions/View+Extensions.swift; then
  echo "  OK  Font.arial defined in View+Extensions.swift"
else
  echo "  FAIL  Font.arial missing from View+Extensions.swift"
  FAIL=1
fi

if test ! -f Matchly/Extensions/Font+Arial.swift; then
  echo "  OK  Font+Arial.swift removed (helpers consolidated)"
else
  echo "  FAIL  Font+Arial.swift still present — pull did not apply"
  FAIL=1
fi

if grep -q "Blob" Matchly/Models/Managers/AccountCloudSyncManager.swift; then
  echo "  FAIL  AccountCloudSyncManager still references Blob"
  FAIL=1
else
  echo "  OK  AccountCloudSyncManager has no Blob reference"
fi

if grep -q "func arialFont" Matchly/Extensions/View+Extensions.swift; then
  echo "  OK  View.arialFont() defined"
else
  echo "  FAIL  View.arialFont() missing"
  FAIL=1
fi

if grep -q "Account Backup" Matchly/Views/DataBackupView.swift; then
  echo "  OK  Backup & Sync includes Account Backup"
else
  echo "  FAIL  Account Backup section missing from DataBackupView"
  FAIL=1
fi

if grep -q "iCloud Device Sync" Matchly/Views/DataBackupView.swift; then
  echo "  OK  Backup & Sync includes iCloud Device Sync"
else
  echo "  FAIL  iCloud Device Sync section missing from DataBackupView"
  FAIL=1
fi

if grep -q "MatchlyFormSectionHeader" Matchly/Views/SettingsView.swift; then
  echo "  OK  Settings uses black left-aligned section headers"
else
  echo "  FAIL  Settings section headers missing"
  FAIL=1
fi

echo
echo "Settings canary (optional UI verification):"
grep -nE "1\.0\.0|Add Email & Password|MatchlyFormSectionHeader" Matchly/Views/SettingsView.swift || true

echo
if [[ "$FAIL" -ne 0 ]]; then
  echo "One or more build-fix checks failed. Do NOT build in Xcode yet."
  echo "Try: git fetch origin && git reset --hard origin/cursor/dashboard-overview-polish"
  exit 1
fi

echo "All build-fix checks passed."
echo
echo "Next on Mac:"
echo "  1. Quit Xcode"
echo "  2. rm -rf ~/Library/Developer/Xcode/DerivedData/Matchly-*"
echo "  3. Open Matchly.xcodeproj from THIS folder (not an old iCloud copy)"
echo "  4. Product → Clean Build Folder (⇧⌘K), then Run (⌘R)"
echo "  5. Settings → About should show Version 1.0.0"
