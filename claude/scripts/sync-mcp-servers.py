#!/usr/bin/env python3

import json
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: sync-mcp-servers.py <claude-json> <mcp-seed-json>", file=sys.stderr)
        return 2

    claude_json_path = Path(sys.argv[1]).expanduser()
    seed_path = Path(sys.argv[2]).expanduser()

    if claude_json_path.exists():
        claude_data = json.loads(claude_json_path.read_text())
    else:
        claude_data = {}

    seed_data = json.loads(seed_path.read_text())
    merged = dict(claude_data.get("mcpServers", {}))
    merged.update(seed_data.get("mcpServers", {}))
    claude_data["mcpServers"] = merged

    claude_json_path.write_text(json.dumps(claude_data, ensure_ascii=False, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
