"""Residency vs fellowship classification helpers (ERAS PAR + ACGME specialty codes)."""

from __future__ import annotations

import json
import re
from functools import lru_cache
from pathlib import Path
from typing import Optional

REPO_DATA = Path(__file__).resolve().parents[2] / "Data"
PAR_PATH = REPO_DATA / "ERAS_PAR_specialties.json"

RESIDENCY_CODES = {
    "020", "040", "060", "080", "110", "120", "140", "130", "160", "180", "185", "200", "220", "240",
    "260", "275", "280", "300", "320", "340", "360", "362", "380", "382", "383", "400", "416", "420",
    "430", "440", "450", "451", "460", "461", "480", "999",
    "700", "705", "715", "726", "730", "735", "740", "742", "745", "751", "752", "753", "754", "755",
    "756", "757", "765", "766", "770", "775", "785", "790", "795", "796", "797",
}

# Parent residency codes reused in fellowship accreditation IDs (e.g. IM fellowships start with 140).
AMBIGUOUS_PARENT_PREFIXES = {"040", "110", "120", "140", "180", "220", "320", "400", "440", "420", "300"}


def strip_code_suffix(specialty: str) -> str:
    return re.sub(r"\s*\(\d{3}\)\s*$", "", (specialty or "").strip())


def normalize_name(specialty: str) -> str:
    return strip_code_suffix(specialty).casefold()


