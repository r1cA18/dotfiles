#!/usr/bin/env bash
# PreToolUse: 秘密情報を含むファイルの編集をブロック
set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0

BASENAME=$(basename "$FILE_PATH")
BASENAME_LOWER=$(echo "$BASENAME" | tr '[:upper:]' '[:lower:]')

# .env.example 等のテンプレートファイルは許可
case "$BASENAME_LOWER" in
  *.example|*.sample|*.template) exit 0 ;;
esac

# ブロック対象パターン
case "$BASENAME_LOWER" in
  .env|.env.*|*.env)
    echo "BLOCKED: .envファイルの編集はブロックされた。秘密情報が含まれている可能性がある。"
    exit 2
    ;;
  credentials*|*credential*|*secret*|*.key|*.pem|id_rsa*|id_ed25519*)
    echo "BLOCKED: 秘密情報ファイルの編集はブロックされた: $BASENAME"
    exit 2
    ;;
esac

# パスに secrets/ や credentials/ を含む場合もブロック
case "$FILE_PATH" in
  */secrets/*|*/credentials/*|*/.ssh/*)
    echo "BLOCKED: 秘密情報ディレクトリ内のファイルの編集はブロックされた: $FILE_PATH"
    exit 2
    ;;
esac
