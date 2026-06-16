#!/usr/bin/env python3
"""
Refresh Matchly catalog from ERAS PAR + ACGME enrichment.

  1. fetch_eras_par.py  → ERAS2026.json (authoritative names)
  2. enrich_catalog.py  → ACGME_2026.json (merge + sanitize + propagate)
  3. audit_names.py     → flag remaining name issues
  4. audit_addresses.py → flag remaining address issues
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent


def run_step(label: str, args: list[str]) -> int:
    print(f"\n=== {label} ===")
    result = subprocess.run([sys.executable, *args], cwd=SCRIPTS_DIR.parent.parent)
    return result.returncode


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync ACGME catalog from ERAS PAR")
    parser.add_argument(
        "--skip-fetch",
        action="store_true",
        help="Skip ERAS fetch (use existing ERAS2026.json)",
    )
    parser.add_argument(
        "--specialty",
        action="append",
        dest="specialties",
        help="Only fetch specific ERAS specialties (repeatable)",
    )
    args = parser.parse_args()

    fetch_args = [str(SCRIPTS_DIR / "fetch_eras_par.py")]
    if args.specialties:
        for specialty in args.specialties:
            fetch_args.extend(["--specialty", specialty])

    steps: list[tuple[str, list[str]]] = []
    if not args.skip_fetch:
        steps.append(("Fetch ERAS PAR", fetch_args))
    steps.extend(
        [
            ("Enrich catalog", [str(SCRIPTS_DIR / "enrich_catalog.py")]),
            ("Audit names", [str(SCRIPTS_DIR / "audit_names.py")]),
            ("Audit addresses", [str(SCRIPTS_DIR / "audit_addresses.py")]),
        ]
    )

    for label, cmd in steps:
        code = run_step(label, cmd)
        if code != 0:
            print(f"\nStopped: {label} failed (exit {code})", file=sys.stderr)
            return code

    print("\nCatalog sync complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
