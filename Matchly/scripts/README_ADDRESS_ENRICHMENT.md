# Address Enrichment for ERAS Programs

This script enriches the ERAS program database with street addresses for all hospitals.

## Overview

The `enrich_with_addresses.py` script:
1. Loads all programs from `ERAS2026.json`
2. For each program without an address, searches for the hospital's street address
3. Uses geocoding services (Google Maps API or OpenStreetMap Nominatim) to find addresses
4. Updates the JSON file with addresses

## Requirements

```bash
pip install requests
# Optional (for faster results):
pip install googlemaps
```

## Usage

### Option 1: Using Free OpenStreetMap Service (No API Key Required)

```bash
cd Matchly/scripts
python3 enrich_with_addresses.py
```

This uses the free Nominatim service. It's slower (1 second delay between requests) but doesn't require an API key.

### Option 2: Using Google Maps API (Faster, Requires API Key)

1. Get a Google Maps API key from [Google Cloud Console](https://console.cloud.google.com/)
2. Enable the Geocoding API
3. Set the API key:

```bash
export GOOGLE_MAPS_API_KEY="your-api-key-here"
python3 enrich_with_addresses.py
```

## Output

The script will:
- Create a new file: `ERAS2026_with_addresses.json`
- Show progress for each program
- Save progress every 10 programs (in case of interruption)
- Display summary of how many addresses were added

## Replacing the Original File

After enrichment is complete:

```bash
# Backup original
cp Matchly/Data/ERAS2026.json Matchly/Data/ERAS2026_backup.json

# Replace with enriched version
cp Matchly/Data/ERAS2026_with_addresses.json Matchly/Data/ERAS2026.json
```

## Notes

- The script respects rate limits (1 second delay for Nominatim, 0.1 seconds for Google)
- Progress is saved every 10 programs, so you can safely interrupt and resume
- If an address cannot be found, the program will remain without an address
- You can manually add addresses later through the app's UI

## Troubleshooting

**"File not found" error:**
- Make sure you're running from the correct directory
- Or provide the full path to ERAS2026.json when prompted

**Rate limiting errors:**
- If using Nominatim, ensure you're waiting 1 second between requests
- If using Google Maps, check your API quota

**No addresses found:**
- Some hospitals may not be in geocoding databases
- Try searching manually and adding addresses through the app UI


