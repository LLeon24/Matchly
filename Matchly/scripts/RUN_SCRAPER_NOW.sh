#!/bin/bash
# Quick script to run the ERAS scraper and generate ERAS2026.json

echo "🚀 Starting ERAS 2026 Scraper..."
echo ""

# Navigate to scripts directory
cd "$(dirname "$0")"

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: python3 not found"
    exit 1
fi

# Check if required packages are installed
echo "📦 Checking dependencies..."
python3 -c "import requests, bs4" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "⚠️  Installing required packages..."
    pip3 install -q requests beautifulsoup4 lxml
fi

echo ""
echo "⏳ Scraping all specialties from ERAS website..."
echo "   This will take 5-10 minutes..."
echo ""

# Run the scraper
python3 eras_proper_parser.py

# Check if file was created
if [ -f "../Matchly/Data/ERAS2026.json" ]; then
    FILE_SIZE=$(ls -lh "../Matchly/Data/ERAS2026.json" | awk '{print $5}')
    PROGRAM_COUNT=$(python3 -c "import json; data = json.load(open('../Matchly/Data/ERAS2026.json')); print(len(data))" 2>/dev/null)
    
    echo ""
    echo "✅ SUCCESS!"
    echo "   File: Matchly/Data/ERAS2026.json"
    echo "   Size: $FILE_SIZE"
    echo "   Programs: $PROGRAM_COUNT"
    echo ""
    echo "📝 Next step: Add this file to Xcode project"
else
    echo ""
    echo "❌ Error: File was not created"
    echo "   Check the error messages above"
fi


