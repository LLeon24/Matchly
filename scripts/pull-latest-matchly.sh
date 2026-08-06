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

if grep -q "Cloud Backup" Matchly/Views/DataBackupView.swift; then
  echo "  OK  Backup & Sync uses simplified Cloud Backup UI"
else
  echo "  FAIL  Simplified Cloud Backup section missing"
  FAIL=1
fi

if grep -q 'static let version = "1.0"' Matchly/Models/MatchlyBuildInfo.swift; then
  echo "  OK  V1.0 build marker present"
else
  echo "  FAIL  MatchlyBuildInfo.swift missing 1.0 version marker"
  FAIL=1
fi

if grep -q "0.965, green: 0.969, blue: 0.976" Matchly/Models/AppColors.swift; then
  echo "  OK  Dashboard canvas uses cool near-white background (not cream)"
else
  echo "  FAIL  Dashboard canvas color wrong — may be on old main-branch cream"
  FAIL=1
fi

if grep -q "accentGreen" Matchly/Views/Components/LiquidGlassTabBar.swift && \
   grep -q "accentPink" Matchly/Views/Components/LiquidGlassTabBar.swift; then
  echo "  OK  Tab bar uses green (Programs) and pink (Rank List) accent colors"
else
  echo "  FAIL  Tab bar accent colors missing"
  FAIL=1
fi

if grep -q "Get Started" Matchly/Views/DashboardView.swift && \
   grep -q "No Programs Yet" Matchly/Views/ProgramsListView.swift && \
   grep -q "No Programs to Rank" Matchly/Views/RankListView.swift; then
  echo "  OK  Dashboard, Programs, and Rank List empty states present"
else
  echo "  FAIL  Tab empty-state copy missing"
  FAIL=1
fi

if grep -q "programsMapEnabled = false" Matchly/Models/FeatureFlags.swift; then
  echo "  OK  Map tab disabled for V1"
else
  echo "  FAIL  Map tab flag missing or enabled"
  FAIL=1
fi

if grep -q "iCloud Device Sync" Matchly/Views/DataBackupView.swift; then
  echo "  WARN  Legacy iCloud Device Sync section present in Backup view"
fi

if grep -q "MatchlyFormSectionHeader" Matchly/Views/SettingsView.swift; then
  echo "  OK  Settings uses black left-aligned section headers"
else
  echo "  FAIL  Settings section headers missing"
  FAIL=1
fi

if grep -q "headerQuickStatsBar" Matchly/Views/DashboardView.swift; then
  echo "  OK  Dashboard pinned header includes Signals KPI strip"
else
  echo "  FAIL  Dashboard header quick stats (Signals) missing"
  FAIL=1
fi

if grep -q "showQuickStats: Bool = true" Matchly/Models/Data/UserPreferences.swift; then
  echo "  OK  Dashboard quick stats enabled by default"
else
  echo "  FAIL  showQuickStats default not true"
  FAIL=1
fi

if grep -q "MatchlyFormSectionHeader" Matchly/Views/DataBackupView.swift && \
   grep -q "MatchlyFormSectionHeader" Matchly/Views/SettingsView.swift; then
  echo "  OK  Settings and Backup use aligned black 17pt section headers"
else
  echo "  FAIL  MatchlyFormSectionHeader missing from Settings or Backup"
  FAIL=1
fi

if grep -q "MatchlySpecialtySectionHeader" Matchly/Views/ProgramsListView.swift && \
   grep -q "MatchlySpecialtySectionHeader" Matchly/Views/RankListView.swift; then
  echo "  OK  Program lists use colored specialty section headers"
else
  echo "  FAIL  Colored specialty headers missing from program lists"
  FAIL=1
fi

if grep -q "buttonStyle(.glassProminent)" Matchly/Views/RankListView.swift && \
   grep -q 'Text("Export PDF")' Matchly/Views/RankListView.swift; then
  echo "  OK  Rank list has prominent Export PDF button"
else
  echo "  FAIL  Prominent Export PDF button missing from Rank List"
  FAIL=1
fi

if grep -q "AppColors.primaryBlue, AppColors.accentPurple" Matchly/Views/DashboardView.swift; then
  echo "  OK  Dashboard empty state uses gradient icon colors"
else
  echo "  FAIL  Dashboard empty-state color polish missing"
  FAIL=1
fi

if grep -q "aamcID" Matchly/Utilities/RankListPDFExporter.swift; then
  echo "  OK  Rank list PDF includes AAMC ID in header"
else
  echo "  FAIL  Rank list PDF missing AAMC ID support"
  FAIL=1
fi

if grep -q "Export PDF" Matchly/Views/RankListView.swift; then
  echo "  OK  Rank list has visible Export PDF control"
else
  echo "  FAIL  Export PDF button missing from Rank List"
  FAIL=1
fi

if grep -q "RankListPDFExporter" Matchly/Views/RankListView.swift; then
  echo "  OK  Rank list PDF exporter wired in RankListView"
else
  echo "  FAIL  RankListPDFExporter not referenced in RankListView"
  FAIL=1
fi

if grep -q 'foregroundStyle(AppColors.primaryBlue)' Matchly/Views/SettingsView.swift; then
  echo "  OK  Settings Replay Guided Tour uses brand blue"
else
  echo "  FAIL  Replay Guided Tour blue styling missing"
  FAIL=1
fi

if grep -A6 'Add Email & Password' Matchly/Views/SettingsView.swift | grep -q 'glassProminent'; then
  echo "  OK  Add Email & Password is a prominent action button"
else
  echo "  FAIL  Add Email & Password prominent button missing"
  FAIL=1
fi

echo
echo "Settings canary (optional UI verification):"
grep -nE "MatchlyBuildInfo|MatchlyFormSectionHeader" Matchly/Views/SettingsView.swift || true

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
echo "  5. Settings → About should show Version 1.0 and Build 1.0 · recovery-8"
echo "  6. Dashboard: KPI strip (Programs/Interviews/Avg/Signals) under greeting"
echo "  7. Settings: blue Replay Guided Tour + prominent Add Email & Password button"
echo "  8. Rank List: full-width Export PDF; PDF includes name + AAMC ID"
echo "  9. Tab bar: 4 tabs (no Map); colored specialty headers on program lists"
