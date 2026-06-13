#!/bin/bash
# Quick script to check if ERAS scraper is done

SCRAPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_FILE="$SCRAPER_DIR/../Matchly/Data/ERAS2026.json"

echo "🔍 Checking scraper status..."
echo ""

# Check if file exists
if [ -f "$DATA_FILE" ]; then
    FILE_SIZE=$(ls -lh "$DATA_FILE" | awk '{print $5}')
    echo "✅ File exists: $DATA_FILE"
    echo "   Size: $FILE_SIZE"
    echo ""
    
    # Count programs
    if command -v python3 &> /dev/null; then
        PROGRAM_COUNT=$(python3 -c "import json; data = json.load(open('$DATA_FILE')); print(len(data))" 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "📊 Total programs: $PROGRAM_COUNT"
            if [ "$PROGRAM_COUNT" -gt 1000 ]; then
                echo "   ✅ Looks complete! (Expected 5,000-10,000+ programs)"
            elif [ "$PROGRAM_COUNT" -gt 0 ]; then
                echo "   ⏳ Still scraping... (Currently has $PROGRAM_COUNT programs)"
            fi
        fi
    fi
else
    echo "⏳ File not created yet - scraper is still running..."
    echo ""
    echo "💡 The scraper will create:"
    echo "   $DATA_FILE"
    echo ""
    echo "⏱️  Expected time: 5-10 minutes for all specialties"
fi

echo ""
echo "To check again, run: ./check_scraper_status.sh"


