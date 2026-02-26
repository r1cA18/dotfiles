#!/usr/bin/env python3
"""Parse xctrace export XML and output a readable time profiler summary.

Usage:
    xctrace export --input recording.trace --xpath '/trace-toc/run/data/table' | python parse_profile.py
    xctrace export --input recording.trace --xpath '/trace-toc/run/data/table' | python parse_profile.py --top 30
    python parse_profile.py --input recording.trace
"""

import argparse
import subprocess
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from typing import Optional


def get_toc_xpath(trace_path: str) -> Optional[str]:
    """Get the XPath for the time profiler table from the trace TOC."""
    result = subprocess.run(
        ["xctrace", "export", "--input", trace_path, "--toc"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"Error reading TOC: {result.stderr}", file=sys.stderr)
        return None

    root = ET.fromstring(result.stdout)
    for table in root.iter("table"):
        schema = table.get("schema", "")
        if "time-profile" in schema.lower() or "time-sample" in schema.lower():
            run_num = "1"
            for parent in root.iter("run"):
                for child in parent:
                    if child == table or (child.tag == "data" and table in list(child)):
                        run_num = parent.get("number", "1")
                        break
            return f'/trace-toc/run[@number="{run_num}"]/data/table[@schema="{schema}"]'

    # Fallback: return first table
    for table in root.iter("table"):
        schema = table.get("schema", "")
        run_num = "1"
        return f'/trace-toc/run[@number="{run_num}"]/data/table[@schema="{schema}"]'

    return None


def parse_xml(xml_input: str) -> list[dict]:
    """Parse xctrace export XML into structured rows."""
    try:
        root = ET.fromstring(xml_input)
    except ET.ParseError:
        print("Error: Invalid XML input", file=sys.stderr)
        return []

    rows = []
    for row in root.iter("row"):
        entry = {}
        for col in row:
            tag = col.tag
            text = col.text or col.get("fmt", "") or ""
            # Handle weight/duration columns
            if (
                "weight" in tag.lower()
                or "duration" in tag.lower()
                or "time" in tag.lower()
            ):
                fmt = col.get("fmt", text)
                entry[tag] = fmt.strip() if fmt else text.strip()
            # Handle symbol/address columns
            elif (
                "symbol" in tag.lower()
                or "name" in tag.lower()
                or "address" in tag.lower()
            ):
                name = col.get("name", text)
                entry[tag] = name.strip() if name else text.strip()
            else:
                entry[tag] = text.strip()
        if entry:
            rows.append(entry)

    return rows


def aggregate_symbols(rows: list[dict], top_n: int) -> str:
    """Aggregate by symbol and format as readable text."""
    if not rows:
        return "No profiling data found."

    # Detect column names
    all_keys = set()
    for r in rows:
        all_keys.update(r.keys())

    weight_key = None
    symbol_key = None
    for k in all_keys:
        kl = k.lower()
        if "weight" in kl or "duration" in kl or "self-weight" in kl:
            if weight_key is None or "self" in kl:
                weight_key = k
        if "symbol" in kl or "name" in kl:
            if symbol_key is None or "symbol" in kl:
                symbol_key = k

    if not weight_key or not symbol_key:
        # Fallback: dump raw
        lines = ["Raw profiler data (could not detect columns):"]
        for r in rows[:top_n]:
            lines.append(str(r))
        return "\n".join(lines)

    # Aggregate
    symbol_weights = defaultdict(float)
    for r in rows:
        sym = r.get(symbol_key, "<unknown>")
        w = r.get(weight_key, "0")
        # Try to parse weight as number (ms, us, s)
        try:
            numeric = float("".join(c for c in w if c.isdigit() or c == "."))
        except ValueError:
            numeric = 0
        symbol_weights[sym] += numeric

    sorted_syms = sorted(symbol_weights.items(), key=lambda x: x[1], reverse=True)

    total = sum(v for _, v in sorted_syms) or 1
    lines = [
        f"Time Profiler Summary (top {top_n} hotspots)",
        f"{'=' * 60}",
        f"{'Weight':>10}  {'%':>6}  Symbol",
        f"{'-' * 10}  {'-' * 6}  {'-' * 40}",
    ]

    for sym, weight in sorted_syms[:top_n]:
        pct = (weight / total) * 100
        lines.append(f"{weight:>10.1f}  {pct:>5.1f}%  {sym}")

    lines.append(f"{'-' * 10}  {'-' * 6}  {'-' * 40}")
    lines.append(f"{total:>10.1f}  100.0%  TOTAL")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Parse xctrace Time Profiler export")
    parser.add_argument("--input", "-i", help="Path to .trace file (auto-exports)")
    parser.add_argument(
        "--top", "-n", type=int, default=20, help="Number of top symbols to show"
    )
    parser.add_argument(
        "--raw", action="store_true", help="Output raw parsed rows as text"
    )
    args = parser.parse_args()

    if args.input:
        xpath = get_toc_xpath(args.input)
        if not xpath:
            print("Error: Could not find time profiler table in trace", file=sys.stderr)
            sys.exit(1)
        result = subprocess.run(
            ["xctrace", "export", "--input", args.input, "--xpath", xpath],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            print(f"Error exporting trace: {result.stderr}", file=sys.stderr)
            sys.exit(1)
        xml_input = result.stdout
    else:
        xml_input = sys.stdin.read()

    rows = parse_xml(xml_input)

    if args.raw:
        for r in rows[: args.top]:
            print(r)
    else:
        print(aggregate_symbols(rows, args.top))


if __name__ == "__main__":
    main()
