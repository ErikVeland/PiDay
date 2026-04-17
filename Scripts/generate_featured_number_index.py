#!/usr/bin/env python3

"""
Generate bundled calendar indexes for non-π featured numbers.

Output format intentionally matches PiDay/Core/Data/PiIndexPayload.swift so the app
can reuse the same decoding + lookup logic.

This script supports multiple strategies depending on the constant:
  - e / phi: query the Irrational Numbers Search Engine (pisearch.org)
  - tau: scan a local digits file using Aho–Corasick (requires pyahocorasick)
  - planck: generate digits of h in eV·s (exact rational) and scan with Aho–Corasick

NOTE: This is an offline data pipeline tool; it is not used at runtime.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from collections import deque
from pathlib import Path
from typing import Iterable, Optional

import requests


FORMATS: dict[str, str] = {
    "ddmmyyyy": "%d%m%Y",
    "mmddyyyy": "%m%d%Y",
    "yyyymmdd": "%Y%m%d",
}


def date_range(start_year: int, end_year: int) -> list[dt.date]:
    dates: list[dt.date] = []
    current = dt.date(start_year, 1, 1)
    end = dt.date(end_year + 1, 1, 1)
    while current < end:
        dates.append(current)
        current += dt.timedelta(days=1)
    return dates


def utc_now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def build_skeleton(start_year: int, end_year: int) -> dict:
    all_dates = date_range(start_year, end_year)
    return {
        current.isoformat(): {"date": current.isoformat(), "formats": {}}
        for current in all_dates
    }


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Generate a featured-number date index (2026–2035 style).")
    p.add_argument("--featured", choices=["tau", "e", "phi", "planck"], required=True)
    p.add_argument("--start-year", type=int, default=2026)
    p.add_argument("--end-year", type=int, default=2035)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--excerpt-radius", type=int, default=20)
    p.add_argument("--max-workers", type=int, default=6)
    p.add_argument(
        "--local-digits",
        type=int,
        default=None,
        help="Generate e/phi locally with mpmath instead of querying pisearch.org.",
    )

    # digits-file mode (tau)
    p.add_argument(
        "--digits-file",
        type=Path,
        default=None,
        help="Path to a plain-text file containing digits AFTER the decimal point.",
    )
    p.add_argument(
        "--tau-digits",
        type=int,
        default=10_000_000,
        help="How many digits of tau to generate locally when --digits-file is omitted.",
    )

    # planck mode
    p.add_argument(
        "--planck-digits",
        type=int,
        default=500_000_000,
        help="How many digits of Planck constant (h in eV·s mantissa fractional digits) to scan.",
    )

    return p.parse_args()


@dataclass(frozen=True)
class WorkItem:
    iso_date: str
    format_name: str
    query: str


def all_work_items(start_year: int, end_year: int) -> list[WorkItem]:
    items: list[WorkItem] = []
    for d in date_range(start_year, end_year):
        iso = d.isoformat()
        for fmt, pattern in FORMATS.items():
            items.append(WorkItem(iso_date=iso, format_name=fmt, query=d.strftime(pattern)))
    return items


# -------------------------
# pisearch.org (e / phi)
# -------------------------

PIS_ORG_ENDPOINT = "https://pisearch.org/e/pi.asp"


def pisearch_org_lookup(constant: str, query: str) -> Optional[tuple[int, str]]:
    """
    Returns (one_based_position_after_decimal, excerpt_digits) or None if not found.

    pisearch.org reports positions as "the Nth decimal digit", where N=1 means the
    first digit after the decimal point. That aligns with our bundled convention.
    """
    # `n` doesn't affect search excerpts; it's effectively required by the form.
    resp = requests.post(
        PIS_ORG_ENDPOINT,
        data={"s": query, "o": "searchdigits", "n": "2", "c": constant},
        timeout=30,
        headers={"User-Agent": "PiDayIndexBot/1.0"},
    )
    resp.raise_for_status()
    html = resp.text

    if "does not appear" in html.lower():
        return None

    m = re.search(
        r"appears at the\s+([0-9,]+)(?:st|nd|rd|th)\s+decimal digit",
        html,
        flags=re.IGNORECASE,
    )
    if not m:
        return None

    position = int(m.group(1).replace(",", ""))

    # Extract the fixed ~20-before + query + ~20-after snippet.
    snippet_match = re.search(r"<code><font size=4>(.*?)<br>", html, flags=re.IGNORECASE | re.DOTALL)
    if snippet_match:
        snippet_html = snippet_match.group(1)
        excerpt_digits = re.sub(r"[^0-9]", "", snippet_html)
    else:
        excerpt_digits = query

    return position, excerpt_digits


def generate_via_pisearch_org(featured: str, start_year: int, end_year: int, excerpt_radius: int, max_workers: int) -> dict:
    constant = "e" if featured == "e" else "phi"
    work = all_work_items(start_year, end_year)
    dates = build_skeleton(start_year, end_year)

    total = len(work)
    completed = 0

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_map = {executor.submit(pisearch_org_lookup, constant, item.query): item for item in work}
        for future in as_completed(future_map):
            item = future_map[future]
            match = future.result()
            if match is not None:
                position, excerpt = match
                dates[item.iso_date]["formats"][item.format_name] = {
                    "query": item.query,
                    "position": position,
                    "excerpt": excerpt,
                }
            completed += 1
            if completed % 200 == 0 or completed == total:
                print(f"[{completed}/{total}] {item.iso_date} {item.format_name}", file=sys.stderr, flush=True)

    found_dates = sum(1 for record in dates.values() if record["formats"])
    return {
        "metadata": {
            "startYear": start_year,
            "endYear": end_year,
            "indexing": "one_based_after_decimal",
            "excerptRadius": excerpt_radius,
            "generatedAt": utc_now_iso(),
            "source": PIS_ORG_ENDPOINT,
            "featured": featured,
            "notes": "Positions + excerpts sourced from pisearch.org",
        },
        "dates": dict(sorted(dates.items())),
        "summary": {"totalDates": len(dates), "foundDates": found_dates},
    }


# -------------------------
# Local digit scanning (tau / planck)
# -------------------------

def build_query_map(items: Iterable[WorkItem]) -> tuple[dict[str, list[WorkItem]], int]:
    query_map: dict[str, list[WorkItem]] = {}
    max_len = 0
    for item in items:
        query_map.setdefault(item.query, []).append(item)
        max_len = max(max_len, len(item.query))
    return query_map, max_len


def generate_tau_or_local_digits(
    featured: str,
    digits_iter: Iterable[str],
    start_year: int,
    end_year: int,
    excerpt_radius: int,
    searched_digits: int,
    source_label: str,
) -> dict:
    items = all_work_items(start_year, end_year)
    query_map, window_len = build_query_map(items)

    dates = build_skeleton(start_year, end_year)
    found: set[tuple[str, str]] = set()
    window: deque[str] = deque(maxlen=window_len)

    # All supported date formats are fixed-width 8-digit queries, so a rolling window
    # is simpler and more reliable here than an incremental automaton.
    for idx, ch in enumerate(digits_iter, start=1):
        if idx > searched_digits:
            break
        window.append(ch)
        if len(window) < window_len:
            continue

        query = "".join(window)
        matched_items = query_map.get(query)
        if matched_items:
            position = idx - window_len + 1
            for item in matched_items:
                item_key = (item.iso_date, item.format_name)
                if item_key in found:
                    continue
                dates[item.iso_date]["formats"][item.format_name] = {
                    "query": item.query,
                    "position": position,
                    "excerpt": item.query,
                }
                found.add(item_key)

        if len(found) == len(items):
            break

        if idx % 5_000_000 == 0:
            print(f"[scan] {idx:,}/{searched_digits:,} digits, found {len(found):,}/{len(items):,} queries", file=sys.stderr, flush=True)

    found_dates = sum(1 for record in dates.values() if record["formats"])
    return {
        "metadata": {
            "startYear": start_year,
            "endYear": end_year,
            "indexing": "one_based_after_decimal",
            "excerptRadius": excerpt_radius,
            "generatedAt": utc_now_iso(),
            "source": source_label,
            "featured": featured,
            "searchedDigits": searched_digits,
            "notes": "Excerpts are query-only for generated streams.",
        },
        "dates": dict(sorted(dates.items())),
        "summary": {"totalDates": len(dates), "foundDates": found_dates, "foundQueries": len(found), "totalQueries": len(items)},
    }


def generate_from_digits_file(
    featured: str,
    digits_file: Path,
    start_year: int,
    end_year: int,
    excerpt_radius: int,
) -> dict:
    import mmap

    if not digits_file.exists():
        raise SystemExit(f"digits file not found: {digits_file}")

    # Memory-map the file for fast random access.
    with digits_file.open("rb") as f:
        mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)

        items = all_work_items(start_year, end_year)
        query_map, window_len = build_query_map(items)
        dates = build_skeleton(start_year, end_year)
        found: set[tuple[str, str]] = set()
        window: deque[str] = deque(maxlen=window_len)

        # Scan digits, skipping non-digit bytes (newlines, spaces).
        digit_index = 0  # 1-based after decimal, counts only '0'..'9'
        for b in iter(lambda: mm.read(1024 * 1024), b""):
            for byte in b:
                if 48 <= byte <= 57:
                    digit_index += 1
                    ch = chr(byte)
                    window.append(ch)
                    if len(window) < window_len:
                        continue

                    query = "".join(window)
                    matched_items = query_map.get(query)
                    if matched_items:
                        position = digit_index - window_len + 1
                        for item in matched_items:
                            item_key = (item.iso_date, item.format_name)
                            if item_key in found:
                                continue
                            # Extract excerpt (best-effort) from the memory map. For now we store
                            # query-only excerpts because the input file may include separators.
                            dates[item.iso_date]["formats"][item.format_name] = {
                                "query": item.query,
                                "position": position,
                                "excerpt": item.query,
                            }
                            found.add(item_key)

                    if len(found) == len(items):
                        break
            if len(found) == len(items):
                break

            if digit_index % 5_000_000 == 0:
                print(f"[scan] {digit_index:,} digits, found {len(found):,}/{len(items):,} queries", file=sys.stderr, flush=True)

        found_dates = sum(1 for record in dates.values() if record["formats"])
        return {
            "metadata": {
                "startYear": start_year,
                "endYear": end_year,
                "indexing": "one_based_after_decimal",
                "excerptRadius": excerpt_radius,
                "generatedAt": utc_now_iso(),
                "source": str(digits_file),
                "featured": featured,
                "notes": "File-scanned index. Excerpts currently store query-only (see script comments).",
            },
            "dates": dict(sorted(dates.items())),
            "summary": {"totalDates": len(dates), "foundDates": found_dates, "foundQueries": len(found), "totalQueries": len(items)},
        }


def planck_digit_stream() -> Iterable[str]:
    """
    Digits of Planck constant h in eV·s mantissa fractional digits.

    Uses the exact SI values:
      h = 6.62607015e-34 J*s (exact)
      1 eV = 1.602176634e-19 J (exact)

    Therefore h in eV*s is:
      (6.62607015 / 1.602176634) * 1e-15  eV*s

    We drop the exponent and treat the mantissa's fractional digits as the digit stream.
    """
    # Exact rational mantissa:
    # (662607015/10^8) / (1602176634/10^9) = 6626070150 / 1602176634
    numerator = 6_626_070_150
    denominator = 1_602_176_634

    # Fractional part remainder after removing the integer part.
    remainder = numerator % denominator

    while True:
        remainder *= 10
        digit = remainder // denominator
        remainder = remainder % denominator
        yield str(digit)


def irrational_digit_stream(
    constant: str,
    searched_digits: int,
    chunk_digits: Optional[int] = None,
) -> Iterable[str]:
    """
    Digits of an irrational constant after the decimal point.

    We generate these locally with mpmath in chunks so the featured-number pipeline
    can fall back to offline generation when a remote source is unavailable.
    """
    from mpmath import mp
    from mpmath.libmp import to_digits_exp

    if chunk_digits is None:
        # For our current bundle sizes, generating the full decimal expansion once
        # is much faster than recomputing the prefix at higher precision for many
        # smaller chunks.
        chunk_digits = searched_digits

    emitted = 0
    while emitted < searched_digits:
        current_chunk = min(chunk_digits, searched_digits - emitted)
        mp.dps = emitted + current_chunk + 100
        if constant == "tau":
            value = 2 * mp.pi
        elif constant == "e":
            value = mp.e
        elif constant == "phi":
            value = (1 + mp.sqrt(5)) / 2
        else:
            raise ValueError(f"Unsupported irrational constant: {constant}")
        _, digits, exponent = to_digits_exp(value._mpf_, emitted + current_chunk + 50)
        if exponent != 0:
            raise RuntimeError(f"Unexpected exponent for {constant}: {exponent}")
        fractional_digits = digits[1:]
        next_slice = fractional_digits[emitted:emitted + current_chunk]
        if len(next_slice) != current_chunk:
            raise RuntimeError(f"{constant} generation produced fewer digits than requested")
        yield from next_slice
        emitted += current_chunk


def main() -> int:
    args = parse_args()
    if args.end_year < args.start_year:
        raise SystemExit("--end-year must be >= --start-year")

    if args.featured in ("e", "phi"):
        if args.local_digits is not None:
            payload = generate_tau_or_local_digits(
                featured=args.featured,
                digits_iter=irrational_digit_stream(args.featured, args.local_digits),
                start_year=args.start_year,
                end_year=args.end_year,
                excerpt_radius=args.excerpt_radius,
                searched_digits=args.local_digits,
                source_label=f"generated locally with mpmath ({args.featured})",
            )
        else:
            payload = generate_via_pisearch_org(
                featured=args.featured,
                start_year=args.start_year,
                end_year=args.end_year,
                excerpt_radius=args.excerpt_radius,
                max_workers=min(max(args.max_workers, 1), 6),
            )
    elif args.featured == "tau":
        if args.digits_file is not None:
            payload = generate_from_digits_file(
                featured="tau",
                digits_file=args.digits_file,
                start_year=args.start_year,
                end_year=args.end_year,
                excerpt_radius=args.excerpt_radius,
            )
        else:
            payload = generate_tau_or_local_digits(
                featured="tau",
                digits_iter=irrational_digit_stream("tau", args.tau_digits),
                start_year=args.start_year,
                end_year=args.end_year,
                excerpt_radius=args.excerpt_radius,
                searched_digits=args.tau_digits,
                source_label="generated locally with mpmath (tau = 2π)",
            )
    elif args.featured == "planck":
        payload = generate_tau_or_local_digits(
            featured="planck",
            digits_iter=planck_digit_stream(),
            start_year=args.start_year,
            end_year=args.end_year,
            excerpt_radius=args.excerpt_radius,
            searched_digits=args.planck_digits,
            source_label="generated (exact rational: h in eV·s mantissa)",
        )
    else:
        raise SystemExit(f"Unsupported featured: {args.featured}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Wrote {args.output}", file=sys.stderr, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
