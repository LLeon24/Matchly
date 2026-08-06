#!/bin/zsh
# Pull the latest Matchly cloud-agent commits into THIS local checkout,
# then print a short verification checklist for Xcode.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Repo: $ROOT"
echo "Branch before: $(git branch --show-current 2>/dev/null || echo '(none)')"

git fetch origin
git checkout cursor/dashboard-overview-polish
git pull --ff-only origin cursor/dashboard-overview-polish

echo
echo "Latest commit:"
git log -1 --oneline
echo
echo "Verify these exist:"
rg -n "1\\.0\\.1|Add Email & Password|settingsSectionHeader" Matchly/Views/SettingsView.swift || true
echo
echo "Next: open this folder in Xcode → Product → Clean Build Folder → Run"
echo "Settings → About should show Version 1.0.1"
