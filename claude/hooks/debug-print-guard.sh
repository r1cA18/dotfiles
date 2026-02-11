#!/usr/bin/env bash
# PreToolUse: git commit前にステージされたファイルのdebug print残りをチェック
set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# git commitコマンド以外は無視
echo "$COMMAND" | grep -q 'git commit' || exit 0

WARNINGS=""

# ステージされたファイルをチェック
while IFS= read -r file; do
  [ ! -f "$file" ] && continue
  EXT="${file##*.}"
  case "$EXT" in
    js|jsx|ts|tsx)
      HITS=$(grep -n 'console\.log\|console\.debug' "$file" 2>/dev/null || true)
      [ -n "$HITS" ] && WARNINGS="${WARNINGS}${file}:\n${HITS}\n"
      ;;
    py)
      HITS=$(grep -n '^\s*print(' "$file" 2>/dev/null || true)
      [ -n "$HITS" ] && WARNINGS="${WARNINGS}${file}:\n${HITS}\n"
      ;;
  esac
done < <(git diff --cached --name-only 2>/dev/null)

if [ -n "$WARNINGS" ]; then
  echo "WARNING: コミット対象にdebug print文が残っている:"
  echo -e "$WARNINGS"
  echo "意図的なものでなければ削除してからコミットすること。"
fi
