# Matchly - Residency Rank List App

A clean, intuitive iOS app to help medical students organize residency interview information and generate personalized rank lists.

## 📁 Project Organization

```
Matchly/
├── Data/                    # Data files (ERAS JSON imports)
├── Documentation/           # All documentation
├── Models/                  # Data models & business logic
├── Views/                   # SwiftUI user interface
│   ├── Components/         # Reusable UI components
│   └── Onboarding/        # First-time user flow
└── scripts/                # Python data extraction tools
```

See `Documentation/PROJECT_STRUCTURE.md` for detailed organization rules.

## 🚀 Quick Start

### For Users:
1. Open the app
2. Select your specialty
3. Start adding programs or search the database

### For Developers:

#### Import ERAS 2026 Data:
```bash
cd Matchly/scripts
pip3 install -r requirements.txt
python3 eras_proper_parser.py
```

This creates `Matchly/Data/ERAS2026.json` with properly formatted data.

#### Add to Xcode:
1. Drag `Matchly/Data/ERAS2026.json` into Xcode project
2. Ensure it's in the app target
3. Build and run

## 📚 Documentation

- **ERAS Import**: `Documentation/ERAS_IMPORT_README.md`
- **Data Extraction**: `scripts/README_ERAS_EXTRACTION.md`
- **Quick Start**: `scripts/QUICK_START.md`
- **Project Structure**: `Documentation/PROJECT_STRUCTURE.md`
- **Fix Data Issues**: `Documentation/FIX_DATA_ISSUE.md`

## ⚠️ Current Status

The ERAS data needs to be re-scraped with the fixed parser. See `Documentation/FIX_DATA_ISSUE.md` for instructions.

## 🎯 Features

- ✅ Search comprehensive ERAS 2026 database
- ✅ Organize programs with detailed ratings
- ✅ Automatic score calculation
- ✅ Personalized rank list generation
- ✅ Voice memos and notes
- ✅ Clean, minimalist UI


