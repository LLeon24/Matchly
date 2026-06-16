#!/usr/bin/env python3
"""
Scrape AAMC ERAS Participating Specialties & Programs (PAR) index.

Source: https://systems.aamc.org/eras/erasstats/par/index.cfm

ERAS groups specialties into:
  - July cycle fellowships
  - September cycle residencies
  - December cycle fellowships

Output: Matchly/Data/ERAS_PAR_specialties.json
"""

from __future__ import annotations

import argparse
import json
import re
from datetime import datetime, timezone
from pathlib import Path

import requests
from bs4 import BeautifulSoup

PAR_URL = "https://systems.aamc.org/eras/erasstats/par/index.cfm"
USER_AGENT = "MatchlyDataPipeline/1.0 (public ERAS PAR specialty index)"


def _links_from_row(tr) -> list[dict]:
    out: list[dict] = []
    for anchor in tr.find_all("a", href=re.compile(r"SPEC_CD=")):
        match = re.search(r"SPEC_CD=(\d+)", anchor.get("href", ""))
        if match:
            out.append({"name": anchor.get_text(strip=True), "spec_cd": match.group(1)})
    return out


def fetch_par_specialties() -> dict:
    response = requests.get(PAR_URL, timeout=30, headers={"User-Agent": USER_AGENT})
    response.raise_for_status()
    soup = BeautifulSoup(response.text, "html.parser")

    july: list[dict] = []
    residency: list[dict] = []
    december: list[dict] = []

    for row in soup.find_all("tr"):
        text = row.get_text(" ", strip=True)
        next_row = row.find_next_sibling("tr")
        if not next_row:
            continue
        if "Fellowship - July Cycle" in text and "December" not in text:
            july = _links_from_row(next_row)
        elif "Residency - September Cycle" in text:
            residency = _links_from_row(next_row)
        elif "Fellowship - December Cycle" in text:
            december = _links_from_row(next_row)

    fellowship = july + december
    fellowship_by_code = {item["spec_cd"]: item["name"] for item in fellowship}
    residency_by_code = {item["spec_cd"]: item["name"] for item in residency}

    return {
        "source": PAR_URL,
        "erasYear": "2027",
        "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "counts": {
            "residency": len(residency_by_code),
            "fellowshipJuly": len(july),
            "fellowshipDecember": len(december),
            "fellowshipTotal": len(fellowship_by_code),
        },
        "residencyByCode": residency_by_code,
        "fellowshipByCode": fellowship_by_code,
        "fellowshipJulyByCode": {item["spec_cd"]: item["name"] for item in july},
        "fellowshipDecemberByCode": {item["spec_cd"]: item["name"] for item in december},
    }


def main() -> None:
    repo_data = Path(__file__).resolve().parents[2] / "Data"
    parser = argparse.ArgumentParser(description="Fetch ERAS PAR residency/fellowship specialty lists")
    parser.add_argument(
        "--output",
        type=Path,
        default=repo_data / "ERAS_PAR_specialties.json",
    )
    args = parser.parse_args()

    data = fetch_par_specialties()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    print(
        f"Wrote {args.output} — "
        f"{data['counts']['residency']} residencies, "
        f"{data['counts']['fellowshipTotal']} fellowships"
    )


if __name__ == "__main__":
    main()
