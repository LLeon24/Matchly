# Quick Guide: Generate ERAS Data

## Why?
The app currently has no ERAS2026.json file, so it's using limited hardcoded programs. You need to run the scraper to get ALL programs from ERAS.

## Steps:

### 1. Run the Scraper
```bash
cd "/Users/leoh/Library/Mobile Documents/com~apple~CloudDocs/Leoh/Business/Matchly/Matchly/Matchly/scripts"
python3 eras_proper_parser.py
```

This will:
- Scrape all specialties from ERAS website
- Create `Matchly/Data/ERAS2026.json` with thousands of programs
- Take 5-10 minutes (scrapes 17 specialties)

### 2. Add to Xcode
1. Open Xcode
2. Right-click the `Matchly` folder in Project Navigator
3. Select "Add Files to Matchly..."
4. Navigate to `Matchly/Data/ERAS2026.json`
5. ✅ Check "Copy items if needed"
6. ✅ Check your app target
7. Click "Add"

### 3. Clean & Rebuild
- `Shift + Cmd + K` (Clean Build Folder)
- `Cmd + B` (Build)

### 4. Test
Search for "Florida" - you should now see all Florida programs!

## Alternative: Use Selenium Scraper
If the basic scraper fails (JavaScript-heavy pages):
```bash
python3 eras_selenium_scraper.py
```
(Requires Chrome/Chromium and selenium)


