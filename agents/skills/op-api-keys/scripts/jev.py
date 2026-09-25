#!/usr/bin/env python3
"""Minimal Jev (TypeSafe System One) CLI wrapper.

Reads TYPESAFE_API_KEY and optionally TYPESAFE_BASE_URL from the environment.
The API key should be injected by 1Password `op run` so that secrets never live
in shell history or process lists.
"""

import argparse
import json
import os
import sys
from typing import Any

import urllib.request
import urllib.error


def base_url() -> str:
    return os.environ.get("TYPESAFE_BASE_URL", "https://api.typesafe.ai").rstrip("/")


def api_key() -> str:
    key = os.environ.get("TYPESAFE_API_KEY", "")
    if not key:
        print(
            "error: TYPESAFE_API_KEY is not set. "
            "Run via 1Password: op run --env-file ~/.config/op/env/typesafe.env -- jev ...",
            file=sys.stderr,
        )
        sys.exit(1)
    return key


def request(method: str, path: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
    url = f"{base_url()}{path}"
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8") if payload else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {api_key()}")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        print(f"HTTP {exc.code}: {body}", file=sys.stderr)
        sys.exit(1)


def parse_question(arg: str) -> tuple[str, dict[str, Any]]:
    """Parse colon-delimited question definition.

    --noul  NAME:question[:true_label:false_label]
    --choice NAME:question:opt1:opt2:...
    --score  NAME:question:level1:level2:...
    """
    parts = arg.split(":")
    if len(parts) < 2:
        raise ValueError(f"question must be NAME:question...: {arg}")
    qid = parts[0]
    instructions = parts[1]
    rest = parts[2:]

    q: dict[str, Any] = {"instructions": instructions}
    return qid, q, rest


def build_noul(arg: str) -> tuple[str, dict[str, Any]]:
    qid, q, rest = parse_question(arg)
    q["type"] = "noul"
    if len(rest) == 2:
        q["criteria"] = {"true": rest[0], "false": rest[1]}
    return qid, q


def build_choice(arg: str) -> tuple[str, dict[str, Any]]:
    qid, q, rest = parse_question(arg)
    if len(rest) < 1:
        raise ValueError(f"--choice requires at least one option: {arg}")
    q["type"] = "choice"
    q["criteria"] = {opt: None for opt in rest}
    return qid, q


def build_score(arg: str) -> tuple[str, dict[str, Any]]:
    qid, q, rest = parse_question(arg)
    if len(rest) < 1:
        raise ValueError(f"--score requires at least one level: {arg}")
    q["type"] = "score"
    q["criteria"] = rest
    return qid, q


def cmd_ask(args: argparse.Namespace) -> int:
    questions: dict[str, dict[str, Any]] = {}
    for raw in args.noul or []:
        qid, q = build_noul(raw)
        questions[qid] = q
    for raw in args.choice or []:
        qid, q = build_choice(raw)
        questions[qid] = q
    for raw in args.score or []:
        qid, q = build_score(raw)
        questions[qid] = q

    if not questions:
        print("error: at least one of --noul/--choice/--score is required", file=sys.stderr)
        return 1

    payload = {
        "model": args.model,
        "state": args.state,
        "questions": questions,
    }
    result = request("POST", "/v1/systemone", payload)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def cmd_classify(args: argparse.Namespace) -> int:
    """Apply the same question set to many items."""
    items: list[str] = []
    if args.items:
        items = [s.strip() for s in args.items if s.strip()]
    elif args.file:
        items = [line.strip() for line in args.file if line.strip()]
    else:
        items = [line.strip() for line in sys.stdin if line.strip()]

    questions: dict[str, dict[str, Any]] = {}
    for raw in args.noul or []:
        qid, q = build_noul(raw)
        questions[qid] = q
    for raw in args.choice or []:
        qid, q = build_choice(raw)
        questions[qid] = q
    for raw in args.score or []:
        qid, q = build_score(raw)
        questions[qid] = q

    if not questions:
        print("error: at least one of --noul/--choice/--score is required", file=sys.stderr)
        return 1

    results = []
    for item in items:
        payload = {
            "model": args.model,
            "state": item,
            "questions": questions,
        }
        results.append({"state": item, "result": request("POST", "/v1/systemone", payload)})
    print(json.dumps(results, ensure_ascii=False, indent=2))
    return 0


def cmd_models(_args: argparse.Namespace) -> int:
    result = request("GET", "/v1/models")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Jev (TypeSafe System One) CLI")
    parser.add_argument("--model", default="jev-latest", help="Model id to use")
    sub = parser.add_subparsers(dest="command", required=True)

    ask = sub.add_parser("ask", help="Ask a question set about one state")
    ask.add_argument("state", help="State text to evaluate")
    ask.add_argument("--noul", action="append", help="NAME:question[:true_label:false_label]")
    ask.add_argument("--choice", action="append", help="NAME:question:opt1:opt2:...")
    ask.add_argument("--score", action="append", help="NAME:question:level1:level2:...")

    classify = sub.add_parser("classify", help="Apply the same questions to many items")
    classify.add_argument("--file", type=argparse.FileType("r"), help="File with one item per line")
    classify.add_argument("--items", nargs="+", help="Items to classify")
    classify.add_argument("--noul", action="append", help="NAME:question[:true_label:false_label]")
    classify.add_argument("--choice", action="append", help="NAME:question:opt1:opt2:...")
    classify.add_argument("--score", action="append", help="NAME:question:level1:level2:...")

    models = sub.add_parser("models", help="List available models")

    args = parser.parse_args(argv)
    if args.command == "ask":
        return cmd_ask(args)
    if args.command == "classify":
        return cmd_classify(args)
    if args.command == "models":
        return cmd_models(args)
    return 1


if __name__ == "__main__":
    sys.exit(main())
