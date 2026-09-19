#!/usr/bin/env python3
"""Validate residency/fellowship classification across the full ACGME catalog."""

from __future__ import annotations

import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SCRIPTS_ACGME = REPO / "scripts" / "acgme"
sys.path.insert(0, str(SCRIPTS_ACGME))

from specialty_training import (  # noqa: E402
    code_for_specialty_name,
    load_par_index,
    repair_garbled_specialty,
    strip_code_suffix,
    training_level_for_code,
    training_level_for_program,
)

CATALOG = REPO / "Data" / "ACGME_2026.json"
ERAS = REPO / "Data" / "ERAS2026.json"


def main() -> int:
    par = load_par_index()
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    eras = json.loads(ERAS.read_text(encoding="utf-8"))
    eras_by_id = {p.get("accreditationID") or p.get("id"): p for p in eras}

    errors: list[str] = []
    warnings: list[str] = []

    unmapped: list[dict] = []
    level_counts = Counter()
    prefix140_fellowship_as_residency: list[str] = []

    for program in catalog:
        acc = program.get("accreditationID") or program.get("id")
        spec = program.get("specialty", "")
        code = code_for_specialty_name(spec, par, accreditation_id=acc)
        level = training_level_for_program(spec, acc, par)
        level_counts[level] += 1

        if not code:
            unmapped.append(program)
            continue

        if not spec.strip().endswith(f"({code})"):
            warnings.append(f"Missing code suffix: {acc} -> {spec}")

        if acc.startswith("140") and level == "residency":
            repaired = repair_garbled_specialty(strip_code_suffix(spec))
            fellow_code = code_for_specialty_name(repaired, par, accreditation_id=acc)
            if fellow_code and fellow_code != "140" and training_level_for_code(fellow_code, par) == "fellowship":
                prefix140_fellowship_as_residency.append(f"{acc} {spec}")

    eras_conflicts = []
    for program in catalog:
        acc = program.get("accreditationID")
        eras_row = eras_by_id.get(acc)
        if not acc or not eras_row:
            continue
        cat_level = training_level_for_program(program["specialty"], acc, par)
        eras_level = training_level_for_program(
            eras_row.get("specialty", ""),
            acc,
            par,
        )
        if cat_level != eras_level:
            eras_conflicts.append(
                (acc, program["specialty"][:40], cat_level, eras_row.get("specialty", "")[:40], eras_level)
            )

    missing_eras_residencies = []
    catalog_ids = {p.get("accreditationID") or p.get("id") for p in catalog}
    for acc, eras_row in eras_by_id.items():
        if acc in catalog_ids:
            continue
        if training_level_for_program(eras_row.get("specialty", ""), acc, par) == "residency":
            missing_eras_residencies.append(acc)

    print("=== Training Level Audit ===")
    print(f"Programs: {len(catalog)}")
    print(f"Residency: {level_counts['residency']}  Fellowship: {level_counts['fellowship']}")
    print(f"Unmapped specialty codes: {len(unmapped)}")
    print(f"Catalog vs ERAS level conflicts: {len(eras_conflicts)}")
    print(f"ERAS residencies missing from catalog: {len(missing_eras_residencies)}")
    print(f"140-prefix fellowships tagged residency: {len(prefix140_fellowship_as_residency)}")

    if unmapped:
        print("\nUnmapped examples:")
        for p in unmapped[:15]:
            print(f"  {p.get('accreditationID')} | {p.get('specialty')[:60]}")

    if eras_conflicts:
        errors.append(f"{len(eras_conflicts)} catalog/ERAS training-level conflicts")
        print("\nERAS conflicts (first 10):")
        for row in eras_conflicts[:10]:
            print(" ", row)

    if prefix140_fellowship_as_residency:
        errors.append(f"{len(prefix140_fellowship_as_residency)} IM-prefix fellowships still marked residency")
        print("\n140-prefix fellowship mislabels (first 10):")
        for row in prefix140_fellowship_as_residency[:10]:
            print(" ", row)

    if missing_eras_residencies:
        errors.append(f"{len(missing_eras_residencies)} ERAS residency programs missing from catalog")

    # Sanity: top residency specialties should not include obvious fellowships
    residency_names = Counter(
        strip_code_suffix(p["specialty"])
        for p in catalog
        if training_level_for_program(p["specialty"], p.get("accreditationID"), par) == "residency"
    )
    fellowship_markers = ("cardiovascular", "gastroenterology", "pulmonary", "nephrology", "hematology")
    bad_residency_labels = [
        name for name in residency_names if any(m in name.lower() for m in fellowship_markers)
    ]
    if bad_residency_labels:
        errors.append(
            "Fellowship-like labels in residency bucket: "
            + ", ".join(sorted(bad_residency_labels)[:8])
        )

    if warnings:
        print(f"\nWarnings: {len(warnings)} (missing `(###)` suffix on otherwise mapped programs)")

    if errors:
        print(f"\nFAILED ({len(errors)}):")
        for err in errors:
            print(f"  ✗ {err}")
        return 1

    print("\n✓ Full catalog training-level audit passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
