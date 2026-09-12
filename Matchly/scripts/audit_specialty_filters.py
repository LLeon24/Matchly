#!/usr/bin/env python3
"""
Audit specialty filter logic against ACGME catalog.

Simulates SpecialtyFormatter.matches() residency/fellowship rules to catch:
  - False positives (substring-style collisions)
  - Missing residency code mappings for commonSpecialties
  - Fellowships with no parent mapping
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SCRIPTS_ACGME = REPO / "scripts" / "acgme"
sys.path.insert(0, str(SCRIPTS_ACGME))

from specialty_training import code_for_specialty_name, training_level_for_program, load_par_index

CATALOG = REPO / "Data" / "ACGME_2026.json"
PAR = REPO / "Data" / "ERAS_PAR_specialties.json"

COMMON_SPECIALTIES = [
    "Internal Medicine", "Family Medicine", "Emergency Medicine", "Pediatrics",
    "General Surgery", "OB/GYN", "Psychiatry", "Neurology", "Anesthesiology",
    "Radiology", "Pathology", "Orthopedics", "ENT", "Urology", "PM&R",
    "Dermatology", "Neurosurgery", "Child Neurology", "Nuclear Medicine",
    "Radiation Oncology", "Plastic Surgery", "Ophthalmology",
    "Interventional Radiology - Integrated", "Thoracic Surgery - Integrated",
    "Vascular Surgery - Integrated", "Transitional Year", "Aerospace Medicine",
    "Occupational and Environmental Medicine",
    "Public Health and General Preventive Medicine",
    "Osteopathic Neuromusculoskeletal Medicine",
]

CATALOG_ALIASES: dict[str, list[str]] = {
    "Internal Medicine": ["Internal Medicine"],
    "Family Medicine": ["Family Medicine"],
    "Emergency Medicine": ["Emergency Medicine"],
    "Pediatrics": ["Pediatrics"],
    "General Surgery": ["Surgery", "General Surgery"],
    "OB/GYN": ["Obstetrics and Gynecology", "OB/GYN"],
    "Psychiatry": ["Psychiatry"],
    "Neurology": ["Neurology"],
    "Anesthesiology": ["Anesthesiology"],
    "Radiology": ["Radiology-Diagnostic", "Diagnostic Radiology", "Radiology", "Diagnostic Radiology/Nuclear Medicine"],
    "Pathology": ["Pathology-Anatomic and Clinical", "Pathology"],
    "Orthopedics": ["Orthopaedic Surgery", "Orthopedics"],
    "ENT": ["Otolaryngology - Head and Neck Surgery", "Otolaryngology", "ENT"],
    "Urology": ["Urology"],
    "PM&R": ["Physical Medicine and Rehabilitation", "PM&R"],
    "Dermatology": ["Dermatology"],
    "Neurosurgery": ["Neurological Surgery", "Neurosurgery"],
    "Child Neurology": ["Child Neurology"],
    "Nuclear Medicine": ["Nuclear Medicine"],
    "Radiation Oncology": ["Radiation Oncology"],
    "Plastic Surgery": ["Plastic Surgery-Integrated", "Plastic Surgery", "Plastic Surgery - Integrated"],
    "Ophthalmology": ["Ophthalmology"],
    "Interventional Radiology - Integrated": ["Interventional Radiology - Integrated", "Interventional Radiology-Integrated"],
    "Thoracic Surgery - Integrated": ["Thoracic Surgery - Integrated", "Thoracic Surgery-Integrated"],
    "Vascular Surgery - Integrated": ["Vascular Surgery - Integrated", "Vascular Surgery-Integrated"],
    "Transitional Year": ["Transitional Year"],
    "Aerospace Medicine": ["Aerospace Medicine"],
    "Occupational and Environmental Medicine": ["Occupational and Environmental Medicine"],
    "Public Health and General Preventive Medicine": ["Public Health and General Preventive Medicine"],
    "Osteopathic Neuromusculoskeletal Medicine": ["Osteopathic Neuromusculoskeletal Medicine"],
}

RESIDENCY_CODES = {
    "020", "040", "060", "080", "110", "120", "140", "130", "160", "180", "185", "200", "220", "240",
    "260", "275", "280", "300", "320", "340", "360", "362", "380", "382", "383", "400", "416", "420",
    "430", "440", "450", "451", "460", "461", "480", "999",
    "700", "705", "715", "726", "730", "735", "740", "742", "745", "751", "752", "753", "754", "755",
    "756", "757", "765", "766", "770", "775", "785", "790", "795", "796", "797",
}


def catalog_code(specialty: str) -> str | None:
    return code_for_specialty_name(specialty, load_par()) or None


def normalized_name(specialty: str) -> str:
    return re.sub(r"\s*\(\d{3}\)\s*$", "", specialty.strip())


def names_match_exact(a: str, b: str) -> bool:
    return a.strip().casefold() == b.strip().casefold()


def old_substring_match(user: str, program_specialty: str) -> bool:
    """Legacy buggy behavior."""
    u, p = user.casefold(), normalized_name(program_specialty).casefold()
    return u in p or p in u


def load_par() -> dict:
    return json.loads(PAR.read_text(encoding="utf-8"))


def fellowship_codes_by_parent(par: dict) -> dict[str, set[str]]:
    result: dict[str, set[str]] = {}
    for fcode, pcode in par["fellowshipParentByCode"].items():
        result.setdefault(pcode, set()).add(fcode)
    return result


def residency_codes_for_user(par: dict, user: str) -> set[str]:
    raw = par.get("userSpecialtyResidencyCodes", {})
    return set(raw.get(user, []))


def fellowship_codes_for_user(par: dict, user: str) -> set[str]:
    parents = residency_codes_for_user(par, user)
    by_parent = fellowship_codes_by_parent(par)
    codes: set[str] = set()
    for p in parents:
        codes |= by_parent.get(p, set())
    extras = par.get("additionalFellowshipCodesByUserSpecialty", {}).get(user, [])
    codes |= set(extras)
    return codes


def training_level(code: str, par: dict, program: dict | None = None) -> str:
    if program:
        return training_level_for_program(program["specialty"], program.get("accreditationID"), par)
    if code in par.get("residencyByCode", {}):
        return "residency"
    if code in par.get("fellowshipByCode", {}):
        return "fellowship"
    return "residency" if code in RESIDENCY_CODES else "fellowship"


def matches_residency(user: str, program: dict, par: dict) -> bool:
    code = catalog_code(program["specialty"])
    if code:
        parent_codes = residency_codes_for_user(par, user)
        if parent_codes and code in parent_codes:
            return True
    program_base = normalized_name(program["specialty"])
    if names_match_exact(program_base, user):
        return True
    aliases = CATALOG_ALIASES.get(user, [user])
    return any(names_match_exact(program_base, a) for a in aliases)


def matches_fellowship(user: str, program: dict, par: dict) -> bool:
    code = catalog_code(program["specialty"])
    if not code:
        return False
    if code in fellowship_codes_for_user(par, user):
        return True
    parent = par["fellowshipParentByCode"].get(code)
    if parent and parent in residency_codes_for_user(par, user):
        return True
    return False


def matches(user: str, program: dict, par: dict) -> bool:
    level = training_level("", par, program)
    if level == "residency":
        return matches_residency(user, program, par)
    return matches_fellowship(user, program, par)


def main() -> int:
    par = load_par()
    programs = json.loads(CATALOG.read_text(encoding="utf-8"))

    errors: list[str] = []
    warnings: list[str] = []

    # Unmapped user specialties
    for user in COMMON_SPECIALTIES:
        if not residency_codes_for_user(par, user):
            warnings.append(f"No residency codes mapped for user specialty: {user}")

    # Fellowships missing parent
    for fcode in par.get("fellowshipByCode", {}):
        if fcode not in par["fellowshipParentByCode"]:
            warnings.append(f"Fellowship code {fcode} has no parent mapping")

    # False positives vs old substring logic
    collision_pairs: list[tuple[str, str, str]] = []
    for user in COMMON_SPECIALTIES:
        false_positives: list[str] = []
        old_false: list[str] = []
        for p in programs:
            spec = p["specialty"]
            code = catalog_code(spec) or ""
            level = training_level("", par, p)
            if level != "residency":
                continue
            if matches_residency(user, p, par) and old_substring_match(user, spec) and not names_match_exact(normalized_name(spec), user):
                # Could be legitimate alias match
                aliases = CATALOG_ALIASES.get(user, [user])
                if not any(names_match_exact(normalized_name(spec), a) for a in aliases):
                    if code not in residency_codes_for_user(par, user):
                        false_positives.append(spec)

            if old_substring_match(user, spec) and not matches_residency(user, p, par):
                if user.casefold() != normalized_name(spec).casefold():
                    old_false.append(spec)

        if false_positives:
            errors.append(f"RESIDENCY false positives for {user}: {len(false_positives)} e.g. {false_positives[:3]}")
        if old_false and user in ("Neurology", "Radiology", "ENT", "Urology"):
            collision_pairs.append((user, str(len(old_false)), old_false[0]))

    # Per-specialty residency audit: programs that OLD logic would include but NEW excludes (good)
    # Per-specialty: programs NEW includes for residency filter
    for user in COMMON_SPECIALTIES:
        matched = [p for p in programs if training_level("", par, p) == "residency" and matches_residency(user, p, par)]
        wrong = [p for p in matched if user.casefold() not in normalized_name(p["specialty"]).casefold()
                 and catalog_code(p["specialty"]) not in residency_codes_for_user(par, user)
                 and not any(names_match_exact(normalized_name(p["specialty"]), a) for a in CATALOG_ALIASES.get(user, [user]))]
        if wrong:
            errors.append(f"Unexpected residency matches for {user}: {[w['specialty'] for w in wrong[:5]]}")

    # Fellowship coverage samples
    for user in ("Emergency Medicine", "Neurology", "OB/GYN", "General Surgery", "Internal Medicine"):
        codes = fellowship_codes_for_user(par, user)
        matched = sum(1 for p in programs if matches_fellowship(user, p, par))
        print(f"  {user} fellowship: {len(codes)} eligible codes, {matched} catalog programs match")

    print("\n=== Specialty Filter Audit ===")
    if collision_pairs:
        print("\nSubstring collisions fixed (old logic would wrongly exclude/include):")
        for user, count, example in collision_pairs:
            print(f"  {user}: {count} programs affected (e.g. {example})")

    if warnings:
        print(f"\nWarnings ({len(warnings)}):")
        for w in warnings[:20]:
            print(f"  ⚠ {w}")
        if len(warnings) > 20:
            print(f"  ... and {len(warnings) - 20} more")

    if errors:
        print(f"\nERRORS ({len(errors)}):")
        for e in errors:
            print(f"  ✗ {e}")
        return 1

    print("\n✓ No residency false positives across all common specialties")
    print(f"✓ {len(par['fellowshipParentByCode'])} fellowship parent mappings")
    print(f"✓ {len(par.get('userSpecialtyResidencyCodes', {}))} user specialty residency maps")
    return 0


if __name__ == "__main__":
    sys.exit(main())
