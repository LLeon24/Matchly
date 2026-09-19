#!/usr/bin/env python3
"""Flag suspicious program addresses in ACGME_2026.json for manual review."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG_PATH = ROOT / "Data" / "ACGME_2026.json"

GARBAGE_MARKERS = (
    "accreditation",
    "md accreditation",
    "healthcare (greater program",
    "program director",
)

STREET_RE = re.compile(
    r"\d{1,5}\s+\w+.*(?:st|street|ave|avenue|blvd|boulevard|rd|road|dr|drive|ln|lane|way|cir|ct|hwy|pkwy)",
    re.I,
)

KNOWN_OVERRIDES = {
    "osceola": {"address": "700 W Oak St", "city": "Kissimmee", "state": "FL"},
    "lake nona": {"address": "6850 Lake Nona Blvd", "city": "Orlando", "state": "FL"},
}


def expected_campus(program: dict) -> dict | None:
    hospital = (program.get("hospital") or "").lower()
    if ("central florida" in hospital or "ucf" in hospital) and "hca" in hospital:
        if "osceola" in hospital and "lake nona" not in hospital:
            return KNOWN_OVERRIDES["osceola"]
        if "lake nona" in hospital:
            return KNOWN_OVERRIDES["lake nona"]
    return None


def looks_like_garbage(address: str) -> bool:
    lower = address.lower()
    return any(marker in lower for marker in GARBAGE_MARKERS)


def audit_program(program: dict) -> list[str]:
    issues: list[str] = []
    acc_id = program.get("accreditationID") or program.get("id") or "?"
    hospital = program.get("hospital") or ""
    address = (program.get("address") or "").strip()
    city = (program.get("city") or "").strip()
    state = (program.get("state") or "").strip()

    if address and looks_like_garbage(address):
        issues.append("garbage_address_blob")

    if address and not STREET_RE.search(address) and not looks_like_garbage(address):
        issues.append("unparsed_street_line")

    if not address:
        issues.append("missing_address")

    campus = expected_campus(program)
    if campus:
        if address and address != campus["address"]:
            issues.append(f"campus_address_mismatch:expected={campus['address']},got={address}")
        if city and city.lower() != campus["city"].lower():
            issues.append(f"campus_city_mismatch:expected={campus['city']},got={city}")
        if state and state.upper() != campus["state"]:
            issues.append(f"campus_state_mismatch:expected={campus['state']},got={state}")

    if issues:
        return [f"{acc_id}\t{hospital}\t{address}\t{city}\t{state}\t" + ";".join(issues)]
    return []


def main() -> int:
    if not CATALOG_PATH.exists():
        print(f"Catalog not found: {CATALOG_PATH}", file=sys.stderr)
        return 1

    programs = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    rows: list[str] = []
    for program in programs:
        rows.extend(audit_program(program))

    print(f"Scanned {len(programs)} programs; {len(rows)} flagged.")
    for row in rows[:200]:
        print(row)
    if len(rows) > 200:
        print(f"... and {len(rows) - 200} more")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
