#!/bin/bash
# trigger_smoke_test.sh - claude -p でスキルのトリガーを検証する
#
# Usage:
#   trigger_smoke_test.sh "<prompt>" "<skill-name>"
#
# Examples:
#   trigger_smoke_test.sh "動画をカットして" "video-editing"
#   trigger_smoke_test.sh "Build my iOS app" "swift-dev-toolkit"
#   trigger_smoke_test.sh "Pythonの型ヒント教えて" "video-editing"  # should NOT trigger
#
# Requirements:
#   - claude CLI on PATH
#   - Skill must be synced to ~/.claude/skills/
#
# Note: This is a best-effort script. The claude CLI API may change.
#       If this script stops working, check `claude --help` for current flags.

set -euo pipefail

PROMPT="${1:?Usage: trigger_smoke_test.sh '<prompt>' '<skill-name>'}"
SKILL_NAME="${2:?Usage: trigger_smoke_test.sh '<prompt>' '<skill-name>'}"

TIMEOUT=30

# Verify claude CLI is available
if ! command -v claude &>/dev/null; then
  echo "ERROR: claude CLI not found on PATH"
  exit 2
fi

# Verify skill exists
SKILL_DIR="$HOME/.claude/skills/${SKILL_NAME}"
if [ ! -d "$SKILL_DIR" ]; then
  echo "ERROR: Skill directory not found: ${SKILL_DIR}"
  echo "Have you run 'dr' to sync?"
  exit 2
fi

# Run claude -p with stream-json output and capture
# We look for the Skill tool being invoked with our skill name
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

# Run with timeout, capture stream-json output
timeout "$TIMEOUT" claude -p "$PROMPT" \
  --output-format stream-json \
  --max-budget-usd 0.05 \
  2>/dev/null > "$TMPFILE" || true

# Check if the skill was triggered
# In stream-json, a Skill tool use appears as a content_block with type "tool_use"
# and the skill name in the input
if grep -q "\"name\":\"Skill\"" "$TMPFILE" && grep -q "\"$SKILL_NAME\"" "$TMPFILE"; then
  echo "TRIGGERED: Skill '$SKILL_NAME' was invoked for prompt: $PROMPT"
  exit 0
fi

# Also check if the skill's SKILL.md was read directly (alternative trigger pattern)
if grep -q "\"name\":\"Read\"" "$TMPFILE" && grep -q "skills/${SKILL_NAME}/SKILL.md" "$TMPFILE"; then
  echo "TRIGGERED: Skill '$SKILL_NAME' was read for prompt: $PROMPT"
  exit 0
fi

echo "NOT_TRIGGERED: Skill '$SKILL_NAME' was not invoked for prompt: $PROMPT"
exit 1
