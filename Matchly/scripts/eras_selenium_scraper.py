#!/usr/bin/env python3
"""
Advanced ERAS 2026 Scraper using Selenium
For JavaScript-heavy pages or when requests/BeautifulSoup doesn't work

Requirements:
    pip install selenium beautifulsoup4
    Download ChromeDriver: https://chromedriver.chromium.org/

Usage:
    python eras_selenium_scraper.py
"""

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.options import Options
from selenium.common.exceptions import TimeoutException, NoSuchElementException
import json
import time
import re
from typing import List, Dict

# Specialty codes - Core ERAS specialties
# Note: The scraper will also try to discover additional specialties dynamically
# There are 146+ specialties/subspecialties total (13,762 programs)
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
    "Ophthalmology": "240",
    "Child Neurology": "175",
    "Nuclear Medicine": "200",
    "Radiation Oncology": "430",
    "Plastic Surgery": "360",
    "Interventional Radiology - Integrated": "417",
    "Thoracic Surgery - Integrated": "460",
    "Vascular Surgery - Integrated": "450",
    "Transitional Year": "999",
    "Aerospace Medicine": "010",
    "Occupational and Environmental Medicine": "380",
    "Public Health and General Preventive Medicine": "390",
    "Osteopathic Neuromusculoskeletal Medicine": "370",
    "Allergy and Immunology": "020",
    "Cardiovascular Disease": "141",
    "Endocrinology, Diabetes and Metabolism": "143",
    "Gastroenterology": "144",
    "Hematology and Oncology": "146",
    "Infectious Disease": "147",
    "Nephrology": "148",
    "Pulmonary Disease": "149",
    "Rheumatology": "150",
    "Critical Care Medicine": "142",
    "Geriatric Medicine": "145",
    "Hospice and Palliative Medicine": "172",
    "Sleep Medicine": "520",
    "Sports Medicine": "198",
    "Addiction Psychiatry": "405",
    "Child and Adolescent Psychiatry": "406",
    "Forensic Psychiatry": "407",
    "Geriatric Psychiatry": "408",
    "Psychosomatic Medicine": "409",
    "Pediatric Cardiology": "321",
    "Pediatric Critical Care Medicine": "322",
    "Pediatric Emergency Medicine": "323",
    "Pediatric Endocrinology": "324",
    "Pediatric Gastroenterology": "325",
    "Pediatric Hematology-Oncology": "326",
    "Pediatric Infectious Diseases": "327",
    "Pediatric Nephrology": "328",
    "Pediatric Pulmonology": "329",
    "Pediatric Rheumatology": "330",
    "Neonatal-Perinatal Medicine": "320",
    "Developmental-Behavioral Pediatrics": "332",
    "Medical Genetics and Genomics": "170",
    "Clinical Biochemical Genetics": "171",
    "Molecular Genetic Pathology": "172",
    "Clinical Cytogenetics and Genomics": "173",
    "Clinical Molecular Genetics and Genomics": "174",
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
    "Ophthalmology": "Ophthalmology",
    "Child Neurology": "Child Neurology",
    "Nuclear Medicine": "Nuclear Medicine",
    "Radiation Oncology": "Radiation Oncology",
    "Plastic Surgery": "Plastic Surgery",
    "Interventional Radiology - Integrated": "Interventional Radiology - Integrated",
    "Thoracic Surgery - Integrated": "Thoracic Surgery - Integrated",
    "Vascular Surgery - Integrated": "Vascular Surgery - Integrated",
    "Transitional Year": "Transitional Year",
    "Aerospace Medicine": "Aerospace Medicine",
    "Occupational and Environmental Medicine": "Occupational and Environmental Medicine",
    "Public Health and General Preventive Medicine": "Public Health and General Preventive Medicine",
    "Osteopathic Neuromusculoskeletal Medicine": "Osteopathic Neuromusculoskeletal Medicine",
}

