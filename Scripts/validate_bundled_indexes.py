#!/usr/bin/env python3
from __future__ import annotations

import datetime as dt
import json
import os
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def expected_iso_dates(start_year: int, end_year: int) -> list[str]:
    start = dt.date(start_year, 1, 1)
    end = dt.date(end_year, 12, 31)
    out: list[str] = []
    cursor = start
    while cursor <= end:
        out.append(cursor.isoformat())
        cursor += dt.timedelta(days=1)
    return out


def load_index(path: Path) -> dict:
    with path.open("rb") as f:
        return json.load(f)


def validate_index(path: Path) -> None:
    data = load_index(path)
    if not isinstance(data, dict):
        raise ValueError("Top-level JSON is not an object")

    metadata = data.get("metadata")
    dates = data.get("dates")
    if not isinstance(metadata, dict):
        raise ValueError("Missing or invalid `metadata` object")
    if not isinstance(dates, dict):
        raise ValueError("Missing or invalid `dates` object")

    start_year = int(metadata.get("startYear"))
    end_year = int(metadata.get("endYear"))

    expected = expected_iso_dates(start_year, end_year)
    expected_set = set(expected)
    actual_set = set(dates.keys())

    missing = sorted(expected_set - actual_set)
    extra = sorted(actual_set - expected_set)

    if missing or extra:
        message_parts: list[str] = []
        if missing:
            message_parts.append(f"missing {len(missing)} dates (e.g. {', '.join(missing[:5])})")
        if extra:
            message_parts.append(f"unexpected {len(extra)} dates (e.g. {', '.join(extra[:5])})")
        raise ValueError("; ".join(message_parts))

    if len(dates) != len(expected):
        raise ValueError(f"Expected {len(expected)} entries, found {len(dates)}")

    # Spot-check entry structure: the payload uses a per-day object that should
    # repeat the same ISO date as its key.
    for key in expected[:10]:
        entry = dates.get(key)
        if not isinstance(entry, dict):
            raise ValueError(f"Date entry {key} is not an object")
        if entry.get("date") != key:
            raise ValueError(f"Date entry {key} has mismatched `date` field")

    # Enforce “no gaps”: every date must have at least one matched format.
    missing_matches: list[str] = []
    for key in expected:
        entry = dates.get(key) or {}
        formats = entry.get("formats")
        if not isinstance(formats, dict) or len(formats) == 0:
            missing_matches.append(key)
    if missing_matches:
        raise ValueError(
            f"{len(missing_matches)} dates have no matches (e.g. {', '.join(missing_matches[:5])})"
        )


def main() -> int:
    # If a constant has missing dates, we can't ship it as a bundled option.
    # This script enforces “zero gaps” for every bundled number.
    #
    # Control which constants to validate via env var:
    #   PIDAY_BUNDLED_CONSTANTS=pi,planck
    # Defaults to validating the constants the app currently ships as selectable modes.
    constants_raw = os.environ.get("PIDAY_BUNDLED_CONSTANTS", "pi,tau,e,phi,planck")
    constants = [c.strip() for c in constants_raw.split(",") if c.strip()]

    targets: list[tuple[str, Path]] = []
    for c in constants:
        targets.append((f"iOS:{c}", ROOT / "PiDay" / "Resources" / f"{c}_2026_2035_index.json"))
        targets.append(
            (f"Android:{c}", ROOT / "PiDayAndroid" / "app" / "src" / "main" / "res" / "raw" / f"{c}_2026_2035_index.json")
        )

    # Website ships only the π demo index right now.
    targets.append(("Website:pi", ROOT / "website" / "src" / "data" / "pi_2026_2035_index.json"))

    failures: list[str] = []
    for label, path in targets:
        if not path.exists():
            failures.append(f"{label}: missing file ({path.as_posix()})")
            continue
        try:
            validate_index(path)
            print(f"✓ {label} ({path.name})")
        except Exception as exc:  # noqa: BLE001 - CLI tool, we want full coverage.
            failures.append(f"{label}: {exc}")

    if failures:
        print("\nBundled index validation failed:\n", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print("\nAll bundled indexes cover every date in their 10-year range.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
