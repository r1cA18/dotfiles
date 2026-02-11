#!/usr/bin/env bash
# PostToolUse: ソースコード変更後にテスト実行をリマインド
set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0

EXT="${FILE_PATH##*.}"

# ソースコードファイルのみ（テストファイル自体は除外）
case "$EXT" in
  py|js|jsx|ts|tsx|swift|go|rs)
    # テストファイル自体の編集は除外
    case "$FILE_PATH" in
      *test*|*spec*|*_test.*|*_spec.*) exit 0 ;;
    esac
    echo "REMINDER: ソースコードが変更された。関連するテストの実行を忘れずに。"
    ;;
esac
