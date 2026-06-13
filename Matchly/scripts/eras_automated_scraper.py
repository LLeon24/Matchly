#!/usr/bin/env python3
"""
Automated ERAS 2026 Data Scraper
Extracts all residency programs from the AAMC ERAS website automatically

Requirements:
    pip install requests beautifulsoup4 lxml

Usage:
    python eras_automated_scraper.py
"""

import requests
from bs4 import BeautifulSoup
import json
import time
import re
from typing import List, Dict, Optional
from urllib.parse import urljoin, urlparse, parse_qs

# Base URL for ERAS
BASE_URL = "https://systems.aamc.org"
ERAS_INDEX = "https://systems.aamc.org/eras/erasstats/par/index.cfm"

# Specialty codes for residency programs (September Cycle)
RESIDENCY_SPECIALTIES = {
    "Internal Medicine": "140",
    "Family Medicine": "120",
    "Emergency Medicine": "110",
    "Pediatrics": "320",
    "General Surgery": "440",
    "OB/GYN": "220",
    "Psychiatry": "400",
    "Neurology": "180",
    "Anesthesiology": "040",
    "Radiology": "420",
    "Pathology": "300",
    "Orthopedics": "260",
    "ENT": "280",
    "Urology": "480",
    "PM&R": "340",
    "Dermatology": "080",
    "Neurosurgery": "160",
}

# Specialty name normalization
SPECIALTY_NORMALIZATION = {
    "Internal Medicine": "Internal Medicine",
    "Family Medicine": "Family Medicine",
    "Emergency Medicine": "Emergency Medicine",
    "Pediatrics": "Pediatrics",
    "General Surgery": "General Surgery",
    "Obstetrics and Gynecology": "OB/GYN",
    "OB/GYN": "OB/GYN",
    "Psychiatry": "Psychiatry",
    "Neurology": "Neurology",
    "Anesthesiology": "Anesthesiology",
    "Diagnostic Radiology": "Radiology",
    "Radiology": "Radiology",
    "Pathology": "Pathology",
    "Orthopaedic Surgery": "Orthopedics",
    "Orthopedics": "Orthopedics",
    "Otolaryngology": "ENT",
    "ENT": "ENT",
    "Urology": "Urology",
    "Physical Medicine and Rehabilitation": "PM&R",
    "PM&R": "PM&R",
    "Dermatology": "Dermatology",
    "Neurological Surgery": "Neurosurgery",
    "Neurosurgery": "Neurosurgery",
}

def get_session():
    """Create a requests session with appropriate headers"""
    session = requests.Session()
    session.headers.update({
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
    })
    return session

