#!/usr/bin/env python3
"""
ERAS 2026 Data Extractor
Helps convert ERAS program data to JSON format for Matchly app

Usage:
1. Export data from ERAS website (copy/paste or save as CSV)
2. Run this script to convert to JSON format
3. Import the JSON file into the Matchly app
"""

import json
import csv
import sys
from typing import List, Dict, Optional

def parse_eras_csv(csv_file: str) -> List[Dict]:
    """
    Parse ERAS CSV export and convert to Matchly format
    Expected CSV columns: Program Name, Hospital, City, State, Specialty, Type, ACGME ID
    """
    programs = []
    
    try:
        with open(csv_file, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            
            for row_num, row in enumerate(reader, start=2):
                # Map common CSV column names to our format
                program_name = row.get('Program Name', row.get('Name', row.get('Program', ''))).strip()
                hospital = row.get('Hospital', row.get('Institution', row.get('Hospital Name', ''))).strip()
                city = row.get('City', '').strip()
                state = row.get('State', '').strip()
                specialty = row.get('Specialty', row.get('Specialty Name', '')).strip()
                program_type = row.get('Type', row.get('Program Type', 'Academic')).strip()
                acgme_id = row.get('ACGME ID', row.get('Accreditation ID', row.get('Program Code', ''))).strip()
                
                # Generate ID if not provided
                program_id = acgme_id if acgme_id else f"{specialty}_{row_num}"
                
                # Normalize specialty names to match app
                specialty_map = {
                    'Internal Medicine': 'Internal Medicine',
                    'Family Medicine': 'Family Medicine',
                    'Emergency Medicine': 'Emergency Medicine',
                    'Pediatrics': 'Pediatrics',
                    'General Surgery': 'General Surgery',
                    'Obstetrics and Gynecology': 'OB/GYN',
                    'OB/GYN': 'OB/GYN',
                    'Psychiatry': 'Psychiatry',
                    'Neurology': 'Neurology',
                    'Anesthesiology': 'Anesthesiology',
                    'Diagnostic Radiology': 'Radiology',
                    'Radiology': 'Radiology',
                    'Pathology': 'Pathology',
                    'Orthopaedic Surgery': 'Orthopedics',
                    'Orthopedics': 'Orthopedics',
                    'Otolaryngology': 'ENT',
                    'ENT': 'ENT',
                    'Urology': 'Urology',
                    'Physical Medicine and Rehabilitation': 'PM&R',
                    'PM&R': 'PM&R',
                    'Dermatology': 'Dermatology',
                    'Neurological Surgery': 'Neurosurgery',
                    'Neurosurgery': 'Neurosurgery',
                }
                
                normalized_specialty = specialty_map.get(specialty, specialty)
                
                # Normalize program type
                type_map = {
                    'Academic': 'Academic',
                    'Community': 'Community',
                    'Hybrid': 'Hybrid',
                    'University': 'Academic',
                    'Teaching': 'Academic',
                }
                normalized_type = type_map.get(program_type, 'Academic')
                
                if program_name or hospital:
                    programs.append({
                        'id': program_id,
                        'name': program_name or normalized_specialty,
                        'hospital': hospital or program_name,
                        'city': city,
                        'state': state,
                        'specialty': normalized_specialty,
                        'type': normalized_type,
                        'accreditationID': acgme_id if acgme_id else None
                    })
    
    except Exception as e:
        print(f"Error reading CSV file: {e}")
        return []
    
    return programs

def create_template_csv(output_file: str = 'eras_template.csv'):
    """Create a CSV template for manual data entry"""
    headers = ['Program Name', 'Hospital', 'City', 'State', 'Specialty', 'Type', 'ACGME ID']
    
    with open(output_file, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        # Add example row
        writer.writerow([
            'Internal Medicine',
            'Johns Hopkins Hospital',
            'Baltimore',
            'MD',
            'Internal Medicine',
            'Academic',
            '1403821100'
        ])
    
    print(f"Template created: {output_file}")
    print("Fill in the data and run this script again with the CSV file")

def convert_to_json(csv_file: str, output_file: str = 'ERAS2026.json'):
    """Convert CSV to JSON format"""
    programs = parse_eras_csv(csv_file)
    
    if not programs:
        print("No programs found in CSV file")
        return
    
    # Remove None values from accreditationID
    for program in programs:
        if program.get('accreditationID') is None:
            program.pop('accreditationID', None)
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(programs, f, indent=2, ensure_ascii=False)
    
    print(f"✓ Converted {len(programs)} programs to {output_file}")
    print(f"✓ File is ready to import into Matchly app")

def main():
    if len(sys.argv) < 2:
        print("ERAS 2026 Data Converter for Matchly")
        print("\nUsage:")
        print("  python eras_data_extractor.py <input.csv> [output.json]")
        print("  python eras_data_extractor.py --template")
        print("\nExample:")
        print("  python eras_data_extractor.py eras_export.csv ERAS2026.json")
        print("\nTo create a template CSV:")
        print("  python eras_data_extractor.py --template")
        sys.exit(1)
    
    if sys.argv[1] == '--template':
        create_template_csv()
        return
    
    csv_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else 'ERAS2026.json'
    
    convert_to_json(csv_file, output_file)

if __name__ == '__main__':
    main()


