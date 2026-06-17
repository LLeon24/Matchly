"""Map raw ACGME search + detail records to Matchly's ResidencyProgramInfo JSON shape."""

from __future__ import annotations

from typing import Optional


def _title_specialty(name: Optional[str]) -> str:
    if not name:
        return "Unknown"
    words = name.strip().split()
    small = {"and", "of", "in", "the", "for"}
    titled = []
    for i, word in enumerate(words):
        if i > 0 and word.lower() in small:
            titled.append(word.lower())
        else:
            titled.append(word[:1].upper() + word[1:].lower() if word else word)
    return " ".join(titled)


def _coordinator_name(raw: dict) -> Optional[str]:
    coords = raw.get("coordinators") or []
    if not coords:
        return None
    return coords[0].get("name")


def to_matchly_program(search_row: dict, detail: Optional[dict] = None) -> dict:
    """Merge a search-table row with optional detail-page fields."""
    detail = detail or {}
    org_code = search_row.get("org_code") or search_row.get("code")

    name = detail.get("program_name") or search_row.get("name") or ""
    specialty = detail.get("specialty") or search_row.get("specialty") or "Unknown"
    city = detail.get("city") or search_row.get("city") or ""
    state = detail.get("state") or ""

    coordinator = _coordinator_name(detail)
    email = detail.get("email")
    phone = detail.get("phone")
    website = detail.get("website")
    address = detail.get("mailing_address")

    record = {
        "id": org_code,
        "name": name,
        "hospital": name,
        "city": city,
        "state": state,
        "address": address,
        "specialty": _title_specialty(specialty),
        "accreditationID": org_code,
        "websiteURL": website,
        "contactEmail": email,
        "contactPhone": phone,
        "programCoordinator": coordinator,
        "isIMGFriendly": None,
    }

    # Additive ACGME fields (Swift Codable ignores unknown keys today; useful later)
    extras = {
        "accreditationStatus": detail.get("accreditation_status"),
        "programDirector": detail.get("director"),
        "directorAppointedDate": detail.get("director_appointed"),
        "coordinators": detail.get("coordinators"),
        "sponsoringInstitution": detail.get("sponsoring_institution"),
        "approvedPositions": detail.get("approved_positions"),
        "filledPositions": detail.get("filled_positions"),
        "participatingSites": detail.get("participating_sites"),
        "lastSiteVisit": detail.get("last_site_visit"),
        "accreditationOriginalDate": detail.get("original_accreditation_date"),
        "accreditationEffectiveDate": detail.get("effective_date"),
        "accreditedLengthOfTraining": detail.get("accredited_length_of_training"),
    }
    for key, value in extras.items():
        if value is not None:
            record[key] = value

    return record
