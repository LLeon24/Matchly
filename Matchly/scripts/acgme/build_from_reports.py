#!/usr/bin/env python3
"""
Build a Matchly catalog from ACGME ADS Report #1 PDFs
(https://apps.acgme.org/ads/Public/Reports/Report/1).

Two modes:
  A) --reports-dir   Parse PDFs you saved manually (safest / offline)
  B) --fetch-reports Download one PDF per specialty (polite rate limit)

Example:
  python build_from_reports.py --fetch-reports --output acgme_catalog.json --delay 3
  python build_from_reports.py --reports-dir ~/Desktop/ACGME/Reports --output acgme_catalog.json
"""

from __future__ import annotations

import argparse
import json
import logging
import re
import time
from datetime import datetime, timezone
from pathlib import Path

import requests
from bs4 import BeautifulSoup

from normalize import to_matchly_program
from parse_report_pdf import parse_report_pdf

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
logger = logging.getLogger("acgme.reports")

REPORT_PAGE = "https://apps.acgme.org/ads/Public/Reports/Report/1"
REPORT_RUN = "https://apps.acgme.org/ads/Public/Reports/ReportRun"
USER_AGENT = "MatchlyDataPipeline/1.0 (annual public catalog; contact: you@example.com)"


def fetch_specialty_codes(session: requests.Session) -> list[tuple[str, str]]:
    session.headers.setdefault("User-Agent", USER_AGENT)
    resp = session.get(REPORT_PAGE, timeout=30)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "html.parser")
    select = soup.find("select", attrs={"name": "SpecialtyCode"})
    if not select:
        raise RuntimeError("Could not find SpecialtyCode dropdown on report page.")
    token_el = soup.find("input", {"name": "__RequestVerificationToken"})
    token = token_el["value"] if token_el else ""
    year_el = soup.find("input", {"name": "CurrentYear"})
    year = year_el["value"] if year_el else "2025"

    options: list[tuple[str, str]] = []
    for opt in select.find_all("option"):
        code = (opt.get("value") or "").strip()
        label = opt.get_text(strip=True)
        if code:
            options.append((code, label))
    return options, token, year


def download_report_pdf(
    session: requests.Session,
    specialty_code: str,
    token: str,
    year: str,
    dest: Path,
) -> None:
    data = {
        "__RequestVerificationToken": token,
        "ReportId": "1",
        "CurrentYear": year,
        "SpecialtyCode": specialty_code,
        "IncludePreAccreditation": "true",
    }
    resp = session.post(
        REPORT_RUN,
        data=data,
        headers={"Referer": REPORT_PAGE, "User-Agent": USER_AGENT},
        timeout=120,
    )
    resp.raise_for_status()
    if not resp.content.startswith(b"%PDF"):
        raise RuntimeError(f"Expected PDF for specialty {specialty_code}, got {resp.headers.get('content-type')}")
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(resp.content)


def specialty_hint_from_filename(path: Path) -> str | None:
    m = re.search(r"\((\d{3})\)", path.stem)
    return path.stem if path.stem else None


def load_from_directory(reports_dir: Path) -> list[dict]:
    pdfs = sorted(reports_dir.glob("**/*.pdf"))
    if not pdfs:
        raise SystemExit(f"No PDF files under {reports_dir}")

    by_code: dict[str, dict] = {}
    for pdf in pdfs:
        hint = pdf.stem
        logger.info("Parsing %s", pdf.name)
        rows = parse_report_pdf(pdf, specialty_hint=hint)
        logger.info("  → %d programs", len(rows))
        for raw in rows:
            search_row = {
                "org_code": raw["org_code"],
                "code": raw["org_code"],
                "specialty": raw.get("specialty") or hint,
                "name": raw.get("program_name") or "",
                "city": raw.get("city") or "",
            }
            by_code[raw["org_code"]] = to_matchly_program(search_row, raw)
    return list(by_code.values())


def main() -> None:
    parser = argparse.ArgumentParser(description="Build Matchly catalog from ACGME Report #1 PDFs")
    parser.add_argument("--reports-dir", type=Path, help="Folder of saved report PDFs")
    parser.add_argument("--fetch-reports", action="store_true", help="Download PDFs from ADS")
    parser.add_argument(
        "--download-dir",
        type=Path,
        default=Path("./report_pdfs"),
        help="Where to save PDFs when --fetch-reports is set",
    )
    parser.add_argument("--output", type=Path, default=Path("acgme_catalog.json"))
    parser.add_argument("--delay", type=float, default=3.0, help="Seconds between PDF downloads")
    parser.add_argument("--limit", type=int, default=0, help="Max specialties to download (0=all)")
    args = parser.parse_args()

    if not args.reports_dir and not args.fetch_reports:
        parser.error("Provide --reports-dir or --fetch-reports")

    if args.fetch_reports:
        session = requests.Session()
        session.headers["User-Agent"] = USER_AGENT
        options, token, year = fetch_specialty_codes(session)
        logger.info("Found %d specialties on report page", len(options))
        if args.limit:
            options = options[: args.limit]

        for i, (code, label) in enumerate(options, start=1):
            safe = re.sub(r"[^\w\s()-]", "", label).strip()
            dest = args.download_dir / f"{safe}.pdf"
            if dest.exists():
                logger.info("[%d/%d] Skipping existing %s", i, len(options), dest.name)
                continue
            logger.info("[%d/%d] Downloading %s", i, len(options), label)
            download_report_pdf(session, code, token, year, dest)
            time.sleep(args.delay)

        args.reports_dir = args.download_dir

    programs = load_from_directory(args.reports_dir)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(programs, indent=2, ensure_ascii=False), encoding="utf-8")
    logger.info("Wrote %d unique programs → %s", len(programs), args.output)

    with_state = sum(1 for p in programs if p.get("state"))
    with_email = sum(1 for p in programs if p.get("contactEmail"))
    logger.info("Coverage: %d with state, %d with email", with_state, with_email)


if __name__ == "__main__":
    main()
