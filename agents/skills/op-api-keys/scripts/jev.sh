#!/usr/bin/env bash
# Jev CLI wrapper that injects the TypeSafe API key via 1Password.
# The actual secret lives in 1Password; this script only references its
# location through an env-file path.
set -euo pipefail

env_file="${OP_ENV_FILE:-$HOME/.config/op/env/typesafe.env}"

if [[ ! -f "$env_file" ]]; then
  echo "error: 1Password env file not found: $env_file" >&2
  echo "Create it with something like:" >&2
  echo "  TYPESAFE_API_KEY=op://<vault>/<item>/<field>" >&2
  exit 1
fi

if ! command -v op >/dev/null 2>&1; then
  echo "error: 1Password CLI (op) is not installed" >&2
  exit 1
fi

# Resolve the skill script path. agent-skill-path is provided by the dotfiles package set.
if ! script_path="$(agent-skill-path op-api-keys scripts/jev.py 2>/dev/null)"; then
  echo "error: could not find op-api-keys/scripts/jev.py via agent-skill-path" >&2
  exit 1
fi

exec op run --env-file "$env_file" -- python3 "$script_path" "$@"
