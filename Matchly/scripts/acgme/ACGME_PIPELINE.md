# ACGME catalog builder

Build a Matchly program database from **public ACGME Accreditation Data System (ADS)**
search results you save yourself in Safari.

## Why save pages manually?

ACGME ADS data is public, but the site includes anti-automation signals. Saving
search results yourself (File → Save As → Web Archive) is the lowest-friction
approach: you browse normally, the script parses your exports locally.

## Report #1 PDFs (recommended for full US catalog)

ACGME publishes a **List of Programs by Specialty** report at
https://apps.acgme.org/ads/Public/Reports/Report/1 — one PDF per specialty (~188),
each row containing program code, name, address, director, accreditation status,
and effective date. This is often the fastest way to build a complete catalog.

### Option A — you save PDFs manually

1. Open the report page, pick a specialty, click **View Report**
2. Save the PDF into `~/Desktop/ACGME/Reports/` (name it with the specialty)
3. Repeat for each specialty (or start with the ones you care about)

```bash
python build_from_reports.py \
  --reports-dir ~/Desktop/ACGME/Reports \
  --output ../../Data/ACGME_2026.json \
  --enrich
```

`--enrich` merges `ERAS2026.json` (by ACGME ID), parses city/state from messy
PDF address strings, and adds campus-specific hospital names (e.g. `AdventHealth
Florida (East Orlando)` instead of plain `AdventHealth`). You can also run
enrichment alone:

```bash
python enrich_catalog.py
```

### Residency vs fellowship (ERAS PAR)

Matchly classifies training level using the [AAMC ERAS PAR specialty
index](https://systems.aamc.org/eras/erasstats/par/index.cfm) (54 residencies,
~79 fellowships across July + December cycles). Refresh annually:

```bash
python ../eras/fetch_par_specialties.py
```

This writes `Matchly/Data/ERAS_PAR_specialties.json`, bundled in the app.
ACGME-only programs not listed on ERAS fall back to the ACGME specialty-code
hierarchy.

### Option B — script downloads PDFs (polite rate limit)

```bash
python build_from_reports.py \
  --fetch-reports \
  --download-dir ./report_pdfs \
  --output ../../Data/ACGME_2026.json \
  --delay 3
```

Use `--limit 5` to test on a handful first. ~188 specialties × 3s ≈ 10 minutes total.

---

## Saved search pages (Web Archive)

```bash
cd Matchly/scripts/acgme
pip install -r acgme-requirements.txt
```

### 1. Export search results (one file per specialty)

1. Open https://apps.acgme.org/ads/Public/Programs/Search
2. Search by specialty (e.g. Allergy and Immunology)
3. **File → Save As… → Format: Web Archive**
4. Save into a folder, e.g. `~/Desktop/ACGME/Allergy and Immunology/`
5. Repeat for each specialty

Your Desktop folder with two specialties is exactly the right shape.

### 2. Build JSON (list fields only — no network)

```bash
python build_dataset.py \
  --search-dir ~/Desktop/ACGME \
  --output ../../Data/ACGME_sample.json
```

This gives you code, specialty, name, and city for every program in the exports.

### 3. Enrich with detail pages (director, phone, email, address, accreditation)

```bash
python build_dataset.py \
  --search-dir ~/Desktop/ACGME \
  --output ../../Data/ACGME_2026.json \
  --fetch-details \
  --delay 2 \
  --cache-dir ./detail_cache \
  --manifest ../../Data/ACGME_manifest.json
```

- `--delay 2` — minimum 2 seconds between requests (be polite)
- `--cache-dir` — saves HTML so re-runs don't re-download
- The client **stops** if ACGME enables CAPTCHA blocking

### 4. Add to Matchly

Copy the output JSON into `Matchly/Data/` and add it to the Xcode target, or
wire up remote manifest loading (see `Documentation/ACGME_DATA_INTEGRATION.md`).

## Output shape

Matches `ResidencyProgramInfo` in `ResidencyProgramDatabase.swift`:

- `id`, `accreditationID` = 10-digit ACGME org code (e.g. `0200121109`)
- `name`, `hospital`, `city`, `state`, `address`
- `websiteURL`, `contactEmail`, `contactPhone`, `programCoordinator`
- Extra ACGME fields (director, accreditation status, sites, …) for future UI

## Legal note

This is **public accreditation information**, not private applicant data. Still:

- Prefer manual exports + local parsing for bulk builds
- Use `--fetch-details` only at a polite rate, with an honest User-Agent
- Request the **official ACGME API** for production-scale updates when available

This is not legal advice — review ACGME's terms before large automated runs.

---

## Annual catalog refresh (recommended workflow)

Run this once per ERAS cycle (typically July) **before** shipping a new app build.
The bundled `ACGME_2026.json` is what the app searches at runtime — never hand-edit it.

```bash
cd Matchly/scripts/acgme
python3 sync_catalog.py
```

What this does:

1. Refreshes `ERAS_PAR_specialties.json` (residency vs fellowship classification)
2. Re-fetches `ERAS2026.json` from ERAS PAR (authoritative hospital names)
3. Re-runs `enrich_catalog.py` (merge ERAS → ACGME, campus enrichment, institution propagation)
4. Runs audits — **sync fails** if hospital-name quality regresses

Use `--skip-fetch` when ERAS was already fetched and you only need to re-enrich:

```bash
python3 sync_catalog.py --skip-fetch
```

### Quality gates

After enrichment, `audit_names.py` checks:

- **Corrupted** hospital strings (PDF scrape artifacts)
- **Vague** hospital names (generic 1–2 word names without campus)
- **ERAS mismatches** (catalog diverged from ERAS without a campus enrichment reason)

By default sync fails if more than **100** vague hospital names remain. Override only
when investigating:

```bash
python3 audit_names.py --max-vague 500
```

Check `ACGME_manifest.json` for stats:

```json
"enrichment": {
  "withCityState": 14069,
  "vagueHospitalRemaining": 44
}
```

### Ship to the app safely

1. Run `sync_catalog.py` and confirm audits pass
2. Commit updated `ACGME_2026.json`, `ACGME_manifest.json`, and `ERAS2026.json`
3. Bump manifest `version` in `enrich_catalog.py` if shipping a remote update
4. **Clean build** in Xcode so the new JSON is bundled
5. Smoke-test search: acronyms (`UCF`, `FSU`, `MGH`), full names, city, ACGME ID

### ERAS is authoritative

Hospital names come from ERAS when an accreditation ID matches. Enrichment may **add**
campus qualifiers to vague ERAS names (e.g. `Tulane University` → `Tulane University
(New Orleans)`) using sibling specialties at the same institution — but it will not
overwrite a complete ERAS name like `University of Central Florida/HCA Florida Healthcare
(Greater Orlando/Lake Monroe)`.

### Search aliases in the app

`ProgramSearchMatcher` derives acronyms from institution names and maps common nicknames
(`ucf`, `mgh`, `hopkins`) to full names. After catalog updates, acronym search works
automatically for `University of X` patterns; add nicknames to `queryAliases` only when
acronym derivation is insufficient.
