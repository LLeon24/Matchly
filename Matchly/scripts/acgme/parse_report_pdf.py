"""
Parse ACGME ADS Report #1 PDFs ("List of Programs by Specialty").

Each PDF row includes (in one block per program):
  [10-digit code], program name, address, phone, email (optional),
  program director, accreditation status, effective date.

PDF text layout varies; this parser uses regex anchors rather than fixed columns.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Optional

import pdfplumber

CODE_SPLIT_RE = re.compile(r"(?=\[\d{10}\])")
CODE_LINE_RE = re.compile(r"^\[(\d{10})\]\s*(.*)$")
DATE_RE = re.compile(r"\b(\d{2}/\d{2}/\d{4})\b")
PHONE_RE = re.compile(r"Ph:\s*(.+)", re.I)
EMAIL_RE = re.compile(r"[\w.+-]+@[\w.-]+\.\w+")
CITY_STATE_ZIP_RE = re.compile(r"^(.+),\s*([A-Z]{2})\s+(\d{5}(?:-\d{4})?)$")

STATUS_PATTERNS = [
    ("Continued Accreditation", "Continued Accreditation"),
    ("Initial Accreditation", "Initial Accreditation"),
    ("Pre-Accreditation", "Pre-Accreditation"),
    ("Probation", "Probation"),
    ("Withdrawn", "Withdrawn"),
]

# Remove per-page footers only (do not use DOTALL — it would strip the whole file).
FOOTER_LINE_RE = re.compile(
    r"^©\s*\d{4} Accreditation Council.*$|^Page \d+ of \d+\s*$",
    re.I | re.M,
)


def extract_pdf_text(path: Path) -> str:
    parts: list[str] = []
    with pdfplumber.open(path) as pdf:
        for page in pdf.pages:
            text = page.extract_text() or ""
            parts.append(text)
    joined = "\n".join(parts)
    return FOOTER_LINE_RE.sub("", joined)


def _parse_block(block: str, specialty_hint: Optional[str] = None) -> Optional[dict]:
    lines = [ln.strip() for ln in block.strip().split("\n") if ln.strip()]
    if not lines:
        return None

    m = CODE_LINE_RE.match(lines[0])
    if not m:
        return None

    org_code = m.group(1)
    first_line = m.group(2)

    effective_date = None
    dates = DATE_RE.findall(first_line)
    if dates:
        effective_date = dates[-1]
        first_line = DATE_RE.sub("", first_line).strip()

    status = None
    blob = " ".join(lines)
    for needle, label in STATUS_PATTERNS:
        if needle in blob:
            status = label
            break

    phone = None
    email = None
    city = None
    state = None
    address_lines: list[str] = []

    for ln in lines[1:]:
        if ln.startswith("Ph:"):
            pm = PHONE_RE.match(ln)
            if pm:
                phone = pm.group(1).strip()
            continue
        em = EMAIL_RE.search(ln)
        if em:
            email = em.group(0)
            continue
        csm = CITY_STATE_ZIP_RE.match(ln)
        if csm:
            city, state = csm.group(1).strip(), csm.group(2)
            address_lines.append(ln)
            continue
        if ln.lower().startswith("©") or "accreditation council" in ln.lower():
            continue
        address_lines.append(ln)

    # Director + name heuristic from first line remainder after removing status words
    name_part = first_line
    for word in ("Initial", "Continued", "Pre-Accreditation", "Accreditation", "MD", "DO", "MBChB"):
        name_part = name_part.replace(word, " ")
    name_part = re.sub(r"\s+", " ", name_part).strip(" ,")

    # Program name ≈ first line chunk before street number pattern
    street_split = re.split(r"\s+(?=\d+\s+[A-Za-z])", name_part, maxsplit=1)
    program_name = street_split[0].strip() if street_split else name_part
    if len(street_split) > 1:
        address_lines.insert(0, street_split[1].strip())

    # Director: try to find "Name, MD" pattern near end of first line before status
    director = None
    dir_m = re.search(
        r"([A-Z][A-Za-z .'-]+,\s*(?:MD|DO|MBChB|PhD|MPH)(?:,\s*[A-Za-z]+)?)\s*(?:Initial|Continued|$)",
        lines[0],
    )
    if dir_m:
        director = dir_m.group(1).strip()
        program_name = lines[0].split(director)[0]
        program_name = CODE_LINE_RE.sub(r"\1", program_name) if False else program_name
        program_name = re.sub(r"^\[\d{10}\]\s*", "", lines[0].split(director)[0]).strip()

    address = ", ".join(address_lines) if address_lines else None

    return {
        "org_code": org_code,
        "program_name": program_name or name_part,
        "specialty": specialty_hint,
        "mailing_address": address,
        "city": city,
        "state": state,
        "phone": phone,
        "email": email,
        "director": director,
        "accreditation_status": status,
        "effective_date": effective_date,
    }


def parse_report_pdf(path: Path, specialty_hint: Optional[str] = None) -> list[dict]:
    text = extract_pdf_text(path)
    blocks = CODE_SPLIT_RE.split(text)
    programs: list[dict] = []
    for block in blocks:
        rec = _parse_block(block, specialty_hint=specialty_hint)
        if rec:
            programs.append(rec)
    return programs
