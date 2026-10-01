"""
Parse an ACGME ADS program Detail page into a structured dict.

The detail page is label-driven HTML. This parser works off the page's text
lines (label -> following value) for scalar fields, and off the participating
sites <table> for structured rows. Field labels were taken from a live page; if
ACGME changes the markup, update the LABELS below.

Returns a dict with raw ACGME values (dates as printed strings, etc.).
Normalization to Matchly's schema happens in normalize.py.
"""

from __future__ import annotations

import re
from typing import Optional

from bs4 import BeautifulSoup

_MISSING = "No Information Currently Present"


def _lines(soup: BeautifulSoup) -> list[str]:
    text = soup.get_text("\n")
    out = []
    for raw in text.split("\n"):
        s = raw.strip()
        if s:
            out.append(s)
    return out


def _value_after(lines: list[str], label: str, *, start: int = 0) -> Optional[str]:
    """Return the first non-label line after the line equal to `label`."""
    for i in range(start, len(lines)):
        if lines[i].rstrip(":").strip().lower() == label.rstrip(":").strip().lower():
            for j in range(i + 1, len(lines)):
                val = lines[j].strip()
                if val and not val.endswith(":"):
                    return None if val == _MISSING else val
            return None
    return None


def parse_detail(html: str, org_code: str) -> dict:
    soup = BeautifulSoup(html, "lxml")
    lines = _lines(soup)

    # Header: "0200121109 - University of Alabama Hospital (Birmingham) Program"
    program_name = None
    for ln in lines:
        m = re.match(rf"{re.escape(org_code)}\s*-\s*(.+)", ln)
        if m:
            program_name = m.group(1).strip()
            break

    # Website: first external http link that isn't acgme.
    website = None
    for a in soup.find_all("a", href=True):
        href = a["href"].strip()
        if href.startswith("http") and "acgme.org" not in href:
            website = href
            break

    mailing_address, city, state = _parse_mailing_address(soup, lines)

    specialty = _value_after(lines, "Specialty:")
    status = _value_after(lines, "Accreditation Status:")

    # Program-level phone/email = the first Phone:/Email: pair (before director).
    program_phone = _value_after(lines, "Phone:")
    program_email = None
    for a in soup.find_all("a", href=re.compile(r"^mailto:", re.I)):
        program_email = a["href"].split(":", 1)[1]
        break

    # Director block
    director = None
    director_appointed = _value_after(lines, "Director First Appointed:")
    for i, ln in enumerate(lines):
        if ln.lower() == "director information":
            if i + 1 < len(lines):
                director = lines[i + 1]
            break

    # Coordinators (repeating "Coordinator Information" sections)
    coordinators = []
    for i, ln in enumerate(lines):
        if ln.lower() == "coordinator information":
            name = lines[i + 1] if i + 1 < len(lines) else None
            phone = _value_after(lines, "Phone:", start=i)
            email = None
            # mailto nearest after this section
            block = "\n".join(lines[i : i + 8])
            em = re.search(r"[\w.+-]+@[\w.-]+\.\w+", block)
            if em:
                email = em.group(0)
            if name:
                coordinators.append({"name": name, "phone": phone, "email": email})

    sponsoring = _value_after(lines, "Sponsoring Institution:")
    if sponsoring:
        sponsoring = re.sub(r"^\[\s*\d+\s*\]\s*", "", sponsoring).strip()

    approved = _value_after(lines, "Total Approved Resident Positions:")
    filled = _value_after(lines, "Total Filled Resident Positions*:") or _value_after(
        lines, "Total Filled Resident Positions:"
    )

    # Participating sites: the table whose header includes "Site Name".
    sites = []
    for table in soup.find_all("table"):
        head = table.get_text(" ", strip=True).lower()
        if "site name" in head:
            for tr in table.select("tbody tr"):
                cells = [td.get_text(strip=True) for td in tr.find_all("td")]
                if len(cells) >= 3 and cells[2]:
                    sites.append(cells[2])
            break

    return {
        "org_code": org_code,
        "program_name": program_name,
        "specialty": specialty,
        "mailing_address": mailing_address,
        "city": city,
        "state": state,
        "website": website,
        "phone": program_phone,
        "email": program_email,
        "director": director,
        "director_appointed": director_appointed,
        "coordinators": coordinators,
        "sponsoring_institution": sponsoring,
        "accreditation_status": status,
        "original_accreditation_date": _value_after(lines, "Original Accreditation Date:"),
        "effective_date": _value_after(lines, "Effective Date:"),
        "accredited_length_of_training": _value_after(lines, "Accredited Length of Training:"),
        "osteopathic_recognition": _value_after(lines, "Osteopathic Recognition:"),
        "last_site_visit": _value_after(lines, "Last Site Visit Date:"),
        "approved_positions": _to_int(approved),
        "filled_positions": _to_int(filled),
        "participating_sites": sites,
    }


def _to_int(v: Optional[str]) -> Optional[int]:
    if not v:
        return None
    m = re.search(r"\d+", v)
    return int(m.group(0)) if m else None


def _parse_mailing_address(
    soup: BeautifulSoup, lines: list[str]
) -> tuple[Optional[str], Optional[str], Optional[str]]:
    """Extract mailing address block and parse city/state from the last line."""
    addr_el = soup.find("address")
    if addr_el:
        parts = [p.strip() for p in addr_el.get_text("\n", strip=True).split("\n") if p.strip()]
        if parts:
            return _split_address_parts(parts)

    # ADS sometimes labels the block "Address" in plain text.
    for label in soup.find_all(string=re.compile(r"^\s*Address\s*$", re.I)):
        block = label.find_parent(["div", "td", "th", "label", "span"])
        if not block:
            continue
        container = block.find_parent("div") or block.parent
        if not container:
            continue
        addr_el = container.find(class_=re.compile(r"address", re.I))
        if addr_el:
            parts = [p.strip() for p in addr_el.get_text("\n", strip=True).split("\n") if p.strip()]
            if parts:
                return _split_address_parts(parts)

    # Fallback: scan text lines after "Address"
    for i, ln in enumerate(lines):
        if ln.lower() == "address":
            parts = []
            for j in range(i + 1, min(i + 8, len(lines))):
                nxt = lines[j]
                if nxt.endswith(":") or nxt.lower() in {
                    "specialty:",
                    "phone:",
                    "email:",
                    "website:",
                    "director information",
                }:
                    break
                parts.append(nxt)
            if parts:
                return _split_address_parts(parts)
    return None, None, None


def _split_address_parts(parts: list[str]) -> tuple[str, Optional[str], Optional[str]]:
    """Join address lines; parse 'City, ST ZIP' from the final line."""
    city, state = None, None
    street_lines = parts
    last = parts[-1]
    m = re.match(r"^(.+?),\s*([A-Z]{2})\s+(\d{5}(?:-\d{4})?)$", last)
    if m:
        city, state = m.group(1).strip(), m.group(2)
        street_lines = parts[:-1] + [f"{city}, {state} {m.group(3)}"]
    joined = ", ".join(street_lines) if len(street_lines) > 1 else street_lines[0]
    return joined, city, state
