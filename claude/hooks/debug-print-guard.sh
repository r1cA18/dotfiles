#!/usr/bin/env bash
# PreToolUse: 単純なgit commitのstaged contentだけを確認する。
set -euo pipefail

exec python3 -c '
import json
import os
import re
import shlex
import subprocess
import sys

try:
    payload = json.load(sys.stdin)
    tokens = shlex.split(payload.get("tool_input", {}).get("command", ""))
except (ValueError, TypeError, AttributeError):
    sys.exit(0)
if not tokens or tokens.pop(0) != "git":
    sys.exit(0)
cwd = payload.get("cwd") or os.getcwd()
if not isinstance(cwd, str):
    sys.exit(0)
while tokens and tokens[0] == "-C":
    if len(tokens) < 2:
        sys.exit(0)
    cwd = os.path.abspath(os.path.join(cwd, tokens[1]))
    tokens = tokens[2:]
if not tokens or tokens[0] != "commit":
    sys.exit(0)
if any(token in ("&&", "||", ";", "|", "&", ">", "<") for token in tokens):
    sys.exit(0)

def git(*args):
    result = subprocess.run(["git", "-C", cwd, *args], capture_output=True)
    return result.stdout if result.returncode == 0 else b""

files = git("diff", "--cached", "--name-only", "-z", "--diff-filter=ACMR").split(b"\0")
warnings = []
for raw in files:
    if not raw:
        continue
    file = os.fsdecode(raw)
    extension = os.path.splitext(file)[1]
    pattern = (r"console\.(?:log|debug)\s*\(" if extension in (".js", ".jsx", ".ts", ".tsx")
               else r"^\s*print\s*\(" if extension == ".py" else None)
    if pattern and re.search(pattern, git("show", ":" + file).decode("utf-8", errors="replace"), re.M):
        warnings.append(file)
if warnings:
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "additionalContext": "Staged files contain print or console diagnostics; these may be intentional: " + ", ".join(warnings)
    }}))
'
