"""Bounded developer cache cleanup and repository report. Default: dry-run."""

import argparse
from datetime import datetime
import fcntl
import hashlib
import json
import logging
from logging.handlers import RotatingFileHandler
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
from urllib.parse import urlsplit, urlunsplit

LOG = logging.getLogger("developer-cleanup")
GIB = 1024 ** 3
RETENTION = 7 * 86400
PRESSURE_RETENTION = 3 * 86400
LOW_FREE = 100 * GIB
TARGET_FREE = 150 * GIB
REPO_RETENTION = 30 * 86400
PRUNE = {".git", "node_modules", ".venv", ".direnv", "target", ".build",
         "DerivedData", "Pods", ".next", "__pycache__", ".local", ".device-lab"}
BUILDERS = {"cargo", ".cargo-wrapped", "rustc", ".rustc-wrapped", "rustdoc", ".rustdoc-wrapped"}


class Busy(Exception):
    pass


def run(command, cwd=None):
    LOG.info("RUN %s", shlex.join(map(str, command)))
    env = os.environ.copy()
    if command[0] == "docker":
        env = {key: value for key, value in env.items()
               if not key.startswith(("DOCKER_", "BUILDX_"))}
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=1800, check=True,
                            env=env, cwd=cwd)
    output = result.stdout
    if output:
        LOG.info("%s", re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", output[-8000:]).strip())
    return output


def inside(path, root):
    return path == root or root in path.parents


def protected(path):
    def matches(value):
        return "mobileandon" in re.sub(r"[^a-z0-9]", "", value.lower())
    try:
        return any(matches(part) for part in path.parts + path.resolve().parts)
    except (OSError, RuntimeError):
        return True


def git(path, *args):
    env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
    env.update(GIT_OPTIONAL_LOCKS="0", GIT_TERMINAL_PROMPT="0", GIT_NO_LAZY_FETCH="1")
    return subprocess.run(["git", "-c", "core.fsmonitor=false", "-C", str(path), *args], text=True,
                          capture_output=True, timeout=30, env=env)


def git_output(path, *args):
    result = git(path, *args)
    if result.returncode:
        raise RuntimeError("Cannot verify repository state")
    return result.stdout


def protected_project(path):
    if protected(path):
        return True
    common = git(path, "rev-parse", "--path-format=absolute", "--git-common-dir")
    if common.returncode or protected(Path(common.stdout.strip())):
        return True
    remotes = git(path, "config", "--get-regexp", r"remote\..*\.url")
    if remotes.returncode not in (0, 1):
        return True
    return "mobileandon" in re.sub(r"[^a-z0-9]", "", remotes.stdout.lower())


class Usage:
    def __init__(self, commands, paths, cwds):
        self.commands, self.paths, self.cwds = commands, paths, cwds
        self.open_parents = {parent for path in paths for parent in (path, *path.parents)}

    @classmethod
    def read(cls):
        ps = subprocess.run(["/bin/ps", "-U", str(os.getuid()), "-o", "pid=,comm="],
                            text=True, capture_output=True, check=True, timeout=15)
        commands = {}
        for line in ps.stdout.splitlines():
            pid, name = line.strip().split(None, 1)
            commands[pid] = Path(name).name
        opened = subprocess.run(["/usr/sbin/lsof", "-nP", "-a", "-u", str(os.getuid()),
                                 "-Fpcfn0"], capture_output=True, check=True, timeout=30)
        paths, cwds = set(), {}
        pid, descriptor = None, None
        for field in opened.stdout.split(b"\0"):
            field = field.lstrip(b"\n")
            if field.startswith(b"p"):
                pid, descriptor = field[1:].decode(), None
            elif field.startswith(b"f"):
                descriptor = field[1:].decode()
            elif field.startswith(b"n/"):
                path = Path(os.fsdecode(field[1:]).removesuffix(" (deleted)")).resolve()
                paths.add(path)
                if descriptor == "cwd":
                    cwds[pid] = path
        if any(name in BUILDERS and pid not in cwds for pid, name in commands.items()):
            raise Busy("Cannot locate the working directory of a Rust build")
        return cls(commands, paths, cwds)

    def busy(self, path):
        path = path.resolve()
        return (path in self.open_parents
                or any(self.commands.get(pid) in BUILDERS and inside(path, cwd)
                       for pid, cwd in self.cwds.items()))

    def running(self, command):
        return command in self.commands.values()


def old_tree(path, cutoff, renamed_root=None):
    """Fail closed on symlinks, unreadable entries, or recent file/directory writes."""
    def check(entry):
        info = entry.lstat()
        return not entry.is_symlink() and max(info.st_mtime, info.st_ctime) < cutoff

    if renamed_root is None:
        if not check(path):
            return False
    else:
        # Our rename updates only the root ctime. Identity and mtime must stay unchanged.
        info = path.lstat()
        identity = lambda stat: (stat.st_dev, stat.st_ino, stat.st_mtime_ns)
        if path.is_symlink() or info.st_mtime >= cutoff or identity(info) != identity(renamed_root):
            return False
    def fail(error):
        raise error
    for current, dirs, files in os.walk(path, followlinks=False, onerror=fail):
        if not all(check(Path(current) / name) for name in dirs + files):
            return False
    return True


def tracked(path):
    result = git(path.parent, "ls-files", "-z", "--", path.name)
    if result.returncode:
        LOG.warning("SKIP cannot verify Git tracking: %s", path)
        return True
    return bool(result.stdout)


def artifacts(roots, include_repos=False):
    for root in roots:
        if not root.is_dir() or root.is_symlink() or protected(root):
            continue
        def fail(error):
            LOG.warning("SCAN %s", error)
        for current, dirs, _ in os.walk(root, followlinks=False, onerror=fail):
            parent = Path(current)
            if protected(parent) or parent == root / "developer-cleanup":
                dirs[:] = []
                continue
            if include_repos and (parent / ".git").exists():
                yield "repo", parent
            path = parent / "target"
            tag = path / "CACHEDIR.TAG"
            if ("target" in dirs and not path.is_symlink()
                    and (parent / "Cargo.toml").is_file()
                    and not (parent / "Cargo.toml").is_symlink()
                    and (path / ".rustc_info.json").is_file()
                    and tag.is_file() and not tag.is_symlink()):
                try:
                    with tag.open("rb") as marker:
                        recognized = marker.read(64).startswith(b"Signature: 8a477f597d28d172789f06886806bc55")
                    if recognized:
                        yield "rust", path
                except OSError as error:
                    LOG.warning("SCAN %s", error)
            dirs[:] = [name for name in dirs
                       if name not in PRUNE and not (parent / name).is_symlink()
                       and not protected(parent / name)]


def clean_artifact(kind, path, apply, cutoff, stats):
    if kind != "rust" or protected(path) or protected_project(path.parent):
        skip(stats, "protected_project")
        return
    if not old_tree(path, cutoff):
        skip(stats, "recent_or_symlink")
        return
    if tracked(path):
        skip(stats, "git_tracked_or_unknown")
        return
    if Usage.read().busy(path.parent):
        skip(stats, "active_project")
        LOG.info("SKIP active project %s", path.parent)
        return
    stats["candidates"] += 1
    LOG.info("CANDIDATE %s %s", kind, path)
    if not apply:
        return
    if Usage.read().busy(path.parent) or protected_project(path.parent):
        skip(stats, "active_or_protected_recheck")
        return
    if not old_tree(path, cutoff):
        skip(stats, "recent_recheck")
        return
    original = path.lstat()
    holding = Path(tempfile.mkdtemp(prefix=".developer-cleanup-", dir=path.parent))
    detached = holding / "target"
    try:
        # New builds use a new target; never delete through their original output path.
        path.rename(detached)
        if Usage.read().busy(path.parent) or protected_project(path.parent):
            raise Busy("Project became active after detaching its old target")
        if not old_tree(detached, cutoff, renamed_root=original):
            raise Busy("Output changed after detaching its old target")
        # A neutral cwd avoids loading project Cargo configuration. Both output paths are explicit.
        with tempfile.TemporaryDirectory(prefix="developer-cleanup-cargo-") as cwd:
            run(["cargo", "clean", "--offline", "--frozen", "--manifest-path", str(path.parent / "Cargo.toml"),
                 "--target-dir", str(detached), "--config", "build.build-dir=" + json.dumps(str(detached))], cwd=cwd)
    finally:
        # Never overwrite a new build or discard remaining output after an error.
        if detached.exists():
            if not path.exists():
                detached.rename(path)
            else:
                LOG.warning("PRESERVED detached output: %s", detached)
        if holding.exists() and not any(holding.iterdir()):
            holding.rmdir()
    stats["cleaned"] += 1


def skip(stats, reason):
    stats["skipped"][reason] = stats["skipped"].get(reason, 0) + 1


def write_text(path, value):
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as output:
        temporary = Path(output.name)
        try:
            output.write(value)
            output.flush()
            os.fsync(output.fileno())
            output.close()
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def write_json(path, value):
    write_text(path, json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def safe_origin(value):
    """Keep a restoration location without URL passwords, tokens, queries or fragments."""
    value = value.strip()
    if not value or any(ord(char) < 32 for char in value):
        return None
    if "://" in value:
        try:
            parsed = urlsplit(value)
            if parsed.scheme not in {"http", "https", "ssh", "git", "git+ssh", "file"}:
                return None
            host = parsed.hostname or ""
            if ":" in host:
                host = "[" + host + "]"
            if parsed.port:
                host += ":" + str(parsed.port)
            if parsed.scheme in {"ssh", "git+ssh"} and parsed.username == "git":
                host = "git@" + host
            return urlunsplit((parsed.scheme, host, parsed.path, "", ""))
        except ValueError:
            return None
    scp = re.fullmatch(r"(?:(?P<user>[A-Za-z0-9_.-]+)@)?(?P<location>[A-Za-z0-9_.-]+:[^?#]+)(?:[?#].*)?", value)
    if scp:
        return ("git@" if scp["user"] == "git" else "") + scp["location"]
    if value.startswith(("/", "./", "../", "~/")):
        return value
    return None


def repo_identity(info):
    return [info.st_dev, info.st_ino, getattr(info, "st_birthtime", None)]


def repository_details(path):
    before = path.lstat()
    if path.is_symlink():
        raise RuntimeError("Repository path is a symlink")
    head, committed_at = git_output(path, "log", "-1", "--format=%H%x00%cI").strip().split("\0")
    refs = git_output(path, "for-each-ref", "--format=%(refname) %(objectname)",
                      "refs/heads", "refs/remotes")
    origin = safe_origin(git_output(path, "remote", "get-url", "origin"))
    files = git_output(path, "ls-files", "-z").split("\0")
    digest = hashlib.sha256()
    modified, changed, count = 0, 0, 0
    for relative in filter(None, files):
        name = Path(relative)
        if name.is_absolute() or ".." in name.parts:
            raise RuntimeError("Invalid tracked path")
        info = (path / name).lstat()
        # lstat records symlinks without reading their destinations or file contents.
        digest.update(json.dumps([relative, info.st_ino, info.st_mode, info.st_size,
                                  info.st_mtime_ns, info.st_ctime_ns]).encode())
        modified, changed = max(modified, info.st_mtime), max(changed, info.st_ctime)
        count += 1
    after = path.lstat()
    if repo_identity(before) != repo_identity(after) or head != git_output(path, "rev-parse", "HEAD").strip():
        raise RuntimeError("Repository changed during observation")
    digest.update(json.dumps([head, refs, origin, after.st_mtime_ns, after.st_ctime_ns]).encode())
    return {"filesystem_identity": repo_identity(after), "directory_created_at": getattr(after, "st_birthtime", None),
            "directory_changed_at": after.st_ctime, "last_tracked_file_modified_at": modified or None,
            "last_tracked_file_changed_at": changed or None, "tracked_files": count,
            "head": head, "head_committed_at": committed_at, "refs": refs.splitlines(),
            "origin_url": origin, "fingerprint": digest.hexdigest()}


def inventory_path(home, relative):
    path = Path(relative)
    if path.is_absolute() or ".." in path.parts or not path.parts or path.parts[0] not in {"Develop", "Workspaces"}:
        raise RuntimeError("Inventory path is outside workspace roots")
    return home / path


def render_inventory(records):
    def date(value):
        return datetime.fromtimestamp(value).astimezone().isoformat(timespec="seconds") if value else "unknown"

    def cell(value):
        return str(value).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("|", "\\|").replace("\n", " ").replace("\r", " ").replace("`", "'")

    lines = ["# Repository inventory", "", "Clone deletion is disabled. Missing paths have an unverified cause.", "",
             "Created = filesystem birthtime. File modified = tracked file mtime. These are not last-use times.", "",
             "| Path | Status | Created | File modified | First observed | Unchanged since | 30-day review |",
             "| --- | --- | --- | --- | --- | --- | --- |"]
    for record in sorted(records.values(), key=lambda item: (item["path"], item["first_seen_at"])):
        lines.append("| " + " | ".join(map(cell, [record["path"], record["status"],
                     date(record.get("directory_created_at")), date(record.get("last_tracked_file_modified_at")),
                     date(record["first_seen_at"]), date(record["unchanged_since"]), record["age_review_candidate"]])) + " |")
    lines += ["", "## Restoration references", ""]
    for record in sorted(records.values(), key=lambda item: item["path"]):
        lines += ["- " + cell(record["path"]) + " [" + record["status"] + "]",
                  "  - Origin: " + cell(record.get("origin_url") or "unknown"),
                  "  - HEAD: " + cell(record.get("head") or "unknown"),
                  "  - Last present: " + date(record["last_seen_at"])]
    return "\n".join(lines) + "\n"


def update_inventory(report, home, store=None):
    """Retain past clones independently of the rotating runtime logs. Never remove a clone."""
    store = store or home / "Develop/developer-cleanup"
    if store.is_symlink():
        raise RuntimeError("Inventory directory is a symlink")
    if not store.parent.is_dir():
        raise RuntimeError("Inventory parent directory is unavailable")
    store.mkdir(exist_ok=True, mode=0o700)
    store.chmod(0o700)
    registry = store / "repositories.json"
    previous = json.loads(registry.read_text())["repositories"] if registry.exists() else {}
    records = {key: dict(value) for key, value in previous.items()}
    known_paths = {value["path"] for value in records.values()}
    now, events, observed = time.time(), [], set()
    for entry in report["repositories"]:
        if not entry["review_candidate"] and entry["path"] not in known_paths:
            continue
        path = inventory_path(home, entry["path"])
        try:
            if protected_project(path):
                continue
            details = repository_details(path)
        except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
            entry["observation_error"] = "unverifiable"
            LOG.warning("INVENTORY cannot observe %s: %s", path, error)
            continue
        key = hashlib.sha256(json.dumps([entry["path"], details["filesystem_identity"]]).encode()).hexdigest()
        old = records.get(key)
        same = (old is not None and old["status"] == "present" and old.get("fingerprint") == details["fingerprint"]
                and old.get("reasons") == entry["reasons"] and 0 <= now - old["last_seen_at"] <= 2 * 86400)
        record = dict(details, path=entry["path"], status="present", first_seen_at=old["first_seen_at"] if old else now,
                      last_seen_at=now, last_checked_at=now, unchanged_since=old["unchanged_since"] if same else now,
                      review_candidate=entry["review_candidate"], reasons=list(entry["reasons"]))
        anchors = [record["unchanged_since"], record["directory_changed_at"],
                   record["last_tracked_file_modified_at"], record["last_tracked_file_changed_at"], record["directory_created_at"]]
        record["age_review_candidate"] = bool(entry["review_candidate"] and record["origin_url"]
                                               and all(value is not None and now - value >= REPO_RETENTION for value in anchors))
        records[key] = record
        observed.add(key)
        entry["observation"] = record
        if not same:
            events.append({"type": "first_seen" if old is None else "changed", "at": now, "id": key, "record": record})
    for key, record in records.items():
        if key in observed:
            continue
        path = inventory_path(home, record["path"])
        try:
            if not (home / Path(record["path"]).parts[0]).is_dir():
                status = "unverifiable"
            else:
                status = "present" if repo_identity(path.lstat()) == record["filesystem_identity"] else "replaced"
        except FileNotFoundError:
            status = "missing"
        except OSError:
            status = "unverifiable"
        changed = record["status"] != status
        record["status"] = status
        record.update(last_checked_at=now, age_review_candidate=False, review_candidate=False,
                      reasons=["not_observed_in_current_report"], unchanged_since=now)
        if changed:
            events.append({"type": status, "at": now, "id": key, "record": dict(record)})
    if events:
        with (store / "repository-events.jsonl").open("a", encoding="utf-8") as output:
            os.fchmod(output.fileno(), 0o600)
            for event in events:
                output.write(json.dumps(event, ensure_ascii=False) + "\n")
            output.flush()
            os.fsync(output.fileno())
    write_json(registry, {"version": 1, "updated_at": now, "deletion_enabled": False, "repositories": records})
    write_text(store / "repositories.md", render_inventory(records))
    report["inventory"] = {"recorded": len(records), "age_review_candidates": sum(row["age_review_candidate"] for row in records.values()),
                           "store": str(store.relative_to(home))}
    return report


def refresh_inventory(home, state):
    """Refresh known candidates without cache cleanup or replacing the full daily report."""
    cached = state / "repo-report.json"
    registry = home / "Develop/developer-cleanup/repositories.json"
    paths = set()
    if cached.exists():
        paths.update(row["path"] for row in json.loads(cached.read_text())["repositories"] if row["review_candidate"])
    if registry.exists():
        paths.update(row["path"] for row in json.loads(registry.read_text())["repositories"].values())
    repos = [inventory_path(home, relative) for relative in sorted(paths)]
    # Keep the daily report's complete topology when checking nested repositories.
    topology = [inventory_path(home, row["path"]) for row in json.loads(cached.read_text())["repositories"]] if cached.exists() else repos
    report = repository_report(repos, home, topology=topology)
    report["scope"] = "previous_candidates_and_inventory"
    update_inventory(report, home)
    write_json(state / "inventory-report.json", report)
    return {"mode": "inventory", "failures": 0, **report["inventory"]}


def repository_report(paths, home, topology=None):
    """Inventory only. Cached remote refs do not prove that a clone can be removed."""
    usage = Usage.read()
    common_states, entries = {}, []

    checked = git_output

    for path in paths:
        entry = {"path": str(path.relative_to(home)), "review_candidate": False}
        try:
            if protected_project(path):
                entry["reasons"] = ["protected_project"]
                entries.append(entry)
                continue
            common = checked(path, "rev-parse", "--path-format=absolute", "--git-common-dir").strip()
            git_dir = checked(path, "rev-parse", "--absolute-git-dir").strip()
            if common not in common_states:
                branches = checked(path, "rev-list", "--count", "--branches", "--not", "--remotes")
                stash = checked(path, "stash", "list", "--format=%H")
                worktrees = checked(path, "worktree", "list", "--porcelain", "-z")
                common_states[common] = (int(branches), bool(stash),
                                         sum(field.startswith("worktree ") for field in worktrees.split("\0")))
            ahead, stash, worktrees = common_states[common]
            status = checked(path, "status", "--porcelain=v1", "-z", "--untracked-files=normal",
                             "--ignore-submodules=none")
            ignored = checked(path, "ls-files", "--others", "--ignored", "--exclude-standard",
                              "--directory", "-z")
            head_ahead = int(checked(path, "rev-list", "--count", "HEAD", "--not", "--remotes"))
            origin = git(path, "remote", "get-url", "origin")
            conditions = {
                "linked_worktree": common != git_dir,
                "dirty": bool(status), "ignored_data": bool(ignored),
                "local_commits": bool(ahead or head_ahead), "stash": stash,
                "other_worktrees": worktrees != 1,
                "no_origin": origin.returncode != 0 or not origin.stdout.strip(),
                "active_project": usage.busy(path),
                "nested_repository": any(other != path and (inside(other, path) or inside(path, other))
                                         for other in (topology if topology is not None else paths)),
            }
            entry["reasons"] = [name for name, present in conditions.items() if present]
            entry["review_candidate"] = not entry["reasons"]
        except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
            entry["reasons"] = ["unverifiable"]
            LOG.warning("REPORT cannot verify %s: %s", path, error)
        entries.append(entry)
    report = {"generated_at": time.time(), "remote_refs": "cached; not fetched",
              "deletion_enabled": False, "repositories": entries,
              "review_candidates": sum(entry["review_candidate"] for entry in entries)}
    LOG.info("REPOSITORIES checked=%s review_candidates=%s deletion_enabled=false",
             len(entries), report["review_candidates"])
    return report


def cleanup(home, apply, monitor=False, state=None):
    free_before = shutil.disk_usage(home).free
    pressure = free_before < LOW_FREE
    retention = PRESSURE_RETENTION if pressure else RETENTION
    stats = {"mode": "monitor" if monitor else "daily", "apply": apply,
             "started_at": time.time(), "free_before": free_before,
             "pressure": pressure, "retention_days": retention // 86400,
             "candidates": 0, "cleaned": 0, "skipped": {}, "failures": 0}
    if monitor and not pressure:
        stats["free_after"] = free_before
        LOG.info("SKIP monitor: free space >=100GiB")
        return stats
    cutoff = time.time() - retention

    def attempt(action):
        try:
            return action()
        except Busy as error:
            skip(stats, "busy_or_usage_unknown")
            LOG.info("SKIP %s", error)
        except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
            stats["failures"] += 1
            LOG.error("FAILED %s", error)
            if isinstance(error, subprocess.CalledProcessError) and error.stdout:
                LOG.error("%s", error.stdout[-8000:])

    if not monitor:
        # User generations only: privileged store GC stays with nix-darwin's existing job.
        command = ["nh", "clean", "user", "--keep", "5", "--keep-since", "30d",
                   "--no-gc", "--no-gcroots", "--no-direnv"]
        attempt(lambda: run(command + ([] if apply else ["--dry"])))

    repos = []
    for kind, path in artifacts([home / "Develop", home / "Workspaces"], include_repos=not monitor):
        if kind == "repo":
            repos.append(path)
        elif pressure and apply and shutil.disk_usage(home).free >= TARGET_FREE:
            skip(stats, "free_space_target_reached")
        else:
            attempt(lambda: clean_artifact(kind, path, apply, cutoff, stats))

    if not monitor:
        def prune_uv():
            if Usage.read().running("uv"):
                skip(stats, "uv_running")
            elif apply:
                run(["uv", "cache", "prune"])
            else:
                LOG.info("PLAN uv cache prune (unused cache only)")
        attempt(prune_uv)
        report = attempt(lambda: repository_report(repos, home))
        if report is not None and state is not None:
            attempt(lambda: update_inventory(report, home))
            write_json(state / "repo-report.json", report)

    # Never start a VM or follow a remote Docker context during scheduled cleanup.
    socket = home / ".orbstack/run/docker.sock"
    if not monitor and socket.exists():
        # Isolate the selected buildx builder as well as Docker's context.
        with tempfile.TemporaryDirectory(prefix="developer-cleanup-docker-") as docker_config:
            docker = ["docker", "--config", docker_config, "--host", f"unix://{socket}"]
            if apply:
                attempt(lambda: run(docker + ["builder", "prune", "--force", "--filter", "until=168h",
                                              "--max-used-space", "10GiB"]))
                attempt(lambda: run(docker + ["image", "prune", "--force", "--filter", "until=720h"]))
            else:
                attempt(lambda: run(docker + ["system", "df"]))
                LOG.info("PLAN unused build cache older than 7 days toward 10GiB; dangling images older than 30 days")
    elif not monitor:
        LOG.info("SKIP Docker: local OrbStack socket unavailable")
    stats["free_after"] = shutil.disk_usage(home).free
    if apply and state is not None and stats["free_after"] < LOW_FREE:
        stamp = state / "last-notification"
        if not stamp.exists() or time.time() - stamp.stat().st_mtime >= 86400:
            message = f'空き容量は{stats["free_after"] / GIB:.1f}GiBです。developer-cleanupのログを確認してください。'
            result = attempt(lambda: run(["/usr/bin/osascript", "-e",
                                         f'display notification {json.dumps(message, ensure_ascii=False)} '
                                         'with title "ストレージ容量不足"']))
            if result is not None:
                stamp.touch(mode=0o600)
    return stats


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Perform cleanup (default: dry-run)")
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--monitor", action="store_true", help="Only check capacity and reclaim aged Rust output below 100GiB")
    modes.add_argument("--inventory-only", action="store_true", help="Update the durable inventory of known clone candidates without cleanup")
    args = parser.parse_args()
    home = Path.home()
    state = home / ".local/state/developer-cleanup"
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.umask(0o077)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s",
                        handlers=[logging.StreamHandler(sys.stdout), RotatingFileHandler(
                            state / "cleanup.log", maxBytes=2_000_000, backupCount=3)])
    with (state / "run.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            LOG.info("SKIP another cleanup is running")
            return 0
        LOG.info("START mode=%s monitor=%s inventory=%s", "apply" if args.apply else "dry-run", args.monitor, args.inventory_only)
        try:
            stats = refresh_inventory(home, state) if args.inventory_only else cleanup(home, args.apply, args.monitor, state)
        except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
            LOG.error("FAILED %s", error)
            return 1
        write_json(state / "latest-summary.json", stats)
        write_json(state / (stats["mode"] + "-summary.json"), stats)
        LOG.info("SUMMARY %s", json.dumps(stats))
        LOG.info("END failures=%s", stats["failures"])
        return bool(stats["failures"])


if __name__ == "__main__":
    raise SystemExit(main())
