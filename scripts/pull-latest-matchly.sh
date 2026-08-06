#!/usr/bin/env bash
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
echo "Auth-baseline checks (must all pass before opening Xcode):"
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

if grep -q 'recoveryTag = "auth-baseline' Matchly/Models/MatchlyBuildInfo.swift; then
  echo "  OK  Build marker is auth-baseline (post-login rewind)"
else
  echo "  FAIL  MatchlyBuildInfo.swift missing auth-baseline marker"
  FAIL=1
fi

if grep -q "switch outcome" Matchly/Views/DataBackupView.swift; then
  echo "  FAIL  DataBackupView still switches on merge outcome enum (API returns Bool)"
  FAIL=1
else
  echo "  OK  DataBackupView matches Bool merge API"
fi

if grep -q "headerQuickStatsBar" Matchly/Views/DashboardView.swift; then
  echo "  FAIL  Dashboard still has pinned KPI strip (removed in auth-baseline rewind)"
  FAIL=1
else
  echo "  OK  Dashboard has no pinned KPI strip under greeting"
fi

if grep -q "DashboardSectionTabBar" Matchly/Views/DashboardView.swift; then
  echo "  OK  Dashboard uses Overview/Programs/Interviews section tabs (auth-era layout)"
else
  echo "  FAIL  Dashboard section tabs missing"
  FAIL=1
fi

if grep -q "LinkEmailPasswordView" Matchly/Views/SettingsView.swift && \
   grep -q "Add Email & Password" Matchly/Views/SettingsView.swift; then
  echo "  OK  Settings includes Add Email & Password (auth feature)"
else
  echo "  FAIL  Add Email & Password missing from Settings"
  FAIL=1
fi

if grep -q "Replay Guided Tour" Matchly/Views/SettingsView.swift; then
  echo "  OK  Settings includes Replay Guided Tour"
else
  echo "  FAIL  Replay Guided Tour missing from Settings"
  FAIL=1
fi

if grep -q "programsMapEnabled = false" Matchly/Models/FeatureFlags.swift; then
  echo "  OK  Map tab disabled for V1"
else
  echo "  FAIL  Map tab flag missing or enabled"
  FAIL=1
fi

if grep -q 'title: "Map"' Matchly/Views/Components/LiquidGlassTabBar.swift && \
   ! grep -q "if FeatureFlags.programsMapEnabled" Matchly/Views/Components/LiquidGlassTabBar.swift; then
  echo "  FAIL  Map tab always visible — should be gated by programsMapEnabled"
  FAIL=1
elif grep -q "if FeatureFlags.programsMapEnabled" Matchly/Views/Components/LiquidGlassTabBar.swift; then
  echo "  OK  Map tab gated behind feature flag (hidden for V1)"
fi

if grep -q "MatchlyListPageToolbar" Matchly/Extensions/View+Extensions.swift; then
  echo "  OK  List pages use shared empty-state toolbar rule"
else
  echo "  FAIL  MatchlyListPageToolbar missing"
  FAIL=1
fi

if grep -q "MatchlyListPageToolbar.showsActions" Matchly/Views/ProgramsListView.swift; then
  echo "  OK  My Programs hides toolbar when empty"
else
  echo "  FAIL  My Programs empty-state toolbar rule missing"
  FAIL=1
fi

if grep -q "MatchlyFormSectionHeader" Matchly/Views/SettingsView.swift; then
  echo "  WARN  Settings still uses MatchlyFormSectionHeader (post-auth polish)"
fi

echo
if [[ "$FAIL" -ne 0 ]]; then
  echo "One or more checks failed. Do NOT build in Xcode yet."
  echo "Try: git fetch origin && git reset --hard origin/cursor/dashboard-overview-polish"
  exit 1
fi

echo "All auth-baseline checks passed."
echo
echo "Next on Mac:"
echo "  1. Quit Xcode"
echo "  2. rm -rf ~/Library/Developer/Xcode/DerivedData/Matchly-*"
echo "  3. Open Matchly.xcodeproj from THIS folder (not an old iCloud copy)"
echo "  4. Product → Clean Build Folder (⇧⌘K), then Run (⌘R)"
echo "  5. Settings → About should show Version 1.0.0 and Build 1.0.0 · auth-baseline-6"
echo "  6. My Programs empty: no Sort / + / Edit in nav bar; they appear once you add programs"
echo "  7. Tab bar: 4 tabs (Dashboard, Programs, Rank List, Settings) — no Map"
echo "  9. Auth intact: Apple / Google / email sign-in + Add Email & Password in Settings"
