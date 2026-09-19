# ACGME Data Integration

How Matchly's program catalog is sourced from ACGME ADS, kept current annually,
and merged with Matchly's own classifications (IMG-friendly, Academic vs.
Community) without losing them on each refresh.

> **Status:** Pipeline scaffold + findings. Source defaults to the official
> ACGME API when granted; an ADS-public adapter exists for interim use **only**
> under the constraints in the "Legal / Terms of Service" section below.

---

## 1. What ACGME ADS exposes

The public Accreditation Data System lives at `https://apps.acgme.org/ads/Public`.
It is a server-rendered ASP.NET app (jQuery DataTables), not a JSON SPA. Two
endpoints carry everything we need:

### a) Program list (enumeration) — *protected*

```
POST https://apps.acgme.org/ads/Public/Programs/Search
Content-Type: application/x-www-form-urlencoded

__RequestVerificationToken=<from search page>
accreditationTypeId=2        # 2 = Accreditation, 3 = Osteopathic Recognition
specialtyId=1                # ADS specialty id (191 options)
specialtyCategoryTypeId=
stateId=                     # optional, 1..53
city=                        # optional
numCode=                     # optional alternative to specialtyId (e.g. "020")
```

Returns the full results page HTML. Each row yields the 10-digit `orgCode`
(e.g. `0200121109`), specialty, program name, and city. One specialty returns
all of its programs in a single response (e.g. 108 for Allergy & Immunology).

### b) Program detail — *referrer-gated only*

```
GET https://apps.acgme.org/ads/Public/Programs/Detail?orgCode=<10-digit code>
Referer: https://apps.acgme.org/ads/Public/Programs/Search
```

Returns the full program page (~16 KB HTML) with:
sponsoring institution, street address, specialty, phone, email, website,
**program director** (+ first-appointed date), **coordinator(s)** (name / phone /
email), **accreditation status**, original/effective accreditation dates,
accredited length of training, osteopathic recognition, last & next site visit,
**total approved / filled positions**, and the **participating sites** table.

A direct GET with no `Referer` returns "Please return to the search page." A GET
with the search-page `Referer` (and session cookie) returns the real content.

---

## 2. Legal / Terms of Service — read before running anything

The search page embeds anti-automation signals:

- a reCAPTCHA `SiteKey`,
- `AllowBrowserAutomation=False`,
- `ShowCaptcha=False`, `DisableCaptcha=False` (CAPTCHA infrastructure present but
  currently not enforced).

**Interpretation:** ACGME has clearly built infrastructure to discourage
automated/bulk access. Scripted access works *today* only because CAPTCHA is not
currently being enforced; that can change at any time. Bulk scraping for a
commercial product is therefore a Terms-of-Service / legal risk.

**Policy for this repo:**

1. **Preferred:** use the official ACGME API once access is granted
   (request already filed). The pipeline swaps to it by changing one source
   adapter — see `sources/official_api.py`.
2. The `ads_public` adapter is for **interim, low-volume, permission-based** use
   only. It must remain respectful: a descriptive `User-Agent`, a hard rate
   limit, annual cadence, and it **aborts** if it detects CAPTCHA is enforced or
   `AllowBrowserAutomation` changes. It will never attempt to solve a CAPTCHA.
3. **Lowest-risk interim option:** *enrichment by known code.* Matchly's existing
   dataset already stores each program's `accreditationID`, which **is** the ACGME
   `orgCode`. We can refresh contacts / director / coordinator / status for
   programs we already list using only the referrer-gated detail endpoint — no
   enumeration of the protected search at all. See `sources/ads_public.py`
   (`mode="enrich"`).

---

## 3. Target schema (app-compatible)

The app decodes `ResidencyProgramInfo` (see
`Matchly/Utilities/ResidencyProgramDatabase.swift`). The pipeline emits that
shape so existing decoding keeps working; richer ACGME fields are added as
*extra* keys the app currently ignores (Swift `Codable` drops unknown keys), so
they can be surfaced later without breaking older builds.

