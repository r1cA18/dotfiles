#!/usr/bin/env bash
# PreToolUse: 巨大ファイルの書き込みを警告
set -euo pipefail

INPUT=$(cat)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
[ -z "$CONTENT" ] && exit 0

# 50KB以上で警告
SIZE=${#CONTENT}
THRESHOLD=51200

if [ "$SIZE" -gt "$THRESHOLD" ]; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // "unknown"')
  SIZE_KB=$((SIZE / 1024))
  echo "WARNING: ${SIZE_KB}KBの大きなファイルを書き込もうとしている ($FILE_PATH)。本当に必要か確認すること。"
fi
