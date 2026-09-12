"""
Respectful HTTP client for the ACGME ADS Public site.

This client intentionally does NOT attempt to defeat any anti-automation
control. It maintains a single session, reuses the search page's anti-forgery
token, sends a descriptive User-Agent and the required Referer, and rate-limits
every request. If it detects that CAPTCHA enforcement has been turned on (or that
the site asks not to be automated), it raises `AutomationBlocked` and stops.

Prefer the official ACGME API (see sources/official_api.py) whenever it is
available. Use this client only for interim, low-volume, permission-based runs.
"""

from __future__ import annotations

import re
import time
import logging
from dataclasses import dataclass, field
from typing import Optional

import requests
from bs4 import BeautifulSoup

logger = logging.getLogger("acgme.client")

BASE = "https://apps.acgme.org/ads/Public"
SEARCH_URL = f"{BASE}/Programs/Search"
DETAIL_URL = f"{BASE}/Programs/Detail"

# Identify the client honestly. Set a real contact address before any real run.
DEFAULT_USER_AGENT = (
    "MatchlyDataPipeline/1.0 (annual residency catalog refresh; contact: you@example.com)"
)


class AutomationBlocked(RuntimeError):
    """Raised when ADS signals that automated access is blocked/CAPTCHA-gated."""


@dataclass
class ACGMEClient:
    delay_seconds: float = 2.0          # hard minimum between requests
    timeout: int = 30
    user_agent: str = DEFAULT_USER_AGENT
    session: requests.Session = field(default_factory=requests.Session)

    _token: Optional[str] = None
    _last_request: float = 0.0

    def __post_init__(self) -> None:
        self.session.headers.update({"User-Agent": self.user_agent})

    # -- low-level ---------------------------------------------------------

    def _throttle(self) -> None:
        elapsed = time.monotonic() - self._last_request
        if elapsed < self.delay_seconds:
            time.sleep(self.delay_seconds - elapsed)
        self._last_request = time.monotonic()

    def _check_not_blocked(self, html: str) -> None:
        """Abort if the page indicates CAPTCHA enforcement / automation block."""
        if re.search(r'AllowBrowserAutomation"\s*value="True"', html, re.I):
            return  # explicitly allowed
        if re.search(r'ShowCaptcha"\s*value="True"', html, re.I) or re.search(
            r'DisableCaptcha"\s*value="True"', html, re.I
        ):
            raise AutomationBlocked(
                "ADS is enforcing CAPTCHA. Stop and use the official API or a "
                "manual export instead."
            )

    # -- session bootstrap -------------------------------------------------

    def prime(self) -> None:
        """Load the search page to obtain cookies + anti-forgery token."""
        self._throttle()
        resp = self.session.get(SEARCH_URL, timeout=self.timeout)
        resp.raise_for_status()
        self._check_not_blocked(resp.text)
        m = re.search(
            r'name="__RequestVerificationToken"[^>]*value="([^"]+)"', resp.text
        )
        if not m:
            raise RuntimeError("Could not find anti-forgery token on search page.")
        self._token = m.group(1)
        logger.info("Session primed (token acquired).")

    # -- enumeration (protected) ------------------------------------------

    def search_specialty(self, specialty_id: str, accreditation_type_id: str = "2") -> str:
        """POST the advanced search for one specialty; returns results HTML.

        Note: this hits the *protected* search endpoint. Only use with
        permission / for low-volume runs. Prefer `enrich` flows that use known
        codes instead.
        """
        if self._token is None:
            self.prime()
        self._throttle()
        data = {
            "__RequestVerificationToken": self._token,
            "accreditationTypeId": accreditation_type_id,
            "specialtyId": str(specialty_id),
            "specialtyCategoryTypeId": "",
            "stateId": "",
            "city": "",
            "numCode": "",
        }
        resp = self.session.post(
            SEARCH_URL, data=data, headers={"Referer": SEARCH_URL}, timeout=self.timeout
        )
        resp.raise_for_status()
        self._check_not_blocked(resp.text)
        return resp.text

    # -- detail (referrer-gated only) -------------------------------------

    def get_detail_html(self, org_code: str) -> str:
        """GET a single program's detail page by ACGME orgCode."""
        if self._token is None:
            # Detail only needs a Referer + session cookie, but priming also
            # gives us the cookie jar.
            self.prime()
        self._throttle()
        resp = self.session.get(
            DETAIL_URL,
            params={"orgCode": org_code},
            headers={"Referer": SEARCH_URL},
            timeout=self.timeout,
        )
        resp.raise_for_status()
        if re.search(r"return to the search page", resp.text, re.I):
            raise RuntimeError(
                f"Detail page for {org_code} was gated (missing referer/session)."
            )
        return resp.text


def parse_search_rows(html: str) -> list[dict]:
    """Extract (org_code, specialty, name, city) rows from a search results page."""
    soup = BeautifulSoup(html, "lxml")
    rows: list[dict] = []
    for tr in soup.select("table tbody tr"):
        cells = [td.get_text(strip=True) for td in tr.find_all("td")]
        link = tr.find("a", href=re.compile(r"orgCode="))
        if not link or len(cells) < 4:
            continue
        m = re.search(r"orgCode=([0-9]+)", link["href"])
        if not m:
            continue
        rows.append(
            {
                "org_code": m.group(1),
                "code": cells[0],
                "specialty": cells[1],
                "name": cells[2],
                "city": cells[3],
            }
        )
    return rows
