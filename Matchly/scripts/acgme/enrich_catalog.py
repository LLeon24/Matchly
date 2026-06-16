#!/usr/bin/env python3
"""
Post-process ACGME catalog JSON for complete hospital names and city/state.

Steps:
  1. Merge ERAS2026.json by accreditation ID (hospital, city, state, website)
  2. Parse city/state from messy address strings
  3. Derive campus-specific hospital names from address patterns
  4. Propagate location data within sponsoring-institution groups
"""

from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

CITY_STATE_ZIP_RE = re.compile(
    r"(?<![A-Za-z])([A-Za-z][A-Za-z .'\-]{0,45}?),\s*([A-Z]{2})\s+(\d{5}(?:-\d{4})?)"
)
CAMPUS_PROGRAM_RE = re.compile(r"\(([^)]+)\)\s*Program", re.I)
ERAS_JUNK_RE = re.compile(r"Osteopathic\s*Recognized!*", re.I)
DIRECTOR_NOISE_RE = re.compile(
    r"\b(?:MD|DO|MBChB|MPH|MBA|PhD|Accreditation|Program|Suite|Ste)\b",
    re.I,
)

# Short generic names that need a campus qualifier when available.
VAGUE_HOSPITALS = {
    "adventhealth",
    "mayo clinic",
    "ochsner health",
    "baptist health",
    "ascension",
    "christus health",
    "memorial healthcare",
    "providence",
    "trinity health",
    "commonspirit health",
    "hca healthcare",
    "tenet healthcare",
    "community health network",
    "beaumont health",
    "spectrum health",
    "honorhealth",
    "banner health",
    "dignity health",
    "sutter health",
    "providence health",
}


def institution_key(code: str) -> Optional[str]:
    if code and len(code) == 10 and code.isdigit():
        return code[3:7]
    return None


def clean_eras_hospital(name: str) -> str:
    name = ERAS_JUNK_RE.sub("", name)
    name = name.replace("\xa0", " ").strip()
    return re.sub(r"\s+", " ", name)


def looks_like_institution_name(name: str) -> bool:
    if not name or is_vague_hospital(name):
        return True
    lower = name.lower()
    institution_markers = (
        "health",
        "hospital",
        "medical center",
        "medical centre",
        "university",
        "college of",
        "advent",
        "clinic",
        "system",
    )
    return any(marker in lower for marker in institution_markers)


def is_vague_hospital(name: str) -> bool:
    if not name or not name.strip():
        return True
    normalized = name.strip().lower()
    if normalized in VAGUE_HOSPITALS:
        return True
    words = normalized.split()
    if len(words) <= 2 and "(" not in name:
        return True
    return False


def is_truncated_hospital(name: str) -> bool:
    if not name or not name.strip():
        return True
    trimmed = name.strip()
    if trimmed.endswith((" and", " of", " at")):
        return True
    if is_vague_hospital(trimmed):
        return True
    if re.search(r"\b(?:MD|DO|Program|Accreditation|Michael|Mana)\b", trimmed, re.I):
        return True
    return False


def site_from_address(address: Optional[str]) -> Optional[str]:
    if not address:
        return None
    patterns = [
        r"(South Shore University Hospital|Cohen Children's Medical Center|Lenox Hill Hospital|Staten Island University Hospital|North Shore University Hospital)",
        r"\bat\s+((?:[^,]+?(?:Hospital|Medical Center|University Hospital)[^,]*))",
        r"Program\s+([A-Za-z .'-]+),\s*[A-Z]{2}",
    ]
    for pattern in patterns:
        match = re.search(pattern, address, re.I)
        if match:
            site = match.group(1).strip()
            if len(site) > 3 and not DIRECTOR_NOISE_RE.search(site):
                return site
    return None


def reconstruct_hospital_from_address(hospital: str, address: Optional[str]) -> str:
    if not is_truncated_hospital(hospital):
        return hospital
    addr = address or ""
    if re.search(r"Hofstra/Northwell|Zucker School", addr, re.I):
        base = "Zucker School of Medicine at Hofstra/Northwell"
        site = site_from_address(addr)
        if site:
            return f"{base} at {site}"
        return base
    if hospital.strip().lower().startswith("zucker school"):
        site = site_from_address(addr)
        if site:
            return f"Zucker School of Medicine at Hofstra/Northwell at {site}"
    return hospital


