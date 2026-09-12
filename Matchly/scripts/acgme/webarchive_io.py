"""Read HTML from Safari .webarchive files or plain .html exports."""

from __future__ import annotations

import plistlib
from pathlib import Path


def read_html(path: Path) -> str:
    """Return UTF-8 HTML from a .webarchive, .html, or .htm file."""
    path = Path(path)
    suffix = path.suffix.lower()

    if suffix == ".webarchive":
        with path.open("rb") as f:
            archive = plistlib.load(f)
        data = archive["WebMainResource"]["WebResourceData"]
        if isinstance(data, bytes):
            return data.decode("utf-8", errors="replace")
        return str(data)

    if suffix in {".html", ".htm"}:
        return path.read_text(encoding="utf-8", errors="replace")

    raise ValueError(f"Unsupported file type: {path}")


def find_search_exports(root: Path) -> list[Path]:
    """Find saved ACGME search result pages under a folder tree."""
    root = Path(root)
    files: list[Path] = []
    for pattern in ("**/*.webarchive", "**/*.html", "**/*.htm"):
        files.extend(root.glob(pattern))
    return sorted(set(files))
