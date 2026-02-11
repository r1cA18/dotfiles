#!/usr/bin/env bash
# PostToolUse: 過剰装飾のprint/log文を検出して警告
set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

EXT="${FILE_PATH##*.}"

case "$EXT" in
  py)
    # Python: 装飾的なprint文を検出（=== や --- や *** を含むprint）
    if grep -nE 'print\(.*[=\-\*]{3,}' "$FILE_PATH" 2>/dev/null; then
      echo "WARNING: 過剰に装飾されたprint文が検出された。シンプルなデバッグ出力にすること。"
    fi
    ;;
  js|jsx|ts|tsx)
    # JS/TS: 装飾的なconsole.log文を検出
    if grep -nE 'console\.(log|info|warn)\(.*[=\-\*]{3,}' "$FILE_PATH" 2>/dev/null; then
      echo "WARNING: 過剰に装飾されたconsole.log文が検出された。シンプルなデバッグ出力にすること。"
    fi
    ;;
esac
