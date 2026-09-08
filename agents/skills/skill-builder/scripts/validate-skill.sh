#!/usr/bin/env bash
# Compatibility entrypoint. Bun provides YAML parsing without extra packages.
set -euo pipefail
if ! command -v bun >/dev/null 2>&1; then
  echo "ERROR: bun is required to validate skills" >&2
  exit 2
fi
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec bun "$SCRIPT_DIR/validate-skill.ts" "$@"
