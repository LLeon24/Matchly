#!/usr/bin/env python3
"""Flag suspicious hospital names in ACGME_2026.json."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG_PATH = ROOT / "Data" / "ACGME_2026.json"
ERAS_PATH = ROOT / "Data" / "ERAS2026.json"

CITY_NAME_TOKENS = {
    "tampa", "orlando", "miami", "jacksonville", "gainesville", "tallahassee",
    "boston", "chicago", "houston", "dallas", "atlanta", "phoenix", "denver",
}


def has_city_then_person_name(name: str) -> bool:
    parts = name.split()
    if len(parts) < 4:
        return False
    city_token = parts[-3].lower().rstrip(".,")
    if city_token not in CITY_NAME_TOKENS:
        return False
    person1, person2 = parts[-2], parts[-1]
    if not (person1[0].isupper() and person2[0].isupper()):
        return False
    if any(marker in person2.lower() for marker in ("hospital", "program", "center")):
        return False
    return True


def token_key(word: str) -> str:
    return word.lower().rstrip(".")


def has_consecutive_duplicate_tokens(name: str) -> bool:
    words = name.split()
    prev = None
    for word in words:
        key = token_key(word)
        if prev and key == prev:
            return True
        prev = key
    return False


def looks_corrupted(name: str) -> bool:
    if not name or not name.strip():
        return True
    if has_consecutive_duplicate_tokens(name):
        return True
    if has_city_then_person_name(name):
        return True
    lower = name.lower()
    if "adventhealth adventhealth" in lower:
        return True
    if name.strip().endswith((" and", " of", " at", " Program")):
        return True
    # Duplicate institution token or glued director / city+name blobs
    if re.search(
        r"\b(?:tampa|orlando|miami|boston|chicago)\s+[A-Z][a-z]+\s+[A-Z][a-z]+\s*$",
        name,
    ):
        return True
    if re.search(r"\b[A-Z][a-z]+\s+[A-Z][a-z]+\s+[A-Z][a-z]+\s*,?\s*No\s*$", name):
        return True
    if re.search(
        r"\b(?:Hospital|Health|Healthcare|Medical|University|Clinic|Center|Florida|AdventHealth)\b.*"
        r"\b[A-Z][a-z]+\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)?\s*$",
        name,
    ):
        if not re.search(r"\b(?:Saint|St\.|Mount|Fort|Los|San|New|North|South|East|West)\s+[A-Z]", name):
            return True
    return False


def normalize_for_compare(name: str) -> str:
    name = re.sub(r"\s+program\s*$", "", name.strip(), flags=re.I)
    return re.sub(r"\s+", " ", name).lower()


def main() -> int:
    if not CATALOG_PATH.exists():
        print(f"Catalog not found: {CATALOG_PATH}", file=sys.stderr)
        return 1

    programs = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    eras_by_id: dict[str, dict] = {}
    if ERAS_PATH.exists():
        for program in json.loads(ERAS_PATH.read_text(encoding="utf-8")):
            acc_id = program.get("accreditationID") or program.get("id")
            if acc_id:
                eras_by_id[acc_id] = program

    rows: list[str] = []
    for program in programs:
        acc_id = program.get("accreditationID") or program.get("id") or "?"
        hospital = program.get("hospital") or ""
        issues: list[str] = []

        if looks_corrupted(hospital):
            issues.append("corrupted_name")

        eras = eras_by_id.get(acc_id)
        if eras:
            eras_hospital = eras.get("hospital") or ""
            if eras_hospital and normalize_for_compare(eras_hospital) != normalize_for_compare(hospital):
                issues.append(f"eras_mismatch:eras={eras_hospital}")

        if issues:
            rows.append(
                f"{acc_id}\t{hospital}\t{program.get('city', '')}\t{program.get('state', '')}\t"
                + ";".join(issues)
            )

    print(f"Scanned {len(programs)} programs; {len(rows)} name issues.")
    for row in rows[:300]:
        print(row)
    if len(rows) > 300:
        print(f"... and {len(rows) - 300} more")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