```jsonc
{
  "id": "0200121109",              // = accreditationID = ACGME orgCode
  "name": "University of Alabama Hospital (Birmingham) Program",
  "hospital": "University of Alabama Hospital (Birmingham) Program",
  "city": "Birmingham",
  "state": "AL",
  "address": "1600 7th Avenue South, Birmingham, AL 35233",
  "specialty": "Allergy and Immunology",
  "type": "Academic",             // Academic | Community | Hybrid (Matchly overlay)
  "accreditationID": "0200121109",
  "websiteURL": "https://www.uab.edu/...",
  "contactEmail": "talkinso@uabmc.edu",
  "contactPhone": "(205) 658-0827",
  "programCoordinator": "Ronda Chandler",
  "isIMGFriendly": null,          // Matchly overlay/heuristic

  // --- richer ACGME fields (additive; app may ignore until surfaced) ---
  "accreditationStatus": "Continued Accreditation",
  "programDirector": "JaneMarie F Freeman, MD",
  "directorAppointedDate": "2025-12-01",
  "coordinators": [{ "name": "...", "phone": "...", "email": "..." }],
  "sponsoringInstitution": "University of Alabama Hospital",
  "approvedPositions": 4,
  "filledPositions": 2,
  "participatingSites": ["Birmingham VA Medical Center", "Children's of Alabama"],
  "lastSiteVisit": "2009-05-21",
  "accreditationOriginalDate": "1991-07-01"
}
```

Plus a sibling `manifest.json` for the app's update check:

```json
{ "version": "2026.1", "generatedAt": "2026-06-13T00:00:00Z", "programCount": 12000, "datasetURL": "programs_2026.json" }
```

---

## 4. Preserving IMG-friendly & Academic/Community across refreshes

Neither field exists in ACGME data. They are Matchly's own. To keep them when the
catalog refreshes annually, the build applies a **curated overlay** keyed by
`orgCode` *after* normalization:

- `curated_overlay.json` — values you've verified (e.g. you checked a program's
  current residents and confirmed it's IMG-friendly). These win.
- The IMG heuristic (`IMGFriendlyHelper` logic, mirrored in `overlay.py`) fills
  programs not in the overlay.

Result: verified answers are stable year over year; everything else gets a
sensible default. See `overlay.py` and `curated_overlay.example.json`.

---

## 5. Hosting & "always up to date" (recommended)

To update the catalog **without an App Store release each year**:

1. Run the pipeline once a year → produces `programs_<year>.json` + `manifest.json`.
2. Host both on a static, versioned URL (GitHub raw / a CDN bucket). Free, simple.
3. The app checks `manifest.json` on launch, downloads the dataset if the version
   is newer than its cached copy, and caches it in Application Support.
4. The bundled `ERAS2026.json` remains the offline fallback.

The reference catalog (`ResidencyProgramDatabase`) is refreshed freely. The
user's *tracked* programs (ratings/notes/signals in `DataManager`) are never
overwritten; only their metadata (contacts/status) is refreshed, keyed by
`accreditationID`.

---

## 6. Pipeline layout

```
Matchly/scripts/acgme/
  acgme_client.py            # respectful ADS HTTP client (session, token, referer, rate limit, captcha guard)
  parse_detail.py            # detail-page HTML -> structured dict
  specialties.py             # ADS specialtyId / numCode / name map
  sources/
    base.py                  # ProgramSource interface
    official_api.py          # PREFERRED: ACGME API adapter (stub until access granted)
    ads_public.py            # interim adapter: mode="enrich" (by known code) or "full" (enumerate)
    manual_import.py         # load from a CSV/JSON export you provide
  normalize.py               # raw -> app schema
  overlay.py                 # apply curated overlay + IMG heuristic
  build_dataset.py           # orchestrator -> programs_<year>.json + manifest.json
  curated_overlay.example.json
  acgme-requirements.txt      # named to avoid colliding with scripts/requirements.txt in the app bundle
  README.md
```

### Running

```bash
cd Matchly/scripts/acgme
pip install -r acgme-requirements.txt

# Lowest-risk: refresh only programs we already list, by their ACGME code
python build_dataset.py --source ads_enrich --input ../../Data/ERAS2026_with_addresses.json --year 2026

# When the official API is granted (preferred):
python build_dataset.py --source official_api --year 2026

# From a manual export you downloaded:
python build_dataset.py --source manual --input my_export.csv --year 2026
```
