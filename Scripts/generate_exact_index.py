#!/usr/bin/env python3

import argparse
import datetime as dt
import json
import sys
import time
import urllib.parse
import urllib.request
from urllib.error import HTTPError
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Dict, Optional


SEARCH_URL = "https://v2.api.pisearch.joshkeegan.co.uk/api/v1/Lookup"
CONTEXT_URL = "https://api.pi.delivery/v1/pi"
SEARCHED_DIGITS = 5_000_000_000
MAX_WORKERS = 10
CONTEXT_WORKERS = 2
MAX_ATTEMPTS = 8
BATCH_SIZE = 120
EXCERPT_RADIUS = 496
FORMATS = {
    "ddmmyyyy": "%d%m%Y",
    "mmddyyyy": "%m%d%Y",
    "yyyymmdd": "%Y%m%d",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate an exact pi date index.")
    parser.add_argument("--start-year", type=int, default=2026)
    parser.add_argument("--end-year", type=int, default=2035)
    parser.add_argument("--excerpt-radius", type=int, default=EXCERPT_RADIUS)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("/Users/veland/PiDay/PiDay/Resources/pi_2026_2035_index.json"),
    )
    parser.add_argument(
        "--refresh-excerpts-from",
        type=Path,
        default=None,
        help="Refresh excerpts in an existing index using exact digits from pi.delivery.",
    )
    return parser.parse_args()


def search_pi(query: str) -> Optional[Dict]:
    params = urllib.parse.urlencode(
        {
            "namedDigits": "pi",
            "find": query,
            "resultId": 0,
        }
    )
    request = urllib.request.Request(
        f"{SEARCH_URL}?{params}",
        headers={"User-Agent": "Mozilla/5.0"},
    )

    with urllib.request.urlopen(request, timeout=30) as response:
        data = json.load(response)

    if data.get("numResults", 0) == 0:
        return None

    return {
        "query": query,
        "position": int(data["resultStringIdx"]) + 1,
    }


def search_pi_with_retry(query: str) -> Optional[Dict]:
    last_error = None
    for attempt in range(MAX_ATTEMPTS):
        try:
            return search_pi(query)
        except Exception as error:
            last_error = error
            if attempt == MAX_ATTEMPTS - 1:
                raise

    raise last_error  # pragma: no cover


def fetch_exact_excerpt(position: int, query: str, excerpt_radius: int) -> str:
    start = max(1, position - excerpt_radius)
    number_of_digits = len(query) + excerpt_radius * 2
    params = urllib.parse.urlencode(
        {
            "start": start,
            "numberOfDigits": number_of_digits,
        }
    )
    request = urllib.request.Request(
        f"{CONTEXT_URL}?{params}",
        headers={"User-Agent": "Mozilla/5.0"},
    )

    with urllib.request.urlopen(request, timeout=30) as response:
        data = json.load(response)

    content = data["content"]
    target_offset = min(excerpt_radius, position - 1)
    if content[target_offset:target_offset + len(query)] != query:
        raise ValueError(f"Context mismatch for {query} at position {position}")
    return content


def fetch_exact_excerpt_with_retry(position: int, query: str, excerpt_radius: int) -> str:
    last_error = None
    for attempt in range(MAX_ATTEMPTS):
        try:
            return fetch_exact_excerpt(position, query, excerpt_radius)
        except HTTPError as error:
            last_error = error
            if error.code == 429:
                time.sleep(8 * (attempt + 1))
            else:
                time.sleep(2 * (attempt + 1))
            if attempt == MAX_ATTEMPTS - 1:
                raise
        except Exception as error:
            last_error = error
            time.sleep(1.5 * (attempt + 1))
            if attempt == MAX_ATTEMPTS - 1:
                raise

    raise last_error  # pragma: no cover


def date_range(start_year: int, end_year: int) -> list[dt.date]:
    dates: list[dt.date] = []
    current = dt.date(start_year, 1, 1)
    end = dt.date(end_year + 1, 1, 1)
    while current < end:
        dates.append(current)
        current += dt.timedelta(days=1)
    return dates


def generate(start_year: int, end_year: int, excerpt_radius: int) -> dict:
    all_dates = date_range(start_year, end_year)
    total_queries = len(all_dates) * len(FORMATS)
    dates: dict[str, dict] = {
        current.isoformat(): {
            "date": current.isoformat(),
            "formats": {},
        }
        for current in all_dates
    }

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        future_map = {
            executor.submit(search_pi_with_retry, current.strftime(pattern)): (current, format_name)
            for current in all_dates
            for format_name, pattern in FORMATS.items()
        }

        completed = 0
        for future in as_completed(future_map):
            current, format_name = future_map[future]
            iso_date = current.isoformat()
            match = future.result()

            if match is not None:
                match["excerpt"] = fetch_exact_excerpt_with_retry(match["position"], match["query"], excerpt_radius)
                dates[iso_date]["formats"][format_name] = match

            completed += 1
            print(f"[{completed}/{total_queries}] {iso_date} {format_name}", file=sys.stderr, flush=True)

    found_dates = sum(1 for record in dates.values() if record["formats"])

    return {
        "metadata": {
            "startYear": start_year,
            "endYear": end_year,
            "indexing": "one_based_after_decimal",
            "excerptRadius": excerpt_radius,
            "generatedAt": dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z"),
            "source": "https://pisearch.joshkeegan.co.uk/",
            "matchFormats": sorted(FORMATS.keys()),
            "matchRule": "Exact substring search in the first 5 billion digits of pi",
            "searchedDigits": SEARCHED_DIGITS,
            "totalDates": len(all_dates),
            "foundDates": found_dates,
        },
        "dates": dict(sorted(dates.items())),
    }


def refresh_excerpts(existing_path: Path, excerpt_radius: int, output_path: Path) -> dict:
    payload = json.loads(existing_path.read_text(encoding="utf-8"))
    work_items = [
        (iso_date, format_name, match["position"], match["query"])
        for iso_date, record in payload["dates"].items()
        for format_name, match in record["formats"].items()
        if len(match.get("excerpt", "")) < (excerpt_radius * 2 + len(match["query"]))
    ]

    completed = 0
    for offset in range(0, len(work_items), BATCH_SIZE):
        batch = work_items[offset:offset + BATCH_SIZE]
        with ThreadPoolExecutor(max_workers=CONTEXT_WORKERS) as executor:
            future_map = {
                executor.submit(fetch_exact_excerpt_with_retry, position, query, excerpt_radius): (iso_date, format_name)
                for iso_date, format_name, position, query in batch
            }

            for future in as_completed(future_map):
                iso_date, format_name = future_map[future]
                payload["dates"][iso_date]["formats"][format_name]["excerpt"] = future.result()
                completed += 1
                print(f"[{completed}/{len(work_items)}] refreshed {iso_date} {format_name}", file=sys.stderr, flush=True)

        payload["metadata"]["excerptRadius"] = excerpt_radius
        payload["metadata"]["generatedAt"] = dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")
        output_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    payload["metadata"]["excerptRadius"] = excerpt_radius
    payload["metadata"]["generatedAt"] = dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")
    return payload


def main() -> int:
    args = parse_args()
    if args.end_year < args.start_year:
        raise SystemExit("--end-year must be greater than or equal to --start-year")

    if args.refresh_excerpts_from is not None:
        output = refresh_excerpts(args.refresh_excerpts_from, args.excerpt_radius, args.output)
    else:
        output = generate(args.start_year, args.end_year, args.excerpt_radius)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Wrote {args.output}", file=sys.stderr, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
