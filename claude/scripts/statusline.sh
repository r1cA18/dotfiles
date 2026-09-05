#!/usr/bin/env bash

set -uo pipefail

payload=$(cat)
fields=$(printf '%s' "$payload" | jq -r '
  def value: if . == null then "-" else . end;
  [
    ((.workspace.current_dir // .cwd) | value),
    (.model.display_name | value),
    (.effort.level | value),
    (.context_window.used_percentage | value),
    (.session_name | value)
  ] | @tsv
' 2>/dev/null) || exit 0
[[ -n "$fields" ]] || exit 0

IFS=$'\t' read -r cwd model effort context_used session_name <<< "$fields"

if [[ -n "${CLAUDE_CONFIG_DIR:-}" ]]; then
  profile=${CLAUDE_CONFIG_DIR##*/}
  metadata_file="$CLAUDE_CONFIG_DIR/.claude.json"
  expected_email=$profile
else
  profile=default
  metadata_file="$HOME/.claude.json"
  expected_email=
fi

actual_email=
if [[ -f "$metadata_file" ]]; then
  actual_email=$(jq -r '.oauthAccount.emailAddress // empty' "$metadata_file" 2>/dev/null || true)
fi

if [[ "${ANTHROPIC_BASE_URL:-}" == "http://127.0.0.1:18765" ]]; then
  account="gpt profile $profile"
elif [[ -n "$actual_email" && "$expected_email" == *@* && "$actual_email" != "$expected_email" ]]; then
  account="MISMATCH $expected_email -> $actual_email"
elif [[ -n "$actual_email" ]]; then
  account=$actual_email
elif [[ -n "$expected_email" ]]; then
  account="$expected_email (not logged in)"
else
  account="default (not logged in)"
fi

directory=$cwd
if [[ "$directory" == "$HOME" || "$directory" == "$HOME/"* ]]; then
  directory="~${directory#"$HOME"}"
fi

branch=$(git -C "$cwd" branch --show-current 2>/dev/null || true)
if [[ -z "$branch" ]]; then
  branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null || true)
fi

parts=("$account")
[[ "$model" != "-" ]] && parts+=("$model")
[[ "$effort" != "-" ]] && parts+=("effort $effort")
[[ "$context_used" != "-" ]] && parts+=("context ${context_used}%")
parts+=("$directory")
[[ -n "$branch" ]] && parts+=("$branch")
[[ "$session_name" != "-" ]] && parts+=("$session_name")

printf '%s\n' "$(IFS=' | '; printf '%s' "${parts[*]}")"
