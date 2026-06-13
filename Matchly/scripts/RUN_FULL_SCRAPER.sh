#!/bin/bash
# Run the fixed ERAS scraper to generate ERAS2026.json with ALL programs

echo "🚀 Starting ERAS 2026 Full Scraper"
echo "=================================="
echo ""

cd "$(dirname "$0")"

echo "⏳ This will scrape all 17 specialties..."
echo "   Expected time: 5-10 minutes"
echo "   Expected programs: 5,000-10,000+"
echo ""

python3 eras_proper_parser.py

echo ""
echo "=================================="
echo "✅ Scraping complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Check Matchly/Data/ERAS2026.json"
echo "   2. Add file to Xcode project"
echo "   3. Clean & rebuild (Shift+Cmd+K, then Cmd+B)"
echo ""