def fuzzy_key(specialty: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", normalize_name(specialty))


def catalog_code(specialty: str) -> Optional[str]:
    match = re.search(r"\((\d{3})\)\s*$", (specialty or "").strip())
    return match.group(1) if match else None


def repair_garbled_specialty(specialty: str) -> str:
    """Fix common ACGME PDF scrape artifacts before lookup."""
    name = strip_code_suffix(specialty)
    if not name:
        return name

    # CamelCase concatenations: Medicinepediatrics -> Medicine pediatrics
    name = re.sub(r"([a-z])([A-Z])", r"\1 \2", name)
    name = re.sub(r"([a-z])(\d)", r"\1 \2", name)

    replacements = (
        (r"Blood Banking\s*[/]?\s*transfusion", "Blood Banking/Transfusion"),
        (r"Endocrinology\s+,?\s*Diabetes\s+,?\s*and", "Endocrinology, Diabetes, and"),
        (r"Hand Surgery\s*\(\s*orthopaedic", "Hand Surgery (Orthopaedic"),
        (r"Hand Surgery\s*\(\s*surgery", "Hand Surgery (Surgery"),
        (r"Neuromuscular Medicine\s*\(\s*neurology", "Neuromuscular Medicine (Neurology"),
        (r"Pediatric Hematology\s*/?\s*oncology", "Pediatric Hematology/Oncology"),
        (r"Diagnostic Radiology\s*/?\s*nuclear Medicine", "Diagnostic Radiology/Nuclear Medicine"),
        (r"Plastic Surgery\s*-\s*Integrated", "Plastic Surgery-Integrated"),
        (r"Plastic Surgery\s*-\s*integrated", "Plastic Surgery-Integrated"),
        (r"Thoracic Surgery\s*-\s*Independent", "Thoracic Surgery - Independent"),
        (r"Vascular Surgery\s*-\s*Independent", "Vascular Surgery - Independent"),
        (r"Internal Medicine\s*pediatrics", "Internal Medicine/Pediatrics"),
        (r"Internal Medicine\s*emergency Medicine", "Internal Medicine/Emergency Medicine"),
        (r"Internal Medicine\s*psychiatry", "Internal Medicine/Psychiatry"),
        (r"Internal Medicine\s*preventive Medicine", "Internal Medicine/Preventive Medicine"),
        (r"Internal Medicine\s*neurology", "Internal Medicine/Neurology"),
        (r"Internal Medicine\s*dermatology", "Internal Medicine/Dermatology"),
        (r"Internal Medicine\s*anesthesiology", "Internal Medicine/Anesthesiology"),
        (r"Internal Medicine\s*medical Genetics", "Internal Medicine/Medical Genetics"),
        (r"Internal Medicine\s*family Practice", "Internal Medicine/Family Practice"),
        (r"Internal Medicine\s*critical Care Medicine", "Internal Medicine/Critical Care Medicine"),
        (r"Emergency Medicine\s*internal Medicine", "Emergency Medicine/Internal Medicine"),
        (r"Emergency Medicine\s*family Medicine", "Emergency Medicine/Family Medicine"),
        (r"Emergency Medicine\s*pediatrics", "Emergency Medicine/Pediatrics"),
        (r"Family Medicine\s*psychiatry", "Family Medicine/Psychiatry"),
        (r"Family Medicine\s*public Health", "Family Medicine/Public Health"),
        (r"Pediatrics\s*anesthesiology", "Pediatrics/Anesthesiology"),
        (r"Pediatrics\s*dermatology", "Pediatrics/Dermatology"),
        (r"Pediatrics\s*emergency Medicine", "Pediatrics/Emergency Medicine"),
        (r"Pediatrics\s*psychiatry", "Pediatrics/Psychiatry"),
        (r"Medical Genetics and Genomics\s*pediatrics", "Medical Genetics and Genomics/Pediatrics"),
        (r"Aerospace Medicine\s*emergency Medicine", "Aerospace Medicine/Emergency Medicine"),
        (r"Aerospace Medicine\s*internal Medicine", "Aerospace Medicine/Internal Medicine"),
        (r"Anesthesiology\s*emergency Medicine", "Anesthesiology/Emergency Medicine"),
        (r"Anesthesiology\s*internal Medicine", "Anesthesiology/Internal Medicine"),
        (r"Anesthesiology\s*pediatrics", "Anesthesiology/Pediatrics"),
        (r"Dermatology\s*internal Medicine", "Dermatology/Internal Medicine"),
        (r"Psychiatry\s*family medicine", "Psychiatry/Family medicine"),
        (r"Psychiatry\s*neurology", "Psychiatry/Neurology"),
        (r"Public Health and General Preventive Medicine\s*occupational", "Public Health and General Preventive Medicine/Occupational"),
        (r"Otolaryngology\s*-\s*Head and Neck Surgery", "Otolaryngology - Head and Neck Surgery"),
        (r"Pathology\s*-\s*anatomic and clinical", "Pathology-Anatomic and Clinical"),
        (r"Pathology\s*anatomic and clinical", "Pathology-Anatomic and Clinical"),
        (r"Radiology\s*-\s*diagnostic", "Radiology-Diagnostic"),
        (r"Radiology\s*diagnostic", "Radiology-Diagnostic"),
        (r"Orthopaedic\s*surgery", "Orthopaedic Surgery"),
        (r"General Surgery", "Surgery"),
    )
    for pattern, repl in replacements:
        name = re.sub(pattern, repl, name, flags=re.I)

    return re.sub(r"\s+", " ", name).strip()


@lru_cache(maxsize=1)
def load_par_index(path: Path = PAR_PATH) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _all_specialty_names(par: dict) -> dict[str, str]:
    """code -> best display name (ERAS PAR preferred, then ACGME report)."""
    names: dict[str, str] = {}
    names.update(par.get("acgmeSpecialtyByCode", {}))
    names.update(par.get("residencyByCode", {}))
    names.update(par.get("fellowshipByCode", {}))
    return names


def _build_lookup_maps(par: dict) -> tuple[dict[str, str], dict[str, str], dict[str, str]]:
    exact: dict[str, str] = {}
    fuzzy: dict[str, str] = {}
    base_fuzzy: dict[str, str] = {}

    for code, name in _all_specialty_names(par).items():
        exact[normalize_name(name)] = code
        fuzzy[fuzzy_key(name)] = code
        base = name.split("(")[0].strip()
        base_fuzzy[fuzzy_key(base)] = code

    return exact, fuzzy, base_fuzzy


def code_for_specialty_name(
    specialty: str,
    par: Optional[dict] = None,
    *,
    accreditation_id: Optional[str] = None,
) -> Optional[str]:
    par = par or load_par_index()
    explicit = catalog_code(specialty)
    if explicit:
        return explicit

    exact, fuzzy, base_fuzzy = _build_lookup_maps(par)
    for candidate in (specialty, repair_garbled_specialty(specialty)):
        normalized = normalize_name(candidate)
        if normalized in exact:
            return exact[normalized]
        key = fuzzy_key(candidate)
        if key in fuzzy:
            return fuzzy[key]
        base_key = fuzzy_key(candidate.split("(")[0])
        if base_key in base_fuzzy:
            return base_fuzzy[base_key]

    return code_from_accreditation_id(specialty, accreditation_id, par)


def code_from_accreditation_id(
    specialty: str,
    accreditation_id: Optional[str],
    par: Optional[dict] = None,
) -> Optional[str]:
    par = par or load_par_index()
    if not accreditation_id or len(accreditation_id) < 3:
        return None

    prefix = accreditation_id[:3]
    fellowship_codes = par.get("fellowshipByCode", {})
    fellowship_parent = par.get("fellowshipParentByCode", {})
    residency_by_code = par.get("residencyByCode", {})
    acgme_by_code = par.get("acgmeSpecialtyByCode", {})

    # Prefer repaired name for parent-code IDs (140xxxx = IM parent track).
    if prefix in AMBIGUOUS_PARENT_PREFIXES:
        for candidate in (specialty, repair_garbled_specialty(specialty)):
            _, fuzzy, base_fuzzy = _build_lookup_maps(par)
            key = fuzzy_key(candidate)
            if key in fuzzy and fuzzy[key] != prefix:
                return fuzzy[key]
            base_key = fuzzy_key(candidate.split("(")[0])
            if base_key in base_fuzzy and base_fuzzy[base_key] != prefix:
                return base_fuzzy[base_key]

    if prefix in fellowship_codes or prefix in fellowship_parent:
        return prefix
    if prefix in residency_by_code or prefix in RESIDENCY_CODES or prefix in acgme_by_code:
        return prefix
    return None


def canonical_specialty_name(code: str, par: Optional[dict] = None) -> Optional[str]:
    par = par or load_par_index()
    names = _all_specialty_names(par)
    raw = names.get(code)
    if not raw:
        return None
    if code in par.get("fellowshipByCode", {}):
        return strip_code_suffix(raw.split("(")[0].strip())
    return strip_code_suffix(raw)


def training_level_for_code(code: str, par: Optional[dict] = None) -> Optional[str]:
    par = par or load_par_index()
    if code in par.get("residencyByCode", {}):
        return "residency"
    if code in par.get("fellowshipByCode", {}):
        return "fellowship"
    if code in RESIDENCY_CODES:
        return "residency"
    if code in par.get("fellowshipParentByCode", {}):
        return "fellowship"
    return None


def training_level_for_name(specialty: str, par: Optional[dict] = None) -> Optional[str]:
    code = code_for_specialty_name(specialty, par)
    if code:
        return training_level_for_code(code, par)
    return None


def training_level_for_program(
    specialty: str,
    accreditation_id: Optional[str] = None,
    par: Optional[dict] = None,
) -> str:
    code = code_for_specialty_name(specialty, par, accreditation_id=accreditation_id)
    if code:
        level = training_level_for_code(code, par)
        if level:
            return level
    return "fellowship"


def specialty_with_code(
    specialty: str,
    par: Optional[dict] = None,
    *,
    accreditation_id: Optional[str] = None,
) -> str:
    repaired = repair_garbled_specialty(strip_code_suffix(specialty))
    if catalog_code(specialty):
        return specialty.strip()
    code = code_for_specialty_name(repaired, par, accreditation_id=accreditation_id)
    if not code:
        return repaired
    canonical = canonical_specialty_name(code, par) or repaired
    return f"{canonical} ({code})"


def resolve_catalog_specialty(
    acgme_specialty: str,
    eras_specialty: Optional[str],
    par: Optional[dict] = None,
    *,
    accreditation_id: Optional[str] = None,
) -> str:
    """Pick the best specialty label, preferring ERAS when ACGME is misclassified."""
    par = par or load_par_index()
    acgme_base = repair_garbled_specialty(strip_code_suffix(acgme_specialty))
    acgme_code = code_for_specialty_name(acgme_base, par, accreditation_id=accreditation_id)
    acgme_level = training_level_for_code(acgme_code, par) if acgme_code else None

    if eras_specialty:
        eras_base = strip_code_suffix(eras_specialty)
        eras_code = code_for_specialty_name(eras_base, par, accreditation_id=accreditation_id)
        eras_level = training_level_for_code(eras_code, par) if eras_code else None

        if eras_code and not acgme_code:
            return eras_base
        if eras_level == "residency" and acgme_level == "fellowship" and eras_base:
            return eras_base
        if eras_code and acgme_code and eras_code != acgme_code and eras_level and acgme_level:
            if eras_level == "residency" and acgme_level == "fellowship":
                return eras_base

    return acgme_base
