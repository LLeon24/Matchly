#!/usr/bin/env python3
"""
Fixed ERAS 2026 Data Scraper
Properly parses ERAS website tables to extract structured program data

Requirements:
    pip install requests beautifulsoup4 lxml

Usage:
    python eras_fixed_scraper.py
"""

import requests
from bs4 import BeautifulSoup
import json
import time
import re
from typing import List, Dict, Optional
from urllib.parse import urljoin

BASE_URL = "https://systems.aamc.org"

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
    })
    return session

def parse_program_row(row, specialty_name: str) -> Optional[Dict]:
    """Parse a single table row into a program dictionary"""
    cells = row.find_all(['td', 'th'])
    
    if len(cells) < 4:  # Need at least: State, City, Program Name, Accreditation ID
        return None
    
    # ERAS table structure (based on the website):
    # Typically: State | City | Program Name | Accreditation ID | Status
    # But the exact order may vary
    
    # Get all cell text
    cell_texts = [cell.get_text(strip=True) for cell in cells]
    
    # Find which column is which by analyzing content
    state = ""
    city = ""
    program_name = ""
    acgme_id = None
    status = ""
    
    # Try to identify columns by content patterns
    for i, text in enumerate(cell_texts):
        text_upper = text.upper()
        
        # State column: 2-letter codes or full state names
        if len(text) == 2 and text.isalpha() and text_upper in ['AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA', 'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD', 'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ', 'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC', 'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY', 'DC', 'PR']:
            if not state:
                state = text.upper()
        
        # City column: Usually contains city names (not all caps, has spaces sometimes)
        elif ',' in text or (len(text) > 3 and not text.isdigit() and not text.startswith('Program')):
            # Check if it looks like a city name
            if not city and not state and i < len(cell_texts) - 2:
                # Might be city,state format
                if ',' in text:
                    parts = text.split(',')
                    city = parts[0].strip()
                    if len(parts) > 1:
                        potential_state = parts[1].strip()[:2]
                        if potential_state.isalpha():
                            state = potential_state.upper()
                else:
                    city = text
        
        # ACGME ID: 10-digit number
        elif re.match(r'^\d{10}$', text):
            acgme_id = text
        
        # Program name: Usually the longest text, contains "Program" or hospital/university names
        elif ('Program' in text or 'Hospital' in text or 'University' in text or 'Medical' in text or 'Center' in text) and len(text) > 10:
            if not program_name:
                program_name = text
        
        # Status: Contains "Participating", "Unregistered", etc.
        elif 'Participating' in text or 'Unregistered' in text or 'Not Participating' in text:
            status = text
    
    # Fallback: Use positional parsing if pattern matching didn't work
    if not state and len(cell_texts) >= 1:
        # First column might be state
        potential_state = cell_texts[0].strip()[:2].upper()
        if potential_state.isalpha() and len(potential_state) == 2:
            state = potential_state
    
    if not city and len(cell_texts) >= 2:
        city = cell_texts[1].strip()
        # Check if it's city,state format
        if ',' in city:
            parts = city.split(',')
            city = parts[0].strip()
            if len(parts) > 1 and not state:
                state = parts[1].strip()[:2].upper()
    
    if not program_name and len(cell_texts) >= 3:
        program_name = cell_texts[2].strip()
    
    # Extract ACGME ID from any cell or from links
    if not acgme_id:
        # Check all cells for 10-digit number
        for text in cell_texts:
            match = re.search(r'(\d{10})', text)
            if match:
                acgme_id = match.group(1)
                break
        
        # Also check links in the row
        if not acgme_id:
            links = row.find_all('a', href=True)
            for link in links:
                href = link.get('href', '')
                match = re.search(r'(\d{10})', href)
                if match:
                    acgme_id = match.group(1)
                    break
    
    # Clean up program name - remove extra text
    if program_name:
        # Remove status indicators from program name
        program_name = re.sub(r'\s*(Participating|Unregistered|Not Participating|New Program!|Osteopathic.*?Recognized!).*$', '', program_name, flags=re.IGNORECASE)
        program_name = program_name.strip()
    
    # Extract hospital name from program name if possible
    hospital = program_name
    if 'Program' in program_name:
        hospital = program_name.replace(' Program', '').strip()
    
    # Determine program type (default to Academic)
    program_type = "Academic"
    if program_name:
        name_lower = program_name.lower()
        if 'community' in name_lower:
            program_type = "Community"
        elif 'hybrid' in name_lower:
            program_type = "Hybrid"
    
    # Validate we have minimum required data
    if not program_name and not hospital:
        return None
    
    if not state:
        return None
    
    # Generate ID if no ACGME ID
    program_id = acgme_id if acgme_id else f"{specialty_name.replace(' ', '_')}_{city}_{state}_{hash(program_name) % 100000}"
    
    return {
        'id': program_id,
        'name': specialty_name,  # Use specialty as name
        'hospital': hospital or program_name,
        'city': city,
        'state': state,
        'specialty': SPECIALTY_NORMALIZATION.get(specialty_name, specialty_name),
        'type': program_type,
        'accreditationID': acgme_id
    }

