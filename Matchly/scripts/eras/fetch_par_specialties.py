#!/usr/bin/env python3
"""
Scrape AAMC ERAS PAR index and build specialty hierarchy maps for Matchly.

Sources:
  - ERAS PAR: https://systems.aamc.org/eras/erasstats/par/index.cfm
  - ACGME Report #1 specialty order (parent → fellowship relationships)

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

# ACGME Report #1 specialty order (apps.acgme.org) — fellowship rows follow their parent residency.
ACGME_REPORT_SPECIALTY_ORDER = """
Allergy and immunology (020) Anesthesiology (040) Adult cardiothoracic anesthesiology (041)
Critical care medicine (Anesthesiology) (045) Obstetric anesthesiology (043)
Pain medicine (multidisciplinary) (530) Pediatric anesthesiology (042)
Pediatric cardiac anesthesiology (047) Regional anesthesiology and acute pain medicine (046)
Colon and rectal surgery (060) Dermatology (080) Dermatopathology (multidisciplinary) (100)
Micrographic surgery and dermatologic oncology (081) Pediatric dermatology (082)
Emergency medicine (110) Emergency medical services (112) Medical toxicology (Emergency medicine) (118)
Pediatric emergency medicine (Emergency medicine) (114) Sports medicine (Emergency medicine) (116)
Undersea and hyperbaric medicine (Emergency medicine) (119) Family medicine (120)
Clinical informatics (Family medicine) (122) Geriatric medicine (Family medicine) (125)
Hospice and palliative medicine (multidisciplinary) (540) Sports medicine (Family medicine) (127)
Internal medicine (140) Adult congenital heart disease (153) Advanced heart failure and transplant cardiology (159)
Cardiovascular disease (141) Clinical cardiac electrophysiology (154) Clinical informatics (Internal medicine) (139)
Critical care medicine (Internal medicine) (142) Endocrinology, diabetes, and metabolism (143)
Gastroenterology (144) Geriatric medicine (Internal medicine) (151) Hematology and medical oncology (155)
Infectious disease (146) Interventional cardiology (152) Interventional pulmonology (138)
Medical oncology (147) Nephrology (148) Pulmonary disease (149)
Pulmonary disease and critical care medicine (156) Rheumatology (150) Sleep medicine (multidisciplinary) (520)
Transplant hepatology (158) Medical genetics and genomics (130) Transplant nephrology (137)
Medical biochemical genetics (131) Molecular genetic pathology (multidisciplinary) (190)
Neurological surgery (160) Neuroendovascular intervention (Neurological surgery) (163)
Neurology (180) Clinical neurophysiology (187) Epilepsy (184)
Neurocritical care (multidisciplinary) (550) Neuroendovascular intervention (Neurology) (182)
Neurodevelopmental disabilities (186) Neuromuscular medicine (Neurology) (183) Vascular neurology (188)
Child neurology (185) Nuclear medicine (200) Obstetrics and gynecology (220)
Urogynecology and Reconstructive Pelvic Surgery (OBGYN) (221) Gynecologic oncology (225)
Maternal-fetal medicine (230) Reproductive endocrinology and infertility (235) Complex family planning (236)
Ophthalmology (240) Ophthalmic plastic and reconstructive surgery (241) Orthopaedic surgery (260)
Adult reconstructive orthopaedics (261) Foot and ankle orthopaedics (262) Hand surgery (Orthopaedic surgery) (263)
Musculoskeletal oncology (270) Orthopaedic sports medicine (268) Orthopaedic surgery of the spine (267)
Orthopaedic trauma (269) Pediatric orthopaedics (265) Osteopathic neuromusculoskeletal medicine (275)
Otolaryngology - Head and Neck Surgery (280) Neurotology (286) Pediatric otolaryngology (288)
Pathology-anatomic and clinical (300) Blood banking/transfusion medicine (305)
Clinical informatics (Pathology) (302) Chemical pathology (306) Cytopathology (307)
Forensic pathology (310) Hematopathology (311) Medical microbiology (314) Neuropathology (315)
Pediatric pathology (316) Selective pathology (301) Pediatrics (320) Adolescent medicine (321)
Child abuse pediatrics (339) Clinical informatics (Pediatrics) (322) Developmental-behavioral pediatrics (336)
Neonatal-perinatal medicine (329) Pediatric cardiology (325) Pediatric critical care medicine (323)
Pediatric emergency medicine (Pediatrics) (324) Pediatric endocrinology (326) Pediatric gastroenterology (332)
Pediatric hematology/oncology (327) Pediatric infectious diseases (335) Pediatric nephrology (328)
Pediatric pulmonology (330) Pediatric rheumatology (331) Sports medicine (Pediatrics) (333)
Pediatric transplant hepatology (338) Pediatric hospital medicine (334)
Physical medicine and rehabilitation (340) Brain injury medicine (Physical medicine and rehabilitation) (347)
Spinal cord injury medicine (345) Pediatric rehabilitation medicine (346)
Sports medicine (Physical medicine and rehabilitation) (342) Plastic surgery (360) Craniofacial surgery (361)
Hand surgery (Plastic surgery) (363) Plastic Surgery - Integrated (362)
Public health and general preventive medicine (380) Undersea and hyperbaric medicine (Preventive medicine) (398)
Medical toxicology (Preventive medicine) (399) Aerospace medicine (383)
Occupational and environmental medicine (382) Psychiatry (400) Addiction medicine (multidisciplinary) (404)
Addiction psychiatry (401) Child and adolescent psychiatry (405) Forensic psychiatry (406)
Geriatric psychiatry (407) Consultation-liaison psychiatry (409) Radiation oncology (430)
Radiology-diagnostic (420) Abdominal radiology (421) Musculoskeletal radiology (426)
Neuroendovascular intervention (Radiology) (422) Neuroradiology (423) Nuclear radiology (425)
Pediatric radiology (424) Vascular and interventional radiology (427)
Interventional radiology - independent (415) Interventional radiology - integrated (416)
Surgery (440) Complex general surgical oncology (446) Hand surgery (Surgery) (443)
Pediatric surgery (445) Surgical critical care (442) Vascular surgery - independent (450)
Vascular surgery - integrated (451) Thoracic surgery - independent (460) Congenital cardiac surgery (466)
Thoracic surgery - integrated (461) Urology (480) Urogynecology and Reconstructive Pelvic Surgery (Urology) (486)
Pediatric urology (485) Transitional year (999)
"""

RESIDENCY_SPECIALTY_CODES = {
    "020", "040", "060", "080", "110", "120", "140", "130", "160", "180", "185", "200", "220", "240",
    "260", "275", "280", "300", "320", "340", "360", "362", "380", "382", "383", "400", "416", "420",
    "430", "440", "450", "451", "460", "461", "480", "999",
    "700", "705", "715", "726", "730", "735", "740", "742", "745", "751", "752", "753", "754", "755",
    "756", "757", "765", "766", "770", "775", "785", "790", "795", "796", "797",
}

# Onboarding specialty → ACGME residency codes (includes combined programs).
USER_SPECIALTY_RESIDENCY_CODES: dict[str, list[str]] = {
    "Internal Medicine": ["140", "700", "705", "715", "740", "742", "745", "751", "766", "785"],
    "Family Medicine": ["120", "720", "752", "753", "795"],
    "Emergency Medicine": ["110", "705", "725", "795", "796", "797"],
    "Pediatrics": ["320", "700", "725", "726", "730", "735", "765", "790"],
    "General Surgery": ["440"],
    "OB/GYN": ["220"],
    "Psychiatry": ["400", "715", "720", "730", "755"],
    "Neurology": ["180", "745", "755"],
    "Anesthesiology": ["040", "726", "742", "796"],
    "Radiology": ["420", "770"],
    "Interventional Radiology - Integrated": ["416"],
    "Pathology": ["300"],
    "Orthopedics": ["260"],
    "ENT": ["280"],
    "Urology": ["480"],
    "PM&R": ["340", "735"],
    "Dermatology": ["080", "785", "790"],
    "Neurosurgery": ["160"],
    "Child Neurology": ["185"],
    "Nuclear Medicine": ["200", "770"],
    "Radiation Oncology": ["430"],
    "Plastic Surgery": ["360", "362"],
    "Ophthalmology": ["240"],
    "Thoracic Surgery - Integrated": ["461"],
    "Vascular Surgery - Integrated": ["451"],
    "Transitional Year": ["999"],
    "Aerospace Medicine": ["383", "797"],
    "Occupational and Environmental Medicine": ["382"],
    "Public Health and General Preventive Medicine": ["380"],
    "Osteopathic Neuromusculoskeletal Medicine": ["275", "753"],
}

ADDITIONAL_FELLOWSHIP_CODES_BY_USER_SPECIALTY: dict[str, list[str]] = {
    "Emergency Medicine": ["404", "520", "540", "530"],
    "Family Medicine": ["404", "520", "540", "127"],
    "Internal Medicine": ["404", "520", "540", "530"],
    "Pediatrics": ["404", "520", "540"],
    "Psychiatry": ["404", "520", "540"],
    "Neurology": ["404", "520", "540", "550"],
    "Anesthesiology": ["404", "520", "540", "530"],
    "PM&R": ["404", "520", "540"],
    "General Surgery": ["060", "450", "460", "446", "445", "442", "443"],
    "OB/GYN": ["754"],
    "Radiology": ["415", "421", "422", "423", "424", "425", "426", "427"],
}


def build_fellowship_parent_by_code() -> dict[str, str]:
    entries = re.findall(r"([^(]+?)\s*\((\d{3})\)", ACGME_REPORT_SPECIALTY_ORDER)
    parent: str | None = None
    mapping: dict[str, str] = {}
    for _name, code in entries:
        if code in RESIDENCY_SPECIALTY_CODES:
            parent = code
        elif parent:
            mapping[code] = parent

    # ERAS-only / cross-parent fellowships not in ACGME parent chain order.
    overrides = {
        "044": "040",  # Clinical Informatics (Anesthesiology)
        "060": "440",  # Colon and Rectal Surgery (after general surgery)
        "111": "110",  # Clinical Informatics (Emergency Medicine)
        "112": "110",
        "114": "110",
        "116": "110",
        "118": "110",
        "119": "110",
        "145": "140",  # Hematology
        "189": "180",  # Brain Injury Medicine (Neurology)
        "450": "440",
        "460": "440",
        "754": "220",  # Medical Genetics/MFM
    }
    mapping.update(overrides)
    return dict(sorted(mapping.items()))


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
    fellowship_parent = build_fellowship_parent_by_code()

    return {
        "source": PAR_URL,
        "erasYear": "2027",
        "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "counts": {
            "residency": len(residency_by_code),
            "fellowshipJuly": len(july),
            "fellowshipDecember": len(december),
            "fellowshipTotal": len(fellowship_by_code),
            "fellowshipParentMappings": len(fellowship_parent),
        },
        "residencyByCode": residency_by_code,
        "fellowshipByCode": fellowship_by_code,
        "fellowshipJulyByCode": {item["spec_cd"]: item["name"] for item in july},
        "fellowshipDecemberByCode": {item["spec_cd"]: item["name"] for item in december},
        "fellowshipParentByCode": fellowship_parent,
        "userSpecialtyResidencyCodes": USER_SPECIALTY_RESIDENCY_CODES,
        "additionalFellowshipCodesByUserSpecialty": ADDITIONAL_FELLOWSHIP_CODES_BY_USER_SPECIALTY,
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
        f"{data['counts']['fellowshipTotal']} fellowships, "
        f"{data['counts']['fellowshipParentMappings']} parent mappings"
    )


if __name__ == "__main__":
    main()