def extract_programs_from_page(session: requests.Session, specialty_code: str, specialty_name: str) -> List[Dict]:
    """Extract all programs from a specialty page"""
    url = f"{BASE_URL}/eras/erasstats/par/display.cfm?NAV_ROW=PAR&SPEC_CD={specialty_code}"
    
    print(f"  Fetching {specialty_name}...", end=" ", flush=True)
    
    try:
        response = session.get(url, timeout=30)
        response.raise_for_status()
        
        soup = BeautifulSoup(response.content, 'html.parser')
        programs = []
        
        # Find the table containing program data
        # ERAS typically displays programs in a table format
        tables = soup.find_all('table')
        
        for table in tables:
            rows = table.find_all('tr')
            
            # Skip header row
            for row in rows[1:]:
                cells = row.find_all(['td', 'th'])
                
                if len(cells) < 3:
                    continue
                
                # Extract data from cells
                # The exact structure may vary, so we'll try multiple patterns
                program_text = ' '.join([cell.get_text(strip=True) for cell in cells])
                
                # Try to extract program name, hospital, location
                # This is a generic parser - you may need to adjust based on actual HTML structure
                program_name = cells[0].get_text(strip=True) if len(cells) > 0 else ""
                hospital = cells[1].get_text(strip=True) if len(cells) > 1 else ""
                location = cells[2].get_text(strip=True) if len(cells) > 2 else ""
                
                # Parse location (City, State)
                city = ""
                state = ""
                if location:
                    parts = location.split(',')
                    if len(parts) >= 2:
                        city = parts[0].strip()
                        state = parts[-1].strip()[:2]  # Take first 2 chars for state
                    else:
                        city = location.strip()
                
                # Try to extract ACGME ID from links or text
                acgme_id = None
                links = row.find_all('a', href=True)
                for link in links:
                    href = link.get('href', '')
                    # Look for ACGME ID in URL parameters
                    if 'PROG_CD' in href or 'program' in href.lower():
                        # Extract ID from URL
                        match = re.search(r'(\d+)', href)
                        if match:
                            acgme_id = match.group(1)
                
                # If no ACGME ID found, try to extract from text
                if not acgme_id:
                    id_match = re.search(r'(\d{10})', program_text)
                    if id_match:
                        acgme_id = id_match.group(1)
                
                # Determine program type (default to Academic)
                program_type = "Academic"
                program_text_lower = program_text.lower()
                if 'community' in program_text_lower:
                    program_type = "Community"
                elif 'hybrid' in program_text_lower:
                    program_type = "Hybrid"
                
                if program_name or hospital:
                    programs.append({
                        'id': acgme_id or f"{specialty_name}_{len(programs) + 1}",
                        'name': program_name or specialty_name,
                        'hospital': hospital or program_name,
                        'city': city,
                        'state': state,
                        'specialty': SPECIALTY_NORMALIZATION.get(specialty_name, specialty_name),
                        'type': program_type,
                        'accreditationID': acgme_id
                    })
        
        # If table parsing didn't work, try alternative methods
        if not programs:
            # Look for program listings in other formats (divs, lists, etc.)
            program_divs = soup.find_all(['div', 'li'], class_=re.compile(r'program|residency', re.I))
            for div in program_divs:
                text = div.get_text(strip=True)
                if text and len(text) > 10:  # Filter out empty/short elements
                    # Try to parse program info from text
                    # This is a fallback - may need customization
                    programs.append({
                        'id': f"{specialty_name}_{len(programs) + 1}",
                        'name': specialty_name,
                        'hospital': text[:100],  # First 100 chars as hospital
                        'city': '',
                        'state': '',
                        'specialty': SPECIALTY_NORMALIZATION.get(specialty_name, specialty_name),
                        'type': 'Academic',
                        'accreditationID': None
                    })
        
        print(f"✓ Found {len(programs)} programs")
        return programs
        
    except requests.RequestException as e:
        print(f"✗ Error: {e}")
        return []
    except Exception as e:
        print(f"✗ Parsing error: {e}")
        return []

def scrape_all_specialties(session: requests.Session, specialties: Dict[str, str]) -> List[Dict]:
    """Scrape all specialties"""
    all_programs = []
    
    print(f"\nScraping {len(specialties)} specialties from ERAS 2026...\n")
    
    for specialty_name, specialty_code in specialties.items():
        programs = extract_programs_from_page(session, specialty_code, specialty_name)
        all_programs.extend(programs)
        
        # Be respectful - add delay between requests
        time.sleep(1)
    
    return all_programs

def save_to_json(programs: List[Dict], filename: str = "ERAS2026.json"):
    """Save programs to JSON file"""
    # Remove None values from accreditationID
    for program in programs:
        if program.get('accreditationID') is None:
            program.pop('accreditationID', None)
    
    with open(filename, 'w', encoding='utf-8') as f:
        json.dump(programs, f, indent=2, ensure_ascii=False)
    
    print(f"\n✓ Saved {len(programs)} programs to {filename}")
    print(f"✓ File is ready to import into Matchly app")

def main():
    print("=" * 60)
    print("ERAS 2026 Automated Data Scraper")
    print("=" * 60)
    print("\nThis script will automatically extract all residency programs")
    print("from the AAMC ERAS website.\n")
    
    session = get_session()
    
    # Test connection
    print("Testing connection to ERAS website...", end=" ", flush=True)
    try:
        response = session.get(ERAS_INDEX, timeout=10)
        response.raise_for_status()
        print("✓ Connected\n")
    except Exception as e:
        print(f"✗ Error: {e}")
        print("\nPlease check your internet connection and try again.")
        return
    
    # Scrape all specialties
    all_programs = scrape_all_specialties(session, RESIDENCY_SPECIALTIES)
    
    if not all_programs:
        print("\n⚠️  No programs found. The website structure may have changed.")
        print("   You may need to update the parsing logic in this script.")
        print("\n   Alternative: Use the manual extraction method described in")
        print("   scripts/README_ERAS_EXTRACTION.md")
        return
    
    # Save to JSON
    save_to_json(all_programs)
    
    print("\n" + "=" * 60)
    print("Next Steps:")
    print("1. Review ERAS2026.json to verify the data")
    print("2. Import into Matchly app:")
    print("   - Option A: Add ERAS2026.json to Xcode project bundle")
    print("   - Option B: Use Settings → Import ERAS 2026 Data")
    print("=" * 60)

if __name__ == '__main__':
    main()


