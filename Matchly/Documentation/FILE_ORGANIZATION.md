# File Organization Guide

## Clean Project Structure

```
Matchly/                          # Main app folder
├── Data/                         # All data files
│   ├── ERAS2026.json             # Main ERAS database (add to Xcode!)
│   └── ERAS2026_broken.json.backup  # Backup of broken file (can delete)
│
├── Documentation/                # All documentation
│   ├── ERAS_IMPORT_README.md
│   ├── FIX_DATA_ISSUE.md
│   ├── PROJECT_STRUCTURE.md
│   └── FILE_ORGANIZATION.md      # This file
│
├── Models/                       # Swift data models
│   ├── DataManager.swift
│   ├── Program.swift
│   ├── ResidencyProgramDatabase.swift
│   ├── ScoringManager.swift
│   └── UserPreferences.swift
│
├── Views/                        # SwiftUI views
│   ├── Components/               # Reusable UI components
│   ├── Onboarding/               # Onboarding screens
│   ├── ContentView.swift
│   ├── MainTabView.swift
│   ├── ProgramDetailView.swift
│   ├── ProgramEntryView.swift
│   ├── ProgramSearchView.swift
│   ├── ProgramsListView.swift
│   ├── RankListView.swift
│   ├── SettingsView.swift
│   └── WeightsView.swift
│
├── scripts/                      # Python data extraction tools
│   ├── eras_proper_parser.py     # Main scraper (use this!)
│   ├── eras_selenium_scraper.py  # Alternative scraper
│   ├── check_scraper_status.sh   # Status checker
│   ├── requirements.txt
│   └── [other scripts]
│
├── Assets.xcassets/              # App assets
├── ContentView.swift
├── MatchlyApp.swift
└── README.md
```

## Rules

1. **Data files** → `Matchly/Data/`
2. **Documentation** → `Matchly/Documentation/`
3. **Scripts** → `Matchly/scripts/`
4. **No duplicate folders** - everything in one place
5. **No nested Matchly/Matchly/** - removed duplicates

## Adding ERAS2026.json to Xcode

1. Right-click `Matchly` folder in Xcode
2. Select "Add Files to Matchly..."
3. Navigate to `Matchly/Data/ERAS2026.json`
4. ✅ Check "Copy items if needed"
5. ✅ Check your app target
6. Click "Add"

## Cleanup

You can safely delete:
- `Matchly/Data/ERAS2026_broken.json.backup` (old broken file)