def is_plausible_city(city: str) -> bool:
    if not city or len(city) > 50:
        return False
    if DIRECTOR_NOISE_RE.search(city):
        return False
    if any(ch.isdigit() for ch in city):
        return False
    return True


def parse_city_state_from_address(address: Optional[str]) -> tuple[str, str]:
    if not address:
        return "", ""
    matches = list(CITY_STATE_ZIP_RE.finditer(address))
    for match in reversed(matches):
        city, state = match.group(1).strip(), match.group(2)
        if is_plausible_city(city):
            return city, state
    return "", ""


def parse_campus_from_address(address: Optional[str]) -> Optional[str]:
    if not address:
        return None
    match = CAMPUS_PROGRAM_RE.search(address)
    if not match:
        return None
    campus = match.group(1).strip()
    if not campus or DIRECTOR_NOISE_RE.search(campus):
        return None
    return campus


def improve_hospital_from_address(hospital: str, address: Optional[str]) -> str:
    campus = parse_campus_from_address(address)
    if not campus:
        return hospital

    hospital = hospital.strip()
    if not is_vague_hospital(hospital):
        # Append campus when name is long but still missing a parenthetical campus.
        if "(" not in hospital and campus.lower() not in hospital.lower():
            return f"{hospital} ({campus})"
        return hospital

    # AdventHealth + "Florida (East Orlando) Program" in address
    state_region = None
    region_match = re.search(
        r"\b(Florida|California|Texas|Georgia|Ohio|Pennsylvania|Colorado|Arizona)\s*\(",
        address or "",
        re.I,
    )
    if region_match:
        state_region = region_match.group(1).title()

    base = hospital
    if state_region and state_region.lower() not in base.lower():
        if base.lower() == "adventhealth":
            base = f"AdventHealth {state_region}"
        else:
            base = f"{base} {state_region}"

    if campus.lower() not in base.lower():
        return f"{base} ({campus})"
    return base


def pick_better_hospital(current: str, candidate: str) -> str:
    current = (current or "").strip()
    candidate = clean_eras_hospital(candidate or "")
    if not candidate:
        return current
    if not current:
        return candidate
    if is_vague_hospital(current) and not is_vague_hospital(candidate):
        return candidate
    if len(candidate) > len(current) + 3:
        return candidate
    if "(" in candidate and "(" not in current:
        return candidate
    return current


def specialty_program_name(specialty: str) -> str:
    if not specialty:
        return ""
    return re.sub(r"\s*\(\d{3}\)\s*$", "", specialty).strip()


STREET_LINE_RE = re.compile(
    r"(\d{1,5}[^,]*?(?:Street|St|Boulevard|Blvd|Avenue|Ave|Road|Rd|Drive|Dr|Way|Lane|Ln|Circle|Cir|Court|Ct|Highway|Hwy|Parkway|Pkwy)(?:[^,]*?)?)\s*,\s*"
    r"([A-Za-z][A-Za-z .'\-]+?)\s*,\s*([A-Z]{2})\s+\d{5}",
    re.I,
)

CAMPUS_OVERRIDES_BY_ID = {
    "1101100194": {
        "address": "7300 W Oak St",
        "city": "Kissimmee",
        "state": "FL",
    },
}


def looks_like_garbage_address(raw: str) -> bool:
    lower = raw.lower()
    return any(
        token in lower
        for token in ("accreditation", "md accreditation", "healthcare (greater program")
    )


def parse_street_from_raw(raw: str) -> tuple[str, str, str] | None:
    if not raw:
        return None
    matches = list(STREET_LINE_RE.finditer(raw))
    if not matches:
        return None
    match = matches[-1]
    city = match.group(2).strip()
    if not city or any(ch.isdigit() for ch in city):
        return None
    if any(token in city.lower() for token in ("program", "accreditation", "healthcare")):
        return None
    return match.group(1).strip(), city, match.group(3).strip()


