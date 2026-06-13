# Quick Start: Automated ERAS Data Extraction

## 🎯 One-Command Solution

Run this to automatically extract ALL ERAS 2026 programs:

```bash
cd scripts
pip install -r requirements.txt
python eras_automated_scraper.py
```

That's it! The script will:
1. Connect to the ERAS website
2. Visit all 17 residency specialties
3. Extract thousands of programs
4. Save to `ERAS2026.json`

## 📥 Import into Matchly

After running the scraper, you have two options:

### Option A: Bundle Import (Development)
1. Copy `ERAS2026.json` to your Xcode project
2. Drag it into the project navigator
3. Make sure it's added to the app target
4. Run the app - it will automatically load!

### Option B: In-App Import (User)
1. Copy `ERAS2026.json` to your iPhone/iPad (via AirDrop, Files app, etc.)
2. Open Matchly app
3. Go to **Settings → Data Management**
4. Tap **"Import ERAS 2026 Data"**
5. Select `ERAS2026.json`

## 🔧 Troubleshooting

### If the basic scraper doesn't work:

The ERAS website structure may vary. Try the Selenium version:

```bash
# Install ChromeDriver first
brew install chromedriver  # macOS
# Or download from: https://chromedriver.chromium.org/

# Run Selenium scraper
python eras_selenium_scraper.py
```

### If you get "No programs found":

1. Check your internet connection
2. The website structure may have changed - you may need to update the parsing logic
3. Try the manual extraction method as a fallback

### If you get import errors:

1. Verify the JSON file is valid: `python -m json.tool ERAS2026.json`
2. Check that specialty names match exactly (see ERAS_IMPORT_README.md)
3. Ensure all required fields are present

## 📊 Expected Results

After running, you should have:
- **Thousands of programs** (not just 200 sample ones)
- **All specialties** covered
- **ACGME accreditation IDs** included
- **All states** represented (including Florida!)

## ⚡ Quick Test

After importing, search for:
- "Florida" - should show many programs
- "Johns Hopkins" - should show multiple programs
- Your specialty - should show all programs in that specialty

If you see results, the import worked! 🎉


