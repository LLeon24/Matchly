# ERAS 2026 Database Import Guide

**⚠️ IMPORTANT: The app currently only has sample/hardcoded programs. To get ALL programs, you must import ERAS 2026 data.**

This app supports importing comprehensive residency program data from the ERAS 2026 database (AAMC/ACGME). The ERAS database contains thousands of programs across all specialties, but the data must be extracted from the AAMC website and imported into the app.

## Data Format

The app expects a JSON file named `ERAS2026.json` in the app bundle with the following structure:

```json
[
  {
    "id": "1403821100",
    "name": "Internal Medicine",
    "hospital": "Johns Hopkins Hospital",
    "city": "Baltimore",
    "state": "MD",
    "specialty": "Internal Medicine",
    "type": "Academic",
    "accreditationID": "1403821100"
  }
]
```

### Required Fields:
- `id`: Unique identifier (can use ACGME accreditation ID)
- `name`: Program name/specialty name
- `hospital`: Hospital or institution name
- `city`: City name
- `state`: Two-letter state code
- `specialty`: Specialty name (must match app specialties)
- `type`: "Academic", "Community", or "Hybrid"
- `accreditationID`: ACGME Program Code (optional but recommended)

## How to Get ERAS 2026 Data

The ERAS website (https://systems.aamc.org/eras/erasstats/par/index.cfm) doesn't provide direct downloads. You need to extract the data manually:

### Quick Method (Recommended):
1. **Use the Python Script:**
   - See `scripts/README_ERAS_EXTRACTION.md` for detailed instructions
   - The script helps convert ERAS data to the correct JSON format
   - Run: `python scripts/eras_data_extractor.py your_data.csv ERAS2026.json`

2. **Manual Extraction Steps:**
   - Visit: https://systems.aamc.org/eras/erasstats/par/index.cfm
   - Click on your specialty (e.g., "Internal Medicine")
   - Copy the program table data
   - Paste into Excel/Google Sheets
   - Clean up columns: Program Name, Hospital, City, State, Specialty, Type, ACGME ID
   - Save as CSV
   - Convert using the Python script

3. **Alternative: ACGME Program Search:**
   - Visit: https://www.acgme.org/programs-and-institutions/programs/search/
   - Search by specialty
   - Export results and format as CSV
   - Convert using the Python script

**For detailed extraction instructions, see: `scripts/README_ERAS_EXTRACTION.md`**

## Adding the Data File

### Method 1: Bundle Import (Development)
1. Create a JSON file named `ERAS2026.json`
2. Add it to your Xcode project:
   - Drag the file into the project navigator
   - Make sure it's added to the app target
   - Place it in the main bundle

3. The app will automatically load this file on startup if it exists

### Method 2: In-App Import (User)
1. Export your ERAS 2026 data as JSON (see format above)
2. Open the Matchly app
3. Go to Settings → Data Management
4. Tap "Import ERAS 2026 Data"
5. Select your JSON file
6. The app will import and replace all existing program data

## Programmatic Import

You can also import ERAS data programmatically:

```swift
// Load from a file URL
let url = URL(fileURLWithPath: "/path/to/ERAS2026.json")
try? ResidencyProgramDatabase.shared.loadFromERASJSONURL(url: url)

// Or load from Data
let data = // your JSON data
try? ResidencyProgramDatabase.shared.loadFromERASJSON(data: data)

// Or replace all existing data
try? ResidencyProgramDatabase.shared.replaceWithERASData(data: data)
```

## Specialty Names

Make sure specialty names in your JSON match exactly:
- "Internal Medicine"
- "Family Medicine"
- "Emergency Medicine"
- "Pediatrics"
- "General Surgery"
- "OB/GYN"
- "Psychiatry"
- "Neurology"
- "Anesthesiology"
- "Radiology"
- "Pathology"
- "Orthopedics"
- "ENT"
- "Urology"
- "PM&R"
- "Dermatology"
- "Neurosurgery"

## Notes

- If `ERAS2026.json` is found, it will replace all hardcoded programs
- If the file is not found or has errors, the app falls back to hardcoded sample programs
- The `accreditationID` field is optional but highly recommended for accurate program identification
- Program IDs should be unique across all programs

