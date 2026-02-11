#!/usr/bin/env bash
# PostToolUse: Edit/Write後にファイルを自動フォーマット
set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

EXT="${FILE_PATH##*.}"

case "$EXT" in
  js|jsx|ts|tsx|json|css|scss|html|md|yaml|yml)
    prettier --write "$FILE_PATH" >/dev/null 2>&1 || true
    ;;
  py)
    ruff format "$FILE_PATH" >/dev/null 2>&1 || true
    ;;
esac
