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
  --output ../../Data/ACGME_2026.json
```

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