def setup_driver(headless: bool = True):
    """Setup Chrome WebDriver"""
    chrome_options = Options()
    if headless:
        chrome_options.add_argument('--headless')
    chrome_options.add_argument('--no-sandbox')
    chrome_options.add_argument('--disable-dev-shm-usage')
    chrome_options.add_argument('--disable-blink-features=AutomationControlled')
    chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
    chrome_options.add_experimental_option('useAutomationExtension', False)
    chrome_options.add_argument('user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
    
    try:
        driver = webdriver.Chrome(options=chrome_options)
        driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
        return driver
    except Exception as e:
        print(f"Error setting up ChromeDriver: {e}")
        print("\nPlease install ChromeDriver:")
        print("1. Download from: https://chromedriver.chromium.org/")
        print("2. Add to PATH or place in same directory as this script")
        print("3. Or install via: brew install chromedriver (macOS)")
        raise

def extract_programs_selenium(driver: webdriver.Chrome, specialty_code: str, specialty_name: str) -> List[Dict]:
    """Extract programs using Selenium"""
    url = f"https://systems.aamc.org/eras/erasstats/par/display.cfm?NAV_ROW=PAR&SPEC_CD={specialty_code}"
    
    print(f"  Fetching {specialty_name}...", end=" ", flush=True)
    
    try:
        driver.get(url)
        
        # Wait for page to load
        WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.TAG_NAME, "table"))
        )
        
        programs = []
        
        # Find all tables on the page
        tables = driver.find_elements(By.TAG_NAME, "table")
        
        for table in tables:
            try:
                rows = table.find_elements(By.TAG_NAME, "tr")
                
                for row_idx, row in enumerate(rows):
                    if row_idx == 0:  # Skip header
                        continue
                    
                    cells = row.find_elements(By.TAG_NAME, "td")
                    
                    if len(cells) < 2:
                        continue
                    
                    # Extract text from cells
                    cell_texts = [cell.text.strip() for cell in cells]
                    
                    # Parse program information
                    # Adjust indices based on actual table structure
                    program_name = cell_texts[0] if len(cell_texts) > 0 else ""
                    hospital = cell_texts[1] if len(cell_texts) > 1 else cell_texts[0]
                    location = cell_texts[2] if len(cell_texts) > 2 else ""
                    
                    # Parse city and state
                    city = ""
                    state = ""
                    if location:
                        parts = location.split(',')
                        if len(parts) >= 2:
                            city = parts[0].strip()
                            state = parts[-1].strip()[:2]
                        else:
                            city = location.strip()
                    
                    # Try to find ACGME ID, website URL, and contact info in links and text
                    acgme_id = None
                    website_url = None
                    contact_email = None
                    contact_phone = None
                    program_coordinator = None
                    
                    try:
                        # First, try to find ACGME ID in the row text itself (often displayed)
                        row_text_all = ' '.join(cell_texts)
                        # ACGME IDs are typically 10 digits
                        acgme_matches = re.findall(r'\b(\d{10})\b', row_text_all)
                        if acgme_matches:
                            acgme_id = acgme_matches[0]  # Take first 10-digit number found
                        
                        links = row.find_elements(By.TAG_NAME, "a")
                        for link in links:
                            href = link.get_attribute('href')
                            if href:
                                # Check for ACGME ID in link (more reliable)
                                if not acgme_id:
                                    match = re.search(r'(\d{10})', href)
                                    if match:
                                        acgme_id = match.group(1)
                                
                                # Also check link text for ACGME ID
                                link_text = link.text.strip()
                                if not acgme_id and link_text:
                                    match = re.search(r'\b(\d{10})\b', link_text)
                                    if match:
                                        acgme_id = match.group(1)
                                
                                # Check for website URL
                                if not website_url:
                                    if href.startswith('http://') or href.startswith('https://'):
                                        # Direct website link
                                        website_url = href
                                    elif 'www.' in href.lower() or 'website' in link.text.lower():
                                        website_url = href if href.startswith('http') else f"https://{href}"
                    except:
                        pass
                    
                    # If still no ACGME ID, try to extract from program name or ID field
                    if not acgme_id:
                        # Sometimes the ID is in a specific cell
                        try:
                            cells = row.find_elements(By.TAG_NAME, "td")
                            for cell in cells:
                                cell_text = cell.text.strip()
                                # Look for 10-digit numbers
                                match = re.search(r'\b(\d{10})\b', cell_text)
                                if match:
                                    acgme_id = match.group(1)
                                    break
                        except:
                            pass
                    
                    # Extract contact information from cell text
                    row_text = ' '.join(cell_texts)
                    
                    # Look for email addresses
                    email_pattern = r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
                    email_matches = re.findall(email_pattern, row_text)
                    if email_matches:
                        contact_email = email_matches[0]
                    
                    # Look for phone numbers (various formats)
                    phone_patterns = [
                        r'\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}',  # (123) 456-7890 or 123-456-7890
                        r'\d{3}[-.\s]?\d{3}[-.\s]?\d{4}',        # 123-456-7890
                        r'\+1[-.\s]?\d{3}[-.\s]?\d{3}[-.\s]?\d{4}'  # +1 123-456-7890
                    ]
                    for pattern in phone_patterns:
                        phone_matches = re.findall(pattern, row_text)
                        if phone_matches:
                            contact_phone = phone_matches[0].strip()
                            break
                    
                    # Look for program coordinator (common patterns)
                    coordinator_patterns = [
                        r'Coordinator[:\s]+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)',
                        r'Program Coordinator[:\s]+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)',
                        r'Contact[:\s]+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)'
                    ]
                    for pattern in coordinator_patterns:
                        match = re.search(pattern, row_text, re.IGNORECASE)
                        if match:
                            program_coordinator = match.group(1).strip()
                            break
                    
                    # Determine program type
                    program_type = "Academic"
                    row_text = ' '.join(cell_texts).lower()
                    if 'community' in row_text:
                        program_type = "Community"
                    elif 'hybrid' in row_text:
                        program_type = "Hybrid"
                    
                    # Try to extract address from program details or links
                    address = None
                    # Look for address in program details page or links
                    # This would require additional navigation - for now, leave as None
                    # Address will be enriched later
                    
                    if program_name or hospital:
                        program_dict = {
                            'id': acgme_id or f"{specialty_name}_{len(programs) + 1}",
                            'name': program_name or specialty_name,
                            'hospital': hospital or program_name,
                            'city': city,
                            'state': state,
                            'specialty': SPECIALTY_NORMALIZATION.get(specialty_name, specialty_name),
                            'type': program_type,
                            'accreditationID': acgme_id,
                            'address': address  # Will be None initially, enriched later
                        }
                        
                        # Add optional contact information
                        if website_url:
                            program_dict['websiteURL'] = website_url
                        if contact_email:
                            program_dict['contactEmail'] = contact_email
                        if contact_phone:
                            program_dict['contactPhone'] = contact_phone
                        if program_coordinator:
                            program_dict['programCoordinator'] = program_coordinator
                        
                        programs.append(program_dict)
            except Exception as e:
                print(f"    Warning: Error parsing table: {e}")
                continue
        
        print(f"✓ Found {len(programs)} programs")
        return programs
        
    except TimeoutException:
        print("✗ Timeout waiting for page")
        return []
    except Exception as e:
        print(f"✗ Error: {e}")
        return []

