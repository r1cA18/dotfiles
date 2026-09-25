#!/usr/bin/env python3
"""まさお氏の公開フィード（YouTube/note/Zenn）から新着を一覧表示する."""

import argparse
import json
import sys
from datetime import datetime, timezone
from html.parser import HTMLParser
from urllib.parse import urlparse

import feedparser


class _StripHTML(HTMLParser):
    def __init__(self):
        super().__init__()
        self.text = []

    def handle_data(self, data):
        self.text.append(data)

    def get_text(self):
        return "".join(self.text)


def strip_html(value: str) -> str:
    parser = _StripHTML()
    try:
        parser.feed(value or "")
        parser.close()
    except Exception:
        return value or ""
    return parser.get_text()


FEEDS = {
    "youtube": "https://www.youtube.com/feeds/videos.xml?channel_id=UCvHpETRVi1tXeRJoYiXHJqw",
    "note": "https://note.com/masa_wunder/rss",
    "zenn": "https://zenn.dev/aimasaou/feed",
}


def parse_date(value: str) -> datetime:
    # feedparser produces struct_time for some feeds; use its published_parsed if available.
    for fmt in ("%a, %d %b %Y %H:%M:%S %z", "%Y-%m-%dT%H:%M:%S%z"):
        try:
            return datetime.strptime(value, fmt)
        except ValueError:
            continue
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return datetime.min.replace(tzinfo=timezone.utc)


def fetch(source: str, limit: int, since: datetime | None):
    url = FEEDS[source]
    parsed = feedparser.parse(url)
    entries = []
    for entry in parsed.entries:
        title = entry.get("title", "(no title)")
        link = entry.get("link", "")
        when = None
        for key in ("published", "pubDate", "updated"):
            raw = entry.get(key)
            if raw:
                when = parse_date(raw)
                break
        if since and when and when < since:
            continue
        summary = ""
        for key in ("summary", "description"):
            raw = entry.get(key)
            if raw:
                summary = strip_html(raw).replace("\n", " ").strip()
                break
        # YouTube descriptions are huge; truncate aggressively.
        if source == "youtube" and len(summary) > 400:
            summary = summary[:400] + "…"
        elif len(summary) > 280:
            summary = summary[:280] + "…"
        entries.append({
            "source": source,
            "title": title,
            "link": link,
            "date": when.isoformat() if when else None,
            "summary": summary,
        })
    entries.sort(key=lambda e: e["date"] or "", reverse=True)
    return entries[:limit]


def main() -> int:
    parser = argparse.ArgumentParser(description="List recent posts from まさお's feeds.")
    parser.add_argument("--source", choices=["all", *FEEDS.keys()], default="all")
    parser.add_argument("--limit", type=int, default=15)
    parser.add_argument("--since", help="YYYY-MM-DD")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    args = parser.parse_args()

    since = None
    if args.since:
        since = datetime.strptime(args.since, "%Y-%m-%d").replace(tzinfo=timezone.utc)

    sources = list(FEEDS.keys()) if args.source == "all" else [args.source]
    results = []
    for src in sources:
        results.extend(fetch(src, args.limit, since))
    results.sort(key=lambda e: e["date"] or "", reverse=True)
    results = results[: args.limit]

    if args.json:
        print(json.dumps(results, ensure_ascii=False, indent=2))
        return 0

    for e in results:
        date = e["date"][:10] if e["date"] else "?"
        print(f"[{e['source']}] {date} {e['title']}")
        print(f"  {e['link']}")
        if e["summary"]:
            print(f"  {e['summary']}")
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