def resolve_mailing_address(program: dict) -> dict:
    hospital = (program.get("hospital") or "").lower()
    raw = program.get("address") or ""
    acc_id = program.get("accreditationID") or program.get("id")

    if acc_id in CAMPUS_OVERRIDES_BY_ID:
        return dict(CAMPUS_OVERRIDES_BY_ID[acc_id])

    if ("central florida" in hospital and "hca" in hospital) or ("ucf" in hospital and "hca" in hospital):
        if "osceola" in hospital and "lake nona" not in hospital:
            parsed = parse_street_from_raw(raw)
            if parsed and parsed[1].lower() == "kissimmee":
                return {"address": parsed[0], "city": parsed[1], "state": parsed[2]}
            return {"address": "7300 W Oak St", "city": "Kissimmee", "state": "FL"}
        if "lake nona" in hospital or "lake nona" in raw.lower() or "6850" in raw:
            return {"address": "6850 Lake Nona Blvd", "city": "Orlando", "state": "FL"}

    if looks_like_garbage_address(raw):
        parsed = parse_street_from_raw(raw)
        if parsed:
            return {"address": parsed[0], "city": parsed[1], "state": parsed[2]}
        return {"address": ""}

    return {"address": raw.strip()}


def clean_program_director(raw: Optional[str]) -> Optional[str]:
    if not raw:
        return None
    text = raw.strip()
    m = re.search(r"([A-Z][a-z]+(?:\s+[A-Z]\.?)?\s+[A-Z][a-z]+),?\s+MD\s*$", text)
    if m:
        return m.group(1).strip()
    blocklist = ("university", "hospital", "medical", "accreditation", "program")
    if not any(b in text.lower() for b in blocklist) and len(text.split()) >= 2:
        return text
    return None


def enrich_program(program: dict, eras: Optional[dict]) -> dict:
    out = dict(program)
    address = out.get("address") or ""

    # ERAS merge (highest confidence for overlapping programs)
    if eras:
        if eras.get("city") and eras.get("state"):
            out["city"] = eras["city"]
            out["state"] = eras["state"]
        out["hospital"] = pick_better_hospital(out.get("hospital", ""), eras.get("hospital", ""))
        if eras.get("websiteURL") and not out.get("websiteURL"):
            out["websiteURL"] = eras["websiteURL"]
        eras_name = (eras.get("name") or "").strip()
        if eras_name and looks_like_institution_name(out.get("name", "")):
            out["name"] = eras_name

    # Parse city/state from address when still missing
    if not (out.get("city") or "").strip() or not (out.get("state") or "").strip():
        parsed_city, parsed_state = parse_city_state_from_address(address)
        if parsed_city and parsed_state:
            if not (out.get("city") or "").strip():
                out["city"] = parsed_city
            if not (out.get("state") or "").strip():
                out["state"] = parsed_state

    # Improve hospital name using campus patterns in address
    out["hospital"] = improve_hospital_from_address(out.get("hospital", ""), address)
    out["hospital"] = reconstruct_hospital_from_address(out.get("hospital", ""), address)

    # Prefer specialty-based program name over mis-parsed institution strings
    specialty_name = specialty_program_name(out.get("specialty", ""))
    if specialty_name:
        out["specialty"] = specialty_name
    current_name = (out.get("name") or "").strip()
    hospital_name = (out.get("hospital") or "").strip()
    if specialty_name:
        if (
            not current_name
            or looks_like_institution_name(current_name)
            or current_name.lower() == (program.get("hospital") or "").strip().lower()
            or current_name.lower() == hospital_name.lower()
        ):
            out["name"] = specialty_name

    resolved = resolve_mailing_address(out)
    if resolved.get("address") is not None:
        out["address"] = resolved["address"] or None
    if resolved.get("city"):
        out["city"] = resolved["city"]
    if resolved.get("state"):
        out["state"] = resolved["state"]

    if out.get("programDirector"):
        out["programDirector"] = clean_program_director(out.get("programDirector"))
    elif address:
        # Some PDF blobs embed director name before "MD Accreditation"
        m = re.search(r"([A-Z][a-z]+(?:\s+[A-Z]\.?)?\s+[A-Z][a-z]+),?\s+MD\s+Accreditation", address)
        if m:
            out["programDirector"] = m.group(1).strip()

    if not out.get("programDirector") and out.get("contactEmail"):
        local = out["contactEmail"].split("@")[0]
        parts = [p for p in re.split(r"[._]", local) if p]
        if len(parts) >= 2:
            out["programDirector"] = " ".join(p.capitalize() for p in parts[:2])

    return out