def extract_programs_from_page(session: requests.Session, specialty_code: str, specialty_name: str) -> List[Dict]:
    """Extract all programs from a specialty page"""
    url = f"{BASE_URL}/eras/erasstats/par/display.cfm?NAV_ROW=PAR&SPEC_CD={specialty_code}"
    
    print(f"  Fetching {specialty_name}...", end=" ", flush=True)
    
    try:
        response = session.get(url, timeout=30)
        response.raise_for_status()
        
        soup = BeautifulSoup(response.content, 'html.parser')
        programs = []
        
        # Find all tables
        tables = soup.find_all('table')
        
        for table in tables:
            rows = table.find_all('tr')
            
            # Skip header rows (usually first 1-2 rows)
            for row in rows[1:]:
                # Skip if it looks like a header row
                row_text = row.get_text().upper()
                if 'STATE' in row_text and 'CITY' in row_text and 'PROGRAM' in row_text:
                    continue
                
                program = parse_program_row(row, specialty_name)
                if program:
                    programs.append(program)
        
        # Remove duplicates based on ACGME ID or hospital+city+state
        seen = set()
        unique_programs = []
        for prog in programs:
            key = prog.get('accreditationID') or f"{prog['hospital']}_{prog['city']}_{prog['state']}"
            if key not in seen:
                seen.add(key)
                unique_programs.append(prog)
        
        print(f"✓ Found {len(unique_programs)} programs")
        return unique_programs
        
    except Exception as e:
        print(f"✗ Error: {e}")
        return []

def scrape_all_specialties(session: requests.Session) -> List[Dict]:
    """Scrape all specialties"""
    all_programs = []
    
    print(f"\nScraping {len(RESIDENCY_SPECIALTIES)} specialties from ERAS 2026...\n")
    
    for specialty_name, specialty_code in RESIDENCY_SPECIALTIES.items():
        programs = extract_programs_from_page(session, specialty_code, specialty_name)
        all_programs.extend(programs)
        time.sleep(1)  # Be respectful
    
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

def main():
    print("=" * 60)
    print("ERAS 2026 Fixed Data Scraper")
    print("=" * 60)
    print("\nThis script properly parses ERAS website tables.\n")
    
    session = get_session()
    
    print("Testing connection...", end=" ", flush=True)
    try:
        response = session.get(f"{BASE_URL}/eras/erasstats/par/index.cfm", timeout=10)
        response.raise_for_status()
        print("✓ Connected\n")
    except Exception as e:
        print(f"✗ Error: {e}")
        return
    
    all_programs = scrape_all_specialties(session)
    
    if not all_programs:
        print("\n⚠️  No programs found. The website structure may have changed.")
        return
    
    save_to_json(all_programs)
    
    print("\n" + "=" * 60)
    print("Next Steps:")
    print("1. Review ERAS2026.json")
    print("2. Import into Matchly app")
    print("=" * 60)

if __name__ == '__main__':
    main()