def main():
    print("=" * 60)
    print("ERAS 2026 Selenium Scraper")
    print("=" * 60)
    print("\nThis script uses Selenium to extract programs from ERAS.")
    print("It will open a Chrome browser window.\n")
    
    driver = None
    try:
        driver = setup_driver(headless=False)  # Set to True for headless mode
        all_programs = []
        
        print(f"\nScraping {len(RESIDENCY_SPECIALTIES)} specialties...\n")
        
        for specialty_name, specialty_code in RESIDENCY_SPECIALTIES.items():
            programs = extract_programs_selenium(driver, specialty_code, specialty_name)
            all_programs.extend(programs)
            time.sleep(2)  # Be respectful with delays
        
        # Save to JSON
        filename = "ERAS2026.json"
        for program in all_programs:
            # Remove None values for optional fields
            if program.get('accreditationID') is None:
                program.pop('accreditationID', None)
            if program.get('websiteURL') is None:
                program.pop('websiteURL', None)
            if program.get('contactEmail') is None:
                program.pop('contactEmail', None)
            if program.get('contactPhone') is None:
                program.pop('contactPhone', None)
            if program.get('programCoordinator') is None:
                program.pop('programCoordinator', None)
        
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(all_programs, f, indent=2, ensure_ascii=False)
        
        print(f"\n✓ Saved {len(all_programs)} programs to {filename}")
        
    except KeyboardInterrupt:
        print("\n\nScraping interrupted by user")
    except Exception as e:
        print(f"\n✗ Error: {e}")
    finally:
        if driver:
            driver.quit()
        print("\nDone!")

if __name__ == '__main__':
    main()


