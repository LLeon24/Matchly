#!/usr/bin/env python3
"""
Build a Matchly-compatible program catalog from saved ACGME ADS search exports.

Typical workflow (lowest legal/ToS friction):
  1. In Safari, run an ACGME ADS search for one specialty.
  2. File → Save As… → Web Archive (.webarchive) into a folder per specialty.
  3. Repeat for each specialty you care about.
  4. Run this script on that folder.

With --fetch-details, the script will politely request each program's detail
page from the public ADS site (rate-limited, honest User-Agent). Only use that
flag if you accept ACGME's terms and the pipeline's captcha guard aborts if
automation is blocked.

Usage:
  cd Matchly/scripts/acgme
  pip install -r acgme-requirements.txt

  # List-only from your saved search pages (no network):
  python build_dataset.py --search-dir ~/Desktop/ACGME --output acgme_sample.json

  # Full records (contacts, director, address, accreditation):
  python build_dataset.py --search-dir ~/Desktop/ACGME --output acgme_full.json --fetch-details
"""

from __future__ import annotations

import argparse
import json
import logging
import sys
from datetime import datetime, timezone
from pathlib import Path

from acgme_client import ACGMEClient, parse_search_rows
from normalize import to_matchly_program
from parse_detail import parse_detail
from webarchive_io import find_search_exports, read_html

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
logger = logging.getLogger("acgme.build")


def load_search_rows(search_dir: Path) -> list[dict]:
    exports = find_search_exports(search_dir)
    if not exports:
        raise SystemExit(f"No .webarchive/.html files found under {search_dir}")

    by_code: dict[str, dict] = {}
    for path in exports:
        logger.info("Parsing search export: %s", path)
        html = read_html(path)
        rows = parse_search_rows(html)
        logger.info("  → %d programs", len(rows))
        for row in rows:
            by_code[row["org_code"]] = row

    return list(by_code.values())


def build_programs(
    rows: list[dict],
    *,
    fetch_details: bool,
    delay: float,
    cache_dir: Path | None,
) -> list[dict]:
    client = ACGMEClient(delay_seconds=delay) if fetch_details else None
    if client:
        client.prime()

    programs: list[dict] = []
    total = len(rows)

    for i, row in enumerate(rows, start=1):
        org_code = row["org_code"]
        detail_dict = None

        if cache_dir:
            cache_file = cache_dir / f"{org_code}.html"
            if cache_file.exists():
                detail_dict = parse_detail(cache_file.read_text(encoding="utf-8"), org_code)

        if detail_dict is None and client is not None:
            logger.info("[%d/%d] Fetching detail %s", i, total, org_code)
            try:
                html = client.get_detail_html(org_code)
                if cache_dir:
                    cache_dir.mkdir(parents=True, exist_ok=True)
                    (cache_dir / f"{org_code}.html").write_text(html, encoding="utf-8")
                detail_dict = parse_detail(html, org_code)
            except Exception as exc:
                logger.warning("  detail fetch failed for %s: %s", org_code, exc)

        programs.append(to_matchly_program(row, detail_dict))

    return programs


def main() -> None:
    parser = argparse.ArgumentParser(description="Build Matchly catalog from ACGME ADS exports")
    parser.add_argument(
        "--search-dir",
        type=Path,
        required=True,
        help="Folder containing saved .webarchive or .html search result pages",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("acgme_programs.json"),
        help="Output JSON path (Matchly ResidencyProgramInfo array)",
    )
    parser.add_argument(
        "--fetch-details",
        action="store_true",
        help="Fetch each program detail page from ADS (rate-limited; opt-in)",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=2.0,
        help="Seconds between network requests when --fetch-details is set",
    )
    parser.add_argument(
        "--cache-dir",
        type=Path,
        default=None,
        help="Optional folder to cache downloaded detail HTML for re-runs",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=None,
        help="Optional manifest.json path (version metadata for in-app updates)",
    )
    args = parser.parse_args()

    rows = load_search_rows(args.search_dir)
    logger.info("Unique programs from exports: %d", len(rows))

    programs = build_programs(
        rows,
        fetch_details=args.fetch_details,
        delay=args.delay,
        cache_dir=args.cache_dir,
    )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(programs, indent=2, ensure_ascii=False), encoding="utf-8")
    logger.info("Wrote %d programs → %s", len(programs), args.output)

    if args.manifest:
        manifest = {
            "version": datetime.now(timezone.utc).strftime("%Y.%m"),
            "generatedAt": datetime.now(timezone.utc).isoformat(),
            "programCount": len(programs),
            "datasetURL": args.output.name,
            "source": "acgme_ads_manual_export",
        }
        args.manifest.parent.mkdir(parents=True, exist_ok=True)
        args.manifest.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
        logger.info("Wrote manifest → %s", args.manifest)

    without_state = sum(1 for p in programs if not p.get("state"))
    if without_state and not args.fetch_details:
        logger.warning(
            "%d programs have no state — re-run with --fetch-details for full addresses.",
            without_state,
        )


if __name__ == "__main__":
    main()
