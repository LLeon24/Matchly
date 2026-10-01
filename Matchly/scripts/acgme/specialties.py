"""
ADS specialty map (specialtyId -> name).

The authoritative list (191 entries incl. subspecialties) lives in the
`specialtyFilter` <select> on the search page, so we read it live. A small
static fallback is kept for offline/dev use.
"""

from __future__ import annotations

import re
from bs4 import BeautifulSoup

from acgme_client import ACGMEClient, SEARCH_URL

# Partial static fallback (specialtyId -> name). Refresh via fetch_specialty_map.
STATIC_FALLBACK: dict[str, str] = {
    "1": "Allergy and immunology",
    "3": "Anesthesiology",
    "148": "Adult cardiothoracic anesthesiology",
}


def fetch_specialty_map(client: ACGMEClient) -> dict[str, str]:
    """Read the full specialtyId -> name map from the live search page."""
    client._throttle()
    resp = client.session.get(SEARCH_URL, timeout=client.timeout)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "lxml")
    select = soup.find("select", attrs={"name": "specialtyId"})
    if not select:
        return dict(STATIC_FALLBACK)
    out: dict[str, str] = {}
    for opt in select.find_all("option"):
        value = (opt.get("value") or "").strip()
        name = opt.get_text(strip=True)
        if value and name and not re.search(r"search by specialty", name, re.I):
            out[value] = name
    return out or dict(STATIC_FALLBACK)
