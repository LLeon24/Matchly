# Matchly Project Structure

This document describes the organization of the Matchly project files.

## 📁 Directory Structure

```
Matchly/
├── Assets.xcassets/          # App icons and colors
├── Data/                      # Data files (ERAS JSON, etc.)
│   └── ERAS2026.json         # ERAS 2026 program database (when imported)
├── Documentation/            # Documentation files
│   ├── ERAS_IMPORT_README.md # ERAS import instructions
│   ├── ERAS2026_Sample.json # Sample JSON format
│   └── PROJECT_STRUCTURE.md # This file
├── Models/                   # Data models and business logic
│   ├── DataManager.swift     # Core data management
│   ├── Program.swift         # Program data model
│   ├── ResidencyProgramDatabase.swift # ERAS database
│   ├── ScoringManager.swift  # Score calculation
│   └── UserPreferences.swift # User settings
├── Views/                    # SwiftUI views
│   ├── Components/          # Reusable UI components
│   │   ├── VoiceMemoPlayer.swift
│   │   ├── VoiceMemoRecorder.swift
│   │   └── WeightSlider.swift
│   ├── Onboarding/          # Onboarding flow
│   │   ├── SpecialtySelectionView.swift
│   │   ├── SplashView.swift
│   │   └── WeightsSetupView.swift
│   ├── MainTabView.swift    # Main tab navigation
│   ├── ProgramDetailView.swift
│   ├── ProgramEntryView.swift
│   ├── ProgramSearchView.swift
│   ├── ProgramsListView.swift
│   ├── RankListView.swift
│   ├── SettingsView.swift
│   └── WeightsView.swift
├── scripts/                  # Python scripts for data extraction
│   ├── eras_automated_scraper.py
│   ├── eras_data_extractor.py
│   ├── eras_fixed_scraper.py
│   ├── eras_proper_parser.py
│   ├── eras_selenium_scraper.py
│   ├── QUICK_START.md
│   ├── README_ERAS_EXTRACTION.md
│   └── requirements.txt
├── ContentView.swift         # Preview helper
└── MatchlyApp.swift          # App entry point
```

## 📂 File Organization Rules

### Models/
- **Purpose**: Data structures, business logic, data persistence
- **Naming**: PascalCase (e.g., `DataManager.swift`)
- **Contains**: 
  - Data models (structs/classes)
  - Database/API managers
  - Business logic (scoring, calculations)

### Views/
- **Purpose**: SwiftUI user interface
- **Naming**: PascalCase with "View" suffix (e.g., `ProgramSearchView.swift`)
- **Organization**:
  - `Components/`: Reusable UI components
  - `Onboarding/`: First-time user flow
  - Root level: Main app screens

### Data/
- **Purpose**: Static data files, imported data
- **Contains**: 
  - `ERAS2026.json`: Imported ERAS database
  - Other data files as needed

### Documentation/
- **Purpose**: Project documentation, guides, samples
- **Contains**:
  - README files
  - Sample data files
  - Import/export guides

### scripts/
- **Purpose**: Python scripts for data processing
- **Contains**:
  - ERAS data scrapers
  - Data conversion tools
  - Documentation for scripts

## 🔄 Data Flow

1. **ERAS Data Import**:
   - User runs Python scraper → `ERAS2026.json`
   - File placed in `Data/` folder
   - App loads on startup via `ResidencyProgramDatabase`

2. **User Data**:
   - Programs stored via `DataManager`
   - Persisted in `UserDefaults`
   - Models in `Models/Program.swift`

3. **Search Flow**:
   - `ProgramSearchView` → `ResidencyProgramDatabase.search()`
   - Returns filtered `ResidencyProgramInfo` objects
   - User selects → `ProgramEntryView` auto-fills

## 📝 Naming Conventions

- **Swift Files**: PascalCase (e.g., `ProgramDetailView.swift`)
- **Models**: PascalCase (e.g., `ResidencyProgramInfo`)
- **Functions**: camelCase (e.g., `loadPrograms()`)
- **Constants**: camelCase (e.g., `programsKey`)
- **Python Scripts**: snake_case (e.g., `eras_proper_parser.py`)

## 🎯 Best Practices

1. **Keep Models separate from Views** - Business logic in Models/
2. **Reusable components in Components/** - Don't duplicate UI code
3. **Documentation stays in Documentation/** - Keep code folders clean
4. **Data files in Data/** - Easy to find and manage
5. **Scripts in scripts/** - Separate from app code

## 📦 Adding New Files

- **New View**: Add to `Views/` (or subfolder if reusable)
- **New Model**: Add to `Models/`
- **New Component**: Add to `Views/Components/`
- **New Data File**: Add to `Data/`
- **New Documentation**: Add to `Documentation/`
- **New Script**: Add to `scripts/`


