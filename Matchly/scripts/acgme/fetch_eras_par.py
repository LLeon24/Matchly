#!/usr/bin/env python3
"""Fetch authoritative program names from the AAMC ERAS PAR website."""

from __future__ import annotations

import argparse
import json
import re
import time
from pathlib import Path
from typing import Optional
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup

BASE_URL = "https://systems.aamc.org"
INDEX_URL = f"{BASE_URL}/eras/erasstats/par/index.cfm"
DISPLAY_URL = f"{BASE_URL}/eras/erasstats/par/display.cfm"

ERAS_JUNK_RE = re.compile(
    r"(Osteopathic\s*Recognized!?|New\s*Program!?|Program\s*Signals?)",
    re.I,
)
STATUS_SUFFIX_RE = re.compile(
    r"\s*(Participating|Unregistered|Not Participating|No Longer Accepting Applications).*$",
    re.I,
)
ACCREDITATION_RE = re.compile(r"^\d{10}$")

US_STATES = {
    "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "HI", "ID", "IL", "IN",
    "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV",
    "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN",
    "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY", "DC", "PR", "VI", "GU",
}


def get_session() -> requests.Session:
    session = requests.Session()
    session.headers.update(
        {
            "User-Agent": (
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            ),
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        }
    )
    return session


def clean_program_name(raw: str) -> str:
    name = ERAS_JUNK_RE.sub("", raw or "")
    name = STATUS_SUFFIX_RE.sub("", name)
    return re.sub(r"\s+", " ", name).strip()


def hospital_from_program_name(program_name: str) -> str:
    name = clean_program_name(program_name)
    if name.lower().endswith(" program"):
        name = name[:-8].strip()
    return name


def infer_program_type(program_name: str) -> str:
    lower = program_name.lower()
    if "community" in lower:
        return "Community"
    if "hybrid" in lower:
        return "Hybrid"
    return "Academic"


def discover_specialties(session: requests.Session) -> dict[str, str]:
    response = session.get(INDEX_URL, timeout=30)
    response.raise_for_status()
    soup = BeautifulSoup(response.content, "html.parser")
    specialties: dict[str, str] = {}
    for link in soup.find_all("a", href=True):
        href = link.get("href", "")
        text = link.get_text(strip=True)
        match = re.search(r"SPEC_CD=([^&]+)", href)
        if not match or not text or len(text) < 3:
            continue
        code = match.group(1)
        if not code.isdigit():
            continue
        if text in {"Specialty Information Available!", "New Specialties"}:
            continue
        specialties[text] = code
    return specialties


def parse_program_row(row, specialty_name: str) -> Optional[dict]:
    cells = row.find_all(["td", "th"])
    if len(cells) < 5:
        return None

    texts = [cell.get_text(" ", strip=True) for cell in cells]
    acgme_id = None
    program_name = ""
    state = ""
    city = ""
    status = ""

    if len(texts) >= 6 and ACCREDITATION_RE.match(texts[4]):
        state, city, program_name, acgme_id, status = (
            texts[0],
            texts[1],
            texts[3],
            texts[4],
            texts[5],
        )
    else:
        for text in texts:
            if ACCREDITATION_RE.match(text):
                acgme_id = text
        for text in texts:
            upper = text.upper()
            if len(text) == 2 and upper in US_STATES and not state:
                state = upper
        for text in texts:
            if "Participating" in text or "Unregistered" in text:
                status = text
        for text in texts:
            if len(text) > 12 and not ACCREDITATION_RE.match(text) and text.upper() not in US_STATES:
                if "Program" in text or "Hospital" in text or "University" in text:
                    program_name = text
                    break

    if not acgme_id or not program_name or not state:
        return None

    program_name = clean_program_name(program_name)
    hospital = hospital_from_program_name(program_name)

    website_url = None
    for cell in cells:
        for link in cell.find_all("a", href=True):
            href = link.get("href", "")
            if "display.cfm" in href or href.startswith("http"):
                website_url = urljoin(BASE_URL, href)
                break
        if website_url:
            break

    return {
        "id": acgme_id,
        "name": specialty_name,
        "hospital": hospital,
        "city": city,
        "state": state,
        "specialty": specialty_name,
        "type": infer_program_type(program_name),
        "accreditationID": acgme_id,
        "erasStatus": status.strip() if status else None,
        "websiteURL": website_url,
    }


def fetch_specialty_programs(
    session: requests.Session, specialty_name: str, specialty_code: str
) -> list[dict]:
    url = f"{DISPLAY_URL}?NAV_ROW=PAR&SPEC_CD={specialty_code}"
    response = session.get(url, timeout=45)
    response.raise_for_status()
    soup = BeautifulSoup(response.content, "html.parser")

    programs: list[dict] = []
    seen: set[str] = set()
    for table in soup.find_all("table"):
        for row in table.find_all("tr"):
            row_text = row.get_text(" ", strip=True).upper()
            if "STATE" in row_text and "CITY" in row_text and "PROGRAM NAME" in row_text:
                continue
            program = parse_program_row(row, specialty_name)
            if not program:
                continue
            key = program["accreditationID"]
            if key in seen:
                continue
            seen.add(key)
            programs.append(program)
    return programs


def fetch_all(
    session: requests.Session,
    specialty_filter: Optional[list[str]] = None,
    delay_seconds: float = 0.75,
) -> list[dict]:
    specialties = discover_specialties(session)
    if specialty_filter:
        specialties = {k: v for k, v in specialties.items() if k in specialty_filter or v in specialty_filter}

    all_programs: list[dict] = []
    for name, code in sorted(specialties.items(), key=lambda item: item[1]):
        print(f"  {name} ({code})...", end=" ", flush=True)
        try:
            programs = fetch_specialty_programs(session, name, code)
            print(f"{len(programs)} programs")
            all_programs.extend(programs)
        except Exception as exc:
            print(f"error: {exc}")
        time.sleep(delay_seconds)
    return all_programs


def main() -> int:
    repo_data = Path(__file__).resolve().parents[2] / "Data"
    parser = argparse.ArgumentParser(description="Fetch ERAS PAR program list into JSON")
    parser.add_argument(
        "--output",
        type=Path,
        default=repo_data / "ERAS2026.json",
        help="Output JSON path",
    )
    parser.add_argument(
        "--specialty",
        action="append",
        dest="specialties",
        help="Only fetch these specialty names or SPEC_CD values (repeatable)",
    )
    parser.add_argument("--delay", type=float, default=0.75, help="Delay between requests (seconds)")
    args = parser.parse_args()

    session = get_session()
    print("Connecting to ERAS PAR...")
    session.get(INDEX_URL, timeout=15).raise_for_status()
    print("Fetching programs...")
    programs = fetch_all(session, args.specialties, args.delay)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(programs, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\nSaved {len(programs)} programs → {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
