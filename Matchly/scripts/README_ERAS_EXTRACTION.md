# Extracting ERAS 2026 Data from AAMC Website

The ERAS 2026 database at https://systems.aamc.org/eras/erasstats/par/index.cfm contains all residency and fellowship programs, but the data isn't directly downloadable. 

## 🚀 Automated Methods (Recommended)

### Method 1: Automated Scraper (Easiest)

**Fully automated - no manual work required!**

```bash
# Install dependencies
pip install -r requirements.txt

# Run the automated scraper
python scripts/eras_automated_scraper.py
```

This script will:
- ✅ Automatically visit all specialty pages
- ✅ Extract all program data
- ✅ Convert to JSON format
- ✅ Save as `ERAS2026.json` ready for import

**Note:** If the basic scraper doesn't work (website structure may vary), use the Selenium version below.

### Method 2: Selenium Scraper (For JavaScript-Heavy Pages)

If the basic scraper doesn't work, use the Selenium version:

```bash
# Install dependencies
pip install -r requirements.txt

# Download ChromeDriver (if not already installed)
# macOS: brew install chromedriver
# Or download from: https://chromedriver.chromium.org/

# Run Selenium scraper
python scripts/eras_selenium_scraper.py
```

This opens a Chrome browser and automatically extracts all data.

## Manual Methods (If Automated Doesn't Work)

## Method 1: Manual Copy-Paste (Quickest for Small Lists)

1. Go to https://systems.aamc.org/eras/erasstats/par/index.cfm
2. Click on your specialty (e.g., "Internal Medicine")
3. Select all the program data (Cmd+A / Ctrl+A)
4. Copy and paste into Excel or Google Sheets
5. Clean up the columns to match: Program Name, Hospital, City, State, Specialty, Type, ACGME ID
6. Save as CSV
7. Run the Python script to convert to JSON:
   ```bash
   python scripts/eras_data_extractor.py your_data.csv ERAS2026.json
   ```

## Method 2: Browser Extension / Web Scraper

### Using a Browser Extension:
1. Install a table export extension (like "Table to CSV" for Chrome)
2. Navigate to the specialty page on ERAS
3. Use the extension to export the table as CSV
4. Convert using the Python script

### Using Python Selenium (Advanced):
```python
from selenium import webdriver
from selenium.webdriver.common.by import By
import csv

# Navigate to ERAS specialty page
driver = webdriver.Chrome()
driver.get("https://systems.aamc.org/eras/erasstats/par/display.cfm?NAV_ROW=PAR&SPEC_CD=140")

# Extract table data
table = driver.find_element(By.TAG_NAME, "table")
rows = table.find_elements(By.TAG_NAME, "tr")

# Save to CSV
with open('eras_data.csv', 'w', newline='') as f:
    writer = csv.writer(f)
    for row in rows:
        cells = row.find_elements(By.TAG_NAME, "td")
        writer.writerow([cell.text for cell in cells])
```

## Method 3: ACGME Program Search Export

1. Go to https://www.acgme.org/programs-and-institutions/programs/search/
2. Search by specialty
3. Use browser developer tools or extensions to export the results
4. Format the data to match the CSV template
5. Convert using the Python script

## Method 4: Request Data from AAMC

Contact AAMC directly to request program data:
- Email: eras@aamc.org
- They may provide data in a structured format for educational/research purposes

## CSV Format Required

Your CSV file should have these columns (in any order):
- Program Name (or Name, Program)
- Hospital (or Institution, Hospital Name)
- City
- State (two-letter code)
- Specialty (or Specialty Name)
- Type (Academic, Community, or Hybrid)
- ACGME ID (or Accreditation ID, Program Code) - optional but recommended

## Converting to JSON

Once you have a CSV file:

```bash
# Install Python if needed
# Then run:
python scripts/eras_data_extractor.py your_export.csv ERAS2026.json
```

The script will:
- Automatically map column names
- Normalize specialty names to match the app
- Generate IDs if ACGME IDs aren't available
- Create a properly formatted JSON file

## Importing into Matchly

1. **Option A: Bundle Import (Development)**
   - Add `ERAS2026.json` to your Xcode project
   - Place it in the app bundle
   - The app will load it automatically

2. **Option B: In-App Import (User)**
   - Open Matchly app
   - Go to Settings → Data Management
   - Tap "Import ERAS 2026 Data"
   - Select your `ERAS2026.json` file

## Specialty Code Reference

When accessing ERAS directly, use these specialty codes in the URL:
- Internal Medicine: `SPEC_CD=140`
- Family Medicine: `SPEC_CD=120`
- Emergency Medicine: `SPEC_CD=110`
- Pediatrics: `SPEC_CD=320`
- General Surgery: `SPEC_CD=440`
- OB/GYN: `SPEC_CD=220`
- Psychiatry: `SPEC_CD=400`
- Neurology: `SPEC_CD=180`
- Anesthesiology: `SPEC_CD=040`
- Radiology: `SPEC_CD=420`
- Pathology: `SPEC_CD=300`
- Orthopedics: `SPEC_CD=260`
- ENT: `SPEC_CD=280`
- Urology: `SPEC_CD=480`
- PM&R: `SPEC_CD=340`
- Dermatology: `SPEC_CD=080`
- Neurosurgery: `SPEC_CD=160`

Example URL for Internal Medicine:
`https://systems.aamc.org/eras/erasstats/par/display.cfm?NAV_ROW=PAR&SPEC_CD=140`

## Notes

- The ERAS website may have rate limiting or require authentication
- Data extraction should comply with AAMC terms of service
- Consider reaching out to AAMC for official data access if you need bulk extraction
- The Python script handles common variations in column names and data formats

