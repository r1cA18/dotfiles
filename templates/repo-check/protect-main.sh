#!/usr/bin/env bash
# Create or update the "main" ruleset of a repository from main-ruleset.json.
#
#   protect-main.sh <owner>/<repo> [required-check]...
#
# Each required check is a check run name, such as "check / check" for the
# reusable workflow. Name only checks that already run on the default branch;
# a required check that never reports blocks every merge. Without checks the
# required_status_checks rule is left out.
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: protect-main.sh <owner>/<repo> [required-check]..." >&2
  exit 2
fi
repo=$1
shift

template="$(dirname "$0")/main-ruleset.json"
body=$(jq --args '
  if ($ARGS.positional | length) == 0 then
    .rules |= map(select(.type != "required_status_checks"))
  else
    (.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks) =
      [$ARGS.positional[] | { context: . }]
  end
' "$@" <"$template")

id=$(gh api "repos/$repo/rulesets" --jq '.[] | select(.name == "main") | .id')
if [ -n "$id" ]; then
  printf '%s' "$body" | gh api -X PUT "repos/$repo/rulesets/$id" --input - --jq '{id, name, enforcement}'
else
  printf '%s' "$body" | gh api -X POST "repos/$repo/rulesets" --input - --jq '{id, name, enforcement}'
fi
