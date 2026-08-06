# AGENTS.md

## Cursor Cloud specific instructions

### What can and cannot run here

Matchly is a native **iOS / SwiftUI app** (`Matchly.xcodeproj`) that also uses
Firebase/Firestore. Building or running the app requires **macOS + Xcode**, so
the app itself **cannot be built or run on the Linux Cloud VM** (no Swift/Xcode
toolchain is present). Do not attempt `xcodebuild`/`swift build` here.

The part of this repo that is developable/testable on Linux is the **Python
data-processing toolchain** in `Matchly/scripts/`. These scripts scrape and
build the ERAS/ACGME residency-program datasets (`Matchly/Data/*.json`) that are
bundled into the iOS app, and audit the residency/fellowship classification
logic that mirrors the Swift `ResidencyProgramDatabase` code.

### Python environment

- Dependencies live in `Matchly/scripts/requirements.txt` and
  `Matchly/scripts/acgme/acgme-requirements.txt`. They are installed into a
  virtualenv at repo root (`.venv/`) by the startup update script.
- Run scripts with the venv interpreter, e.g. `.venv/bin/python <script>.py`
  (or activate with `source .venv/bin/activate`). System `pip install` is
  blocked by PEP 668 on this Ubuntu image — always use the venv.
- The `.venv/` is git-ignored and rebuilt by the update script; it is not
  committed.

### Running / testing the data toolchain (offline, no network)

These operate on the committed datasets in `Matchly/Data/` and are the best
"does my environment work" checks. Run from `Matchly/scripts/`:

- `.venv/bin/python audit_training_levels.py` — validates residency vs
  fellowship classification across the full ~14k-program ACGME catalog; exits
  non-zero on classification conflicts.
- `.venv/bin/python audit_specialty_filters.py` — audits specialty filter
  matching logic; exits non-zero on false positives.
- `.venv/bin/python eras_data_extractor.py --template` then
  `.venv/bin/python eras_data_extractor.py <input.csv> <output.json>` — the
  CSV→JSON dataset build/convert step.

### Scrapers require network + Chrome (may be blocked)

Scripts like `eras_automated_scraper.py`, `eras_selenium_scraper.py`, and the
`acgme/` fetch/report scripts hit external sites (AAMC/ACGME) and may need
`chromedriver`. They can fail due to egress restrictions or site
anti-automation; prefer the offline audit/convert scripts above for validation.
There are no automated unit tests or linters configured — the `audit_*.py`
scripts serve as the de-facto test/validation suite.
