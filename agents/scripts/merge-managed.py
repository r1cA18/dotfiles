#!/usr/bin/env python3
"""Merge the keys Home Manager manages into a client's writable config file.

Claude Code and Codex rewrite their own config files (plugin installs, /model,
trust prompts), so Home Manager must not own those files. Instead each
activation merges the managed keys into the live file and leaves every other
key alone.

    merge-managed.py json|toml FILE FRAGMENT RECORD

FRAGMENT is a JSON file:

    {"set": {key: value, ...}, "entries": {section: {name: value, ...}, ...}}

- "set": top-level keys whose whole value Nix owns (theme, hooks, ...)
- "entries": named entries inside a section that Nix owns one by one
  (projects, marketplaces, ...); other entries of the same section stay

RECORD remembers which keys the previous run wrote, so a key removed from Nix
is removed from the file and a key Nix never wrote is never removed. A file
that cannot be parsed is left unchanged and the script exits 0 with a warning,
so activation never fails on drift.
"""

import copy
import json
import os
import sys
import tempfile
from pathlib import Path


def load(path: Path, fmt: str) -> dict:
    if not path.exists() or not path.read_text().strip():
        return {}
    text = path.read_text()
    if fmt == "toml":
        import tomllib

        return tomllib.loads(text)
    data = json.loads(text)
    if not isinstance(data, dict):
        raise ValueError("not an object")
    return data


def dump(data: dict, fmt: str) -> str:
    if fmt == "toml":
        import tomli_w

        return tomli_w.dumps(data)
    return json.dumps(data, ensure_ascii=False, indent=2) + "\n"


def write_atomic(path: Path, text: str) -> None:
    mode = path.stat().st_mode & 0o777 if path.exists() else 0o644
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    with os.fdopen(fd, "w") as handle:
        handle.write(text)
    os.chmod(tmp, mode)
    os.replace(tmp, path)


def main() -> int:
    if len(sys.argv) != 5 or sys.argv[1] not in ("json", "toml"):
        print(__doc__, file=sys.stderr)
        return 2
    fmt, target, fragment_path, record_path = sys.argv[1], *map(Path, sys.argv[2:])
    target = target.expanduser()
    if target.is_symlink():
        real = target.resolve()
        if str(real).startswith("/nix/store/"):
            # An earlier generation linked it into the store: replace the link
            # with a writable copy, then merge into that.
            content = real.read_text() if real.exists() else ""
            target.unlink()
            target.write_text(content)
        else:
            target = real
    target.parent.mkdir(parents=True, exist_ok=True)
    try:
        data = load(target, fmt)
    except ValueError as error:
        print(f"merge-managed: {target} cannot be parsed ({error}); left unchanged", file=sys.stderr)
        return 0

    fragment = json.loads(fragment_path.read_text())
    try:
        previous = json.loads(record_path.read_text())
    except (OSError, json.JSONDecodeError):
        previous = {}
    old_set = set(previous.get("set", []))
    old_entries = {tuple(k) for k in previous.get("entries", [])}

    new_set = set(fragment.get("set", {}))
    new_entries = {(s, n) for s, names in fragment.get("entries", {}).items() for n in names}

    original = copy.deepcopy(data)
    for key in old_set - new_set:
        data.pop(key, None)
    for section, name in old_entries - new_entries:
        if isinstance(data.get(section), dict):
            data[section].pop(name, None)
            if not data[section]:
                data.pop(section)

    data.update(fragment.get("set", {}))
    for section, names in fragment.get("entries", {}).items():
        if not names:
            continue
        if not isinstance(data.get(section), dict):
            data[section] = {}
        data[section].update(names)

    if data != original or not target.exists():
        write_atomic(target, dump(data, fmt))
    record_path.parent.mkdir(parents=True, exist_ok=True)
    record = {"set": sorted(new_set), "entries": sorted([list(k) for k in new_entries])}
    write_atomic(record_path, json.dumps(record, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
