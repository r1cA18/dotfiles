#!/usr/bin/env python3
"""Claude trigger check. Failed/incomplete runs are never negative observations."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def check(prompt: str, skill: str) -> bool:
    for command in ("claude", "agent-skill-path"):
        if not shutil.which(command):
            raise ValueError(f"{command} not found on PATH")
    lookup = subprocess.run(["agent-skill-path", skill], capture_output=True, text=True, timeout=10)
    if lookup.returncode:
        raise ValueError("agent-skill-path failed; verify skill installation")
    skill_dir = Path(lookup.stdout.strip())
    if not lookup.stdout.strip() or not (skill_dir / "SKILL.md").is_file():
        raise ValueError("Installed SKILL.md not found; verify skill sync")
    duration = float(os.environ.get("SKILL_SMOKE_TIMEOUT", "30"))
    if not 0 < duration <= 300:
        raise ValueError("SKILL_SMOKE_TIMEOUT must be between 0 and 300 seconds")
    result = subprocess.run(
        ["claude", "-p", prompt, "--output-format", "stream-json", "--verbose",
         "--max-budget-usd", "0.05", "--allowedTools", "Skill,Read"],
        capture_output=True, text=True, timeout=duration,
    )
    if result.returncode:
        # Do not echo raw stderr: it may contain account/runtime details.
        raise ValueError(f"claude exited with status {result.returncode}; check CLI/authentication")
    events = [json.loads(line) for line in result.stdout.splitlines() if line.strip()]
    if not events or any(not isinstance(event, dict) for event in events):
        raise ValueError("Invalid or empty stream-json output")
    completed = False
    triggered = False
    for event in events:
        if event.get("type") == "result":
            if event.get("is_error") or event.get("subtype") != "success":
                raise ValueError("Claude run did not complete successfully")
            completed = True
        if event.get("type") != "assistant":
            continue
        for block in event.get("message", {}).get("content", []):
            if not isinstance(block, dict) or block.get("type") != "tool_use":
                continue
            arguments = block.get("input", {})
            if not isinstance(arguments, dict):
                continue
            if block.get("name") == "Skill" and arguments.get("skill") == skill:
                triggered = True
            if block.get("name") == "Read" and isinstance(arguments.get("file_path"), str):
                if Path(arguments["file_path"]).resolve() == (skill_dir / "SKILL.md").resolve():
                    triggered = True
    if not completed:
        raise ValueError("Missing successful completion event; result is inconclusive")
    return triggered


def main() -> int:
    if len(sys.argv) != 3:
        print("ERROR: Usage: trigger_smoke_test.sh '<prompt>' '<skill-name>'")
        return 2
    try:
        triggered = check(sys.argv[1], sys.argv[2])
    except (ValueError, OSError, subprocess.SubprocessError, TypeError, AttributeError) as error:
        reason = "Claude run timed out" if isinstance(error, subprocess.TimeoutExpired) else str(error)
        print(f"ERROR: {reason}")
        return 2
    print(f"{'TRIGGERED' if triggered else 'NOT_TRIGGERED'}: {sys.argv[2]}")
    return 0 if triggered else 1


if __name__ == "__main__":
    sys.exit(main())
