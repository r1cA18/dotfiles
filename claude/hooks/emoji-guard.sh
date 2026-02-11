#!/usr/bin/env bash
# PreToolUse: Edit/Writeで絵文字が含まれていたらブロック
set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

if [ "$TOOL" = "Edit" ]; then
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty')
elif [ "$TOOL" = "Write" ]; then
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
else
  exit 0
fi

[ -z "$CONTENT" ] && exit 0

if echo "$CONTENT" | node -e "
  let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
    if(/[\u{1F300}-\u{1FFFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]/u.test(d))process.exit(0);
    process.exit(1);
  });
" 2>/dev/null; then
  echo "BLOCKED: 絵文字が検出された。コード規約により絵文字は禁止。絵文字を削除してやり直すこと。"
  exit 2
fi
