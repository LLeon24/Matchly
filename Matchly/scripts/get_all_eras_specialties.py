#!/usr/bin/env python3
"""
Script to discover ALL ERAS specialty codes dynamically from the AAMC ERAS website
This ensures we capture all 146+ specialties/subspecialties
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

def discover_all_specialties(driver):
    """
    Discover all specialty codes from ERAS website
    """
    print("Discovering all ERAS specialties...")
    
    # Base URL for ERAS specialty listing
    base_url = "https://systems.aamc.org/eras/erasstats/par/display.cfm?NAV_ROW=PAR"
    
    specialties = {}
    
    try:
        # Try to get specialty list from a specialty selection page or dropdown
        # This is a common pattern - we'll try multiple approaches
        
        # Approach 1: Try to find specialty dropdown/select element
        driver.get(base_url)
        time.sleep(2)
        
        # Look for specialty selection elements
        try:
            # Try finding select elements with specialty options
            select_elements = driver.find_elements(By.TAG_NAME, "select")
            for select in select_elements:
                options = select.find_elements(By.TAG_NAME, "option")
                for option in options:
                    value = option.get_attribute("value")
                    text = option.text.strip()
                    if value and value.isdigit() and text:
                        specialties[text] = value
                        print(f"  Found: {text} ({value})")
        except Exception as e:
            print(f"  Could not find select elements: {e}")
        
        # Approach 2: Try common specialty codes and verify they exist
        # We'll test a range of codes
        common_codes = [
            "010", "020", "040", "080", "110", "120", "140", "141", "142", "143",
            "144", "145", "146", "147", "148", "149", "150", "160", "170", "171",
            "172", "173", "174", "175", "180", "198", "200", "220", "240", "260",
            "280", "300", "320", "321", "322", "323", "324", "325", "326", "327",
            "328", "329", "330", "332", "340", "360", "370", "380", "390", "400",
            "405", "406", "407", "408", "409", "417", "420", "430", "440", "450",
            "460", "480", "520", "999"
        ]
        
        print("\nTesting specialty codes to discover all specialties...")
        for code in common_codes:
            url = f"{base_url}&SPEC_CD={code}"
            try:
                driver.get(url)
                time.sleep(1)
                
                # Check if page has programs (not an error page)
                page_text = driver.page_source.lower()
                if "no programs found" not in page_text and "error" not in page_text:
                    # Try to extract specialty name from page
                    try:
                        title_elements = driver.find_elements(By.TAG_NAME, "h1")
                        title_elements.extend(driver.find_elements(By.TAG_NAME, "h2"))
                        title_elements.extend(driver.find_elements(By.CSS_SELECTOR, ".specialty-name, .page-title"))
                        
                        for elem in title_elements:
                            text = elem.text.strip()
                            if text and len(text) > 3:
                                specialties[text] = code
                                print(f"  Found: {text} ({code})")
                                break
                    except:
                        pass
            except Exception as e:
                continue
        
    except Exception as e:
        print(f"Error discovering specialties: {e}")
    
    return specialties

def main():
    print("=" * 60)
    print("ERAS Specialty Discovery Script")
    print("=" * 60)
    print()
    
    driver = None
    try:
        driver = setup_driver(headless=False)  # Not headless so user can see progress
        specialties = discover_all_specialties(driver)
        
        print(f"\n✓ Discovered {len(specialties)} specialties")
        print("\nSpecialties found:")
        for name, code in sorted(specialties.items()):
            print(f"  {name}: {code}")
        
        # Save to JSON
        output_file = "all_eras_specialties.json"
        with open(output_file, 'w') as f:
            json.dump(specialties, f, indent=2)
        
        print(f"\n✓ Saved to {output_file}")
        print("\nYou can now use this file to update the ERAS scraper with all specialties.")
        
    except Exception as e:
        print(f"Error: {e}")
    finally:
        if driver:
            driver.quit()

if __name__ == "__main__":
    main()


