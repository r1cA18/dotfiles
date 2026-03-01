#!/bin/bash
# UserPromptSubmit hook: auto-name session from first prompt
# Creates state file with first ~10 chars of the prompt text
# Skips if already named (auto or manual)

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')

[ -z "$SESSION_ID" ] && exit 0
[ -z "$PROMPT" ] && exit 0

STATE_FILE="/tmp/cc-status-${SESSION_ID}.json"

# Already named? Skip.
if [ -f "$STATE_FILE" ]; then
  exit 0
fi

# Extract first ~10 characters, strip control chars and quotes
SHORT_NAME=$(echo "$PROMPT" | tr -d '\n\r"\\' | awk '{print substr($0, 1, 10)}' | sed 's/ *$//')

[ -z "$SHORT_NAME" ] && exit 0

printf '{"name":"%s","source":"auto"}\n' "$SHORT_NAME" > "$STATE_FILE"
