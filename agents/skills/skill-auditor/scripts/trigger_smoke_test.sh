#!/usr/bin/env bash
# Claude-specific adapter; exit 0=triggered, 1=not triggered, 2=check failed.
set -euo pipefail
if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required" >&2
  exit 2
fi
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/trigger_smoke_test.py" "$@"
