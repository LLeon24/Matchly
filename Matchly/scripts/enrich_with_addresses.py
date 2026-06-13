#!/usr/bin/env python3
"""
Address Enrichment Script for ERAS Programs
Fetches addresses for programs that don't have them using Google Maps Geocoding API

Requirements:
    pip install requests googlemaps

Usage:
    python enrich_with_addresses.py
    
Note: You'll need a Google Maps API key. Set it as an environment variable:
    export GOOGLE_MAPS_API_KEY="your-api-key-here"
    
Or the script will use a free geocoding service as a fallback.
"""

import json
import os
import sys
import time
import requests
from typing import Dict, List, Optional
from urllib.parse import quote

# Try to import googlemaps (optional)
try:
    import googlemaps
    HAS_GOOGLEMAPS = True
except ImportError:
    HAS_GOOGLEMAPS = False
    print("Note: googlemaps not installed. Using free geocoding service.")

def get_address_from_nominatim(hospital: str, city: str, state: str) -> Optional[str]:
    """
    Use OpenStreetMap Nominatim (free) to geocode hospital addresses
    """
    try:
        # Try multiple query variations for better results
        queries = [
            f"{hospital}, {city}, {state}, USA",
            f"{hospital} Hospital, {city}, {state}, USA",
            f"{hospital} Medical Center, {city}, {state}, USA"
        ]
        
        for query in queries:
            url = f"https://nominatim.openstreetmap.org/search?q={quote(query)}&format=json&addressdetails=1&limit=1"
            
            headers = {
                'User-Agent': 'Matchly Address Enrichment Script (contact: matchly@example.com)'
            }
            
            response = requests.get(url, headers=headers, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            if data and len(data) > 0:
                result = data[0]
                address_parts = result.get('address', {})
                
                # Build address string
                house_number = address_parts.get('house_number', '')
                road = address_parts.get('road', '')
                
                if house_number and road:
                    return f"{house_number} {road}"
                elif road:
                    return road
                elif address_parts.get('suburb'):
                    return address_parts.get('suburb')
        
        return None
    except Exception as e:
        print(f"    Error geocoding {hospital}: {e}")
        return None

def get_address_from_google(hospital: str, city: str, state: str, api_key: str) -> Optional[str]:
    """
    Use Google Maps Geocoding API to get hospital address
    """
    if not HAS_GOOGLEMAPS:
        return None
    
    try:
        gmaps = googlemaps.Client(key=api_key)
        
        query = f"{hospital}, {city}, {state}"
        result = gmaps.geocode(query)
        
        if result and len(result) > 0:
            address_components = result[0].get('address_components', [])
            formatted_address = result[0].get('formatted_address', '')
            
            # Extract street address from components
            street_number = ''
            route = ''
            
            for component in address_components:
                types = component.get('types', [])
                if 'street_number' in types:
                    street_number = component.get('long_name', '')
                elif 'route' in types:
                    route = component.get('long_name', '')
            
            if street_number and route:
                return f"{street_number} {route}"
            elif route:
                return route
            elif formatted_address:
                # Fallback to formatted address, but extract just the street part
                parts = formatted_address.split(',')
                if len(parts) > 0:
                    return parts[0].strip()
        
        return None
    except Exception as e:
        print(f"    Error with Google geocoding {hospital}: {e}")
        return None

def enrich_program_address(program: Dict) -> Dict:
    """
    Enrich a single program with address if missing
    Handles null values and tries multiple strategies
    """
    # Skip if address already exists and is not null/empty
    existing_address = program.get('address')
    if existing_address and existing_address.lower() not in ['null', 'none', '']:
        return program
    
    hospital = program.get('hospital', '') or program.get('name', '')
    city = program.get('city', '')
    state = program.get('state', '')
    
    if not hospital or not city or not state:
        print(f"  ⚠ Skipping: Missing hospital, city, or state")
        return program
    
    # Clean hospital name
    hospital = hospital.strip()
    if not hospital:
        print(f"  ⚠ Skipping: Empty hospital name")
        return program
    
    print(f"  Fetching address for: {hospital}, {city}, {state}")
    
    # Try Google Maps API first if available
    google_api_key = os.environ.get('GOOGLE_MAPS_API_KEY')
    address = None
    
    if google_api_key and HAS_GOOGLEMAPS:
        address = get_address_from_google(hospital, city, state, google_api_key)
        time.sleep(0.1)  # Rate limiting
    
    # Fallback to Nominatim (free, but slower)
    if not address:
        address = get_address_from_nominatim(hospital, city, state)
        time.sleep(1)  # Nominatim requires 1 second between requests
    
    if address and address.lower() not in ['null', 'none', '']:
        program['address'] = address
        print(f"    ✓ Found: {address}")
    else:
        # Try alternative hospital name variations
        hospital_variations = [
            f"{hospital} Hospital",
            f"{hospital} Medical Center",
            f"{hospital} Health System",
            f"{hospital} Medical",
        ]
        
        for variation in hospital_variations:
            if address:
                break
                
            if google_api_key and HAS_GOOGLEMAPS:
                address = get_address_from_google(variation, city, state, google_api_key)
                time.sleep(0.1)
            
            if not address:
                address = get_address_from_nominatim(variation, city, state)
                time.sleep(1)
            
            if address and address.lower() not in ['null', 'none', '']:
                program['address'] = address
                print(f"    ✓ Found (variation): {address}")
                break
        
        if not address or address.lower() in ['null', 'none', '']:
            print(f"    ✗ Could not find address")
            # Don't set null - leave it missing so we can try again later
    
    return program

def enrich_eras_data(input_file: str, output_file: Optional[str] = None):
    """
    Enrich ERAS JSON data with addresses for all programs
    """
    if output_file is None:
        output_file = input_file.replace('.json', '_with_addresses.json')
    
    print(f"Loading programs from {input_file}...")
    with open(input_file, 'r', encoding='utf-8') as f:
        programs = json.load(f)
    
    print(f"Found {len(programs)} programs")
    
    # Count programs without addresses (excluding null/empty strings)
    programs_without_address = [
        p for p in programs 
        if not p.get('address') or p.get('address', '').lower() in ['null', 'none', '']
    ]
    print(f"Programs without valid addresses: {len(programs_without_address)}")
    
    if len(programs_without_address) == 0:
        print("All programs already have addresses!")
        return
    
    print(f"\nEnriching {len(programs_without_address)} programs with addresses...")
    print("This may take a while due to rate limiting...\n")
    
    enriched_count = 0
    for i, program in enumerate(programs_without_address, 1):
        print(f"[{i}/{len(programs_without_address)}] ", end="")
        original_address = program.get('address')
        enriched_program = enrich_program_address(program)
        
        if enriched_program.get('address') and not original_address:
            enriched_count += 1
        
        # Update in main programs list
        program_id = program.get('id')
        for p in programs:
            if p.get('id') == program_id:
                p['address'] = enriched_program.get('address')
                break
        
        # Save progress every 10 programs
        if i % 10 == 0:
            print(f"\n  Saving progress... ({i}/{len(programs_without_address)})")
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(programs, f, indent=2, ensure_ascii=False)
    
    # Final save
    print(f"\nSaving enriched data to {output_file}...")
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(programs, f, indent=2, ensure_ascii=False)
    
    print(f"\n✓ Enrichment complete!")
    print(f"  Added addresses to {enriched_count} programs")
    print(f"  Output saved to: {output_file}")
    print(f"\nTo use the enriched data, replace ERAS2026.json with {output_file}")

def main():
    # Default paths - try multiple locations
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Try different possible paths
    possible_paths = [
        os.path.join(script_dir, "..", "Matchly", "Data", "ERAS2026.json"),
        os.path.join(script_dir, "..", "..", "Matchly", "Data", "ERAS2026.json"),
        os.path.join(script_dir, "..", "Data", "ERAS2026.json"),
        "Matchly/Data/ERAS2026.json",
        "../Matchly/Data/ERAS2026.json",
        os.path.join(os.path.expanduser("~"), "Library", "Mobile Documents", "com~apple~CloudDocs", "Leoh", "Business", "Matchly", "Matchly", "Matchly", "Data", "ERAS2026.json")
    ]
    
    eras_file = None
    for path in possible_paths:
        abs_path = os.path.abspath(path)
        if os.path.exists(abs_path):
            eras_file = abs_path
            print(f"Found ERAS file at: {eras_file}")
            break
    
    if not eras_file:
        print("Error: ERAS data file not found")
        print("\nSearched in:")
        for path in possible_paths:
            abs_path = os.path.abspath(path)
            exists = "✓" if os.path.exists(abs_path) else "✗"
            print(f"  {exists} {abs_path}")
        print("\nPlease provide the full path to ERAS2026.json:")
        user_path = input("Path: ").strip().strip('"').strip("'")
        if user_path and os.path.exists(user_path):
            eras_file = os.path.abspath(user_path)
        else:
            print("Invalid path. Exiting.")
            sys.exit(1)
    
    print("=" * 60)
    print("ERAS Address Enrichment Script")
    print("=" * 60)
    print()
    
    if not HAS_GOOGLEMAPS:
        print("Note: Using free OpenStreetMap Nominatim service.")
        print("      For faster results, install googlemaps and set GOOGLE_MAPS_API_KEY")
        print("      pip install googlemaps")
        print()
    
    enrich_eras_data(eras_file)

if __name__ == "__main__":
    main()