def propagate_institution_data(programs: list[dict]) -> list[dict]:
    by_inst: dict[str, list[dict]] = defaultdict(list)
    for program in programs:
        key = institution_key(program.get("accreditationID") or program.get("id", ""))
        if key:
            by_inst[key].append(program)

    for group in by_inst.values():
        # Best hospital template: longest non-vague name in the group
        templates = sorted(
            [p["hospital"] for p in group if p.get("hospital") and not is_truncated_hospital(p["hospital"])],
            key=lambda h: -len(h),
        )
        best_hospital = templates[0] if templates else ""
        inst_prefix = ""
        if best_hospital and not is_vague_hospital(best_hospital):
            inst_prefix = re.sub(r"\s*\([^)]+\)\s*$", "", best_hospital).strip()
            inst_prefix = re.sub(r"\s+at\s+.+$", "", inst_prefix, flags=re.I).strip()

        # City/state frequency within institution
        city_counts: dict[str, int] = defaultdict(int)
        state_counts: dict[str, int] = defaultdict(int)
        campus_to_city: dict[str, tuple[str, str]] = {}

        for program in group:
            city, state = program.get("city", ""), program.get("state", "")
            if city and state:
                city_counts[city] += 1
                state_counts[state] += 1
            campus = parse_campus_from_address(program.get("address"))
            if campus and city and state:
                campus_to_city[campus.lower()] = (city, state)

        default_city = max(city_counts, key=city_counts.get) if city_counts else ""
        default_state = max(state_counts, key=state_counts.get) if state_counts else ""

        inst_prefix = inst_prefix or ""
        if best_hospital and not is_vague_hospital(best_hospital) and not inst_prefix:
            inst_prefix = re.sub(r"\s*\([^)]+\)\s*$", "", best_hospital).strip()

        for program in group:
            if not program.get("city") or not program.get("state"):
                campus = parse_campus_from_address(program.get("address"))
                if campus and campus.lower() in campus_to_city:
                    program["city"], program["state"] = campus_to_city[campus.lower()]
                elif default_city and default_state:
                    program["city"] = program.get("city") or default_city
                    program["state"] = program.get("state") or default_state

            if is_vague_hospital(program.get("hospital", "")) and inst_prefix:
                campus = parse_campus_from_address(program.get("address"))
                if campus:
                    candidate = f"{inst_prefix} ({campus})"
                    program["hospital"] = pick_better_hospital(program["hospital"], candidate)

    return programs


def enrich_catalog(
    acgme_path: Path,
    eras_path: Path,
    output_path: Path,
    manifest_path: Optional[Path] = None,
) -> dict:
    acgme_programs = json.loads(acgme_path.read_text(encoding="utf-8"))
    eras_programs = json.loads(eras_path.read_text(encoding="utf-8"))
    eras_by_id = {p.get("accreditationID") or p.get("id"): p for p in eras_programs}

    enriched = [
        enrich_program(p, eras_by_id.get(p.get("accreditationID") or p.get("id")))
        for p in acgme_programs
    ]
    enriched = propagate_institution_data(enriched)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(enriched, indent=2, ensure_ascii=False), encoding="utf-8")

    stats = {
        "total": len(enriched),
        "with_city_state": sum(1 for p in enriched if p.get("city") and p.get("state")),
        "vague_hospitals": sum(1 for p in enriched if is_vague_hospital(p.get("hospital", ""))),
    }

    if manifest_path:
        manifest = {
            "version": "2026.2",
            "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "programCount": stats["total"],
            "datasetURL": output_path.name,
            "source": "acgme_ads_report_1_pdfs+eras_enrichment",
            "enrichment": {
                "erasSource": eras_path.name,
                "withCityState": stats["with_city_state"],
                "vagueHospitalRemaining": stats["vague_hospitals"],
            },
        }
        manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    return stats


def main() -> None:
    repo_data = Path(__file__).resolve().parents[2] / "Data"
    parser = argparse.ArgumentParser(description="Enrich ACGME catalog with ERAS + address parsing")
    parser.add_argument(
        "--acgme",
        type=Path,
        default=repo_data / "ACGME_2026.json",
        help="Input ACGME catalog JSON",
    )
    parser.add_argument(
        "--eras",
        type=Path,
        default=repo_data / "ERAS2026.json",
        help="ERAS catalog JSON for merge",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=repo_data / "ACGME_2026.json",
        help="Output enriched catalog JSON",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=repo_data / "ACGME_manifest.json",
        help="Manifest JSON to update",
    )
    args = parser.parse_args()

    stats = enrich_catalog(args.acgme, args.eras, args.output, args.manifest)
    print(
        f"Enriched {stats['total']} programs → "
        f"{stats['with_city_state']} with city/state, "
        f"{stats['vague_hospitals']} still vague hospital names"
    )


if __name__ == "__main__":
    main()
