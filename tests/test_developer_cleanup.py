import importlib.util
from contextlib import ExitStack
import json
import os
from pathlib import Path
import subprocess
import shutil
import tempfile
import time
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "nix/home-manager/programs/developer-cleanup.py"
SPEC = importlib.util.spec_from_file_location("cleanup", SCRIPT)
cleanup = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cleanup)


def stats():
    return {"candidates": 0, "cleaned": 0, "skipped": {}}


class CleanupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.project = self.root / "project"
        self.project.mkdir()
        self.target = self.project / "target"
        self.target.mkdir()
        (self.target / ".rustc_info.json").write_text("{}")
        (self.target / "CACHEDIR.TAG").write_text("Signature: 8a477f597d28d172789f06886806bc55\n")
        (self.project / "Cargo.toml").write_text('[package]\nname="fixture"\nversion="0.1.0"\n')
        self.git(self.project, "init", "-q")
        self.idle = cleanup.Usage({}, set(), {})

    def git(self, path, *args):
        return subprocess.run(["git", "-c", "core.hooksPath=/dev/null", "-c", "commit.gpgSign=false",
                               "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                               "-C", str(path), *args], check=True, text=True, capture_output=True)

    def repo(self, name="repo"):
        path = self.root / "Develop" / name
        path.mkdir(parents=True)
        self.git(path, "init", "-q", "-b", "main")
        (path / "README").write_text("fixture\n")
        self.git(path, "add", ".")
        self.git(path, "commit", "-qm", "fixture")
        self.git(path, "remote", "add", "origin", "https://example.invalid/project.git")
        self.git(path, "update-ref", "refs/remotes/origin/main", "HEAD")
        return path

    def clean_context(self, age=True, usage=None):
        stack = ExitStack()
        stack.enter_context(patch.object(cleanup, "old_tree", return_value=age))
        stack.enter_context(patch.object(cleanup.Usage, "read", return_value=usage or self.idle))
        return stack

    def test_only_recognized_rust_artifacts_are_discovered(self):
        (self.root / "other/target").mkdir(parents=True)
        (self.root / "link").symlink_to(self.project, target_is_directory=True)
        (self.project / "Package.swift").touch()
        (self.project / ".build").mkdir()
        self.assertEqual(list(cleanup.artifacts([self.root])), [("rust", self.target)])
        (self.target / "CACHEDIR.TAG").write_text("not a Cargo cache")
        self.assertEqual(list(cleanup.artifacts([self.root])), [])

    def test_age_checks_all_descendants_and_rejects_symlinks(self):
        future = time.time() + 60
        self.assertTrue(cleanup.old_tree(self.target, future))
        self.assertFalse(cleanup.old_tree(self.target, time.time() - 86400))
        nested = self.target / "debug"
        nested.mkdir()
        (nested / "new").write_text("data")
        os.utime(nested / "new", (future + 60, future + 60))
        self.assertFalse(cleanup.old_tree(self.target, future))
        (nested / "new").unlink()
        (nested / "link").symlink_to(self.project / "Cargo.toml")
        self.assertFalse(cleanup.old_tree(self.target, future))

    def test_runtime_data_and_ios_lab_are_not_scanned(self):
        for name in (".local", ".device-lab"):
            hidden = self.project / name / "nested"
            hidden.mkdir(parents=True)
            shutil.copyfile(self.project / "Cargo.toml", hidden / "Cargo.toml")
            shutil.copytree(self.target, hidden / "target")
        self.assertEqual(list(cleanup.artifacts([self.root])), [("rust", self.target)])

    def test_inventory_directory_in_develop_is_excluded_from_cleanup_scan(self):
        data = self.root / "Develop/developer-cleanup"
        data.mkdir(parents=True)
        shutil.copyfile(self.project / "Cargo.toml", data / "Cargo.toml")
        shutil.copytree(self.target, data / "target")
        self.git(data, "init", "-q")
        self.assertEqual(list(cleanup.artifacts([self.root / "Develop"], include_repos=True)), [])

    def test_scanner_does_not_keep_candidate_open_as_active_usage(self):
        opened = []
        original = Path.open
        def record(path, *args, **kwargs):
            stream = original(path, *args, **kwargs)
            opened.append(stream)
            return stream
        with patch.object(Path, "open", record):
            scanner = cleanup.artifacts([self.root])
            self.assertEqual(next(scanner), ("rust", self.target))
            self.assertTrue(all(stream.closed for stream in opened))
        scanner.close()

    def test_detached_age_check_requires_same_root_and_old_descendants(self):
        future = time.time() + 60
        original = self.target.lstat()
        detached = self.project / "detached"
        self.target.rename(detached)
        self.assertTrue(cleanup.old_tree(detached, future, renamed_root=original))
        (detached / "new").write_text("new")
        os.utime(detached / "new", (future + 1, future + 1))
        self.assertFalse(cleanup.old_tree(detached, future, renamed_root=original))
        other = self.project / "other"
        other.mkdir()
        self.assertFalse(cleanup.old_tree(other, future, renamed_root=original))

    def test_git_tracked_and_unverifiable_artifacts_are_preserved(self):
        self.git(self.project, "add", "target")
        with self.clean_context(), patch.object(cleanup, "run") as run:
            cleanup.clean_artifact("rust", self.target, True, 0, stats())
        run.assert_not_called()
        self.assertTrue(cleanup.tracked(self.root / "unknown"))

    def test_dry_run_never_cleans(self):
        with self.clean_context(), patch.object(cleanup, "run") as run:
            cleanup.clean_artifact("rust", self.target, False, 0, stats())
        run.assert_not_called()
        self.assertTrue(self.target.exists())

    def test_mobileandon_names_and_remote_aliases_are_protected(self):
        for name in ("MobileAndon", "mobile-andon-ios", "Mobile_Andon"):
            self.assertTrue(cleanup.protected(self.root / name / "target"))
        alias = self.root / "alias"
        alias.symlink_to(self.root / "MobileAndon", target_is_directory=True)
        self.assertTrue(cleanup.protected(alias / "target"))
        self.git(self.project, "remote", "add", "origin", "git@example.invalid:apps/MobileAndon.git")
        with self.clean_context(), patch.object(cleanup, "run") as run:
            cleanup.clean_artifact("rust", self.target, True, 0, stats())
        run.assert_not_called()
        self.project.rename(self.root / "MobileAndon")
        self.assertEqual(list(cleanup.artifacts([self.root])), [])

    def test_mobileandon_worktree_with_generic_name_is_protected(self):
        main = self.repo("MobileAndon")
        worktree = self.root / "generic-worktree"
        self.git(main, "worktree", "add", "-qb", "work", str(worktree))
        self.assertTrue(cleanup.protected_project(worktree))

    def test_scope_keeps_active_project_without_xcode_global_skip(self):
        usage = cleanup.Usage({"1": "Xcode", "2": "cargo"}, {self.root / "unrelated/target/file"},
                              {"2": self.root / "unrelated"})
        self.assertFalse(usage.busy(self.project))
        usage = cleanup.Usage({}, {self.target / "release/app"}, {})
        self.assertTrue(usage.busy(self.project))
        usage = cleanup.Usage({"2": "cargo"}, set(), {"2": self.root})
        self.assertTrue(usage.busy(self.project))

    def test_active_project_and_fresh_age_recheck_prevent_clean(self):
        busy = cleanup.Usage({}, {self.target / "app"}, {})
        with self.clean_context(usage=busy), patch.object(cleanup, "run") as run:
            cleanup.clean_artifact("rust", self.target, True, 0, stats())
        run.assert_not_called()
        with self.clean_context(), patch.object(cleanup, "old_tree", side_effect=[True, False]), \
                patch.object(cleanup, "run") as run:
            cleanup.clean_artifact("rust", self.target, True, 0, stats())
        run.assert_not_called()
        with self.clean_context(), patch.object(cleanup.Usage, "read", side_effect=[self.idle, busy]), \
                patch.object(cleanup, "run") as run:
            cleanup.clean_artifact("rust", self.target, True, 0, stats())
        run.assert_not_called()

    def test_usage_parses_nul_paths_and_fails_closed_for_unknown_builder_cwd(self):
        opened = b"p42\0ccargo\0\nfcwd\0n" + os.fsencode(self.project) + b"\0\n"
        ps = subprocess.CompletedProcess([], 0, stdout="42 /nix/store/cargo/bin/cargo\n")
        lsof = subprocess.CompletedProcess([], 0, stdout=opened)
        with patch.object(cleanup.subprocess, "run", side_effect=[ps, lsof]):
            self.assertTrue(cleanup.Usage.read().busy(self.project))
        lsof.stdout = b"p42\0ccargo\0\nf1\0n/dev/null\0\n"
        with patch.object(cleanup.subprocess, "run", side_effect=[ps, lsof]):
            with self.assertRaises(cleanup.Busy):
                cleanup.Usage.read()

    def test_native_cargo_clean_uses_neutral_cwd_and_both_output_paths(self):
        result = stats()
        with self.clean_context(), patch.object(cleanup, "run") as run:
            cleanup.clean_artifact("rust", self.target, True, 0, result)
        command = run.call_args.args[0]
        self.assertIn("--offline", command)
        self.assertIn("--frozen", command)
        detached = Path(command[command.index("--target-dir") + 1])
        self.assertEqual(detached.name, "target")
        self.assertEqual(detached.parent.parent, self.project)
        self.assertNotEqual(detached, self.target)
        self.assertIn("build.build-dir=" + json.dumps(str(detached)), command)
        self.assertNotEqual(run.call_args.kwargs["cwd"], str(self.project))
        self.assertEqual(result["cleaned"], 1)

    def test_failure_restores_detached_output(self):
        with self.clean_context(), patch.object(cleanup, "run", side_effect=subprocess.CalledProcessError(1, ["cargo"])):
            with self.assertRaises(subprocess.CalledProcessError):
                cleanup.clean_artifact("rust", self.target, True, 0, stats())
        self.assertTrue((self.target / ".rustc_info.json").exists())
        self.assertEqual(list(self.project.glob(".developer-cleanup-*")), [])

    def test_activity_after_detach_restores_output_without_clean(self):
        busy = cleanup.Usage({}, {self.project / "src/main.rs"}, {})
        with self.clean_context(), patch.object(cleanup.Usage, "read", side_effect=[self.idle, self.idle, busy]), \
                patch.object(cleanup, "run") as run:
            with self.assertRaises(cleanup.Busy):
                cleanup.clean_artifact("rust", self.target, True, 0, stats())
        run.assert_not_called()
        self.assertTrue((self.target / ".rustc_info.json").exists())

    def test_concurrent_new_target_is_never_cleaned(self):
        def clean_detached(command, **kwargs):
            self.target.mkdir()
            (self.target / "NEW_BUILD").write_text("keep")
            detached = Path(command[command.index("--target-dir") + 1])
            shutil.rmtree(detached)
        with self.clean_context(), patch.object(cleanup, "run", side_effect=clean_detached):
            cleanup.clean_artifact("rust", self.target, True, 0, stats())
        self.assertEqual((self.target / "NEW_BUILD").read_text(), "keep")
        self.assertTrue((self.project / "Cargo.toml").exists())

    def test_monitor_with_enough_space_avoids_all_heavy_work(self):
        space = shutil_usage(120)
        with patch.object(cleanup.shutil, "disk_usage", return_value=space), \
                patch.object(cleanup, "run") as run, patch.object(cleanup, "artifacts") as scan:
            result = cleanup.cleanup(self.root, True, monitor=True)
        run.assert_not_called()
        scan.assert_not_called()
        self.assertEqual(result["retention_days"], 7)

    def test_pressure_uses_three_days_and_stops_at_target(self):
        now = time.time()
        with patch.object(cleanup.shutil, "disk_usage", side_effect=[shutil_usage(90), shutil_usage(90),
                                                                    shutil_usage(155), shutil_usage(155)]), \
                patch.object(cleanup, "artifacts", return_value=[("rust", self.target)] * 2), \
                patch.object(cleanup, "clean_artifact") as clean, \
                patch.object(cleanup.time, "time", return_value=now):
            result = cleanup.cleanup(self.root, True, monitor=True)
        clean.assert_called_once()
        self.assertEqual(clean.call_args.args[3], now - 3 * 86400)
        self.assertEqual(result["skipped"]["free_space_target_reached"], 1)

    def test_daily_uses_seven_days_and_preserves_ios_and_docker_volumes(self):
        derived = self.root / "Library/Developer/Xcode/DerivedData/fixture"
        derived.mkdir(parents=True)
        (derived / "build-output").write_text("keep")
        ios = self.root / "Develop/MobileAndon/.device-lab/run/DerivedData"
        ios.mkdir(parents=True)
        (ios / "build-output").write_text("keep")
        socket = self.root / ".orbstack/run/docker.sock"
        socket.parent.mkdir(parents=True)
        socket.touch()
        with patch.object(cleanup.shutil, "disk_usage", return_value=shutil_usage(120)), \
                patch.object(cleanup.Usage, "read", return_value=self.idle), \
                patch.object(cleanup, "run", return_value="") as run:
            result = cleanup.cleanup(self.root, True)
        self.assertEqual(result["failures"], 0)
        self.assertEqual(result["retention_days"], 7)
        self.assertTrue((derived / "build-output").exists())
        self.assertTrue((ios / "build-output").exists())
        commands = [call.args[0] for call in run.call_args_list]
        self.assertIn(["uv", "cache", "prune"], commands)
        docker = [cmd for cmd in commands if cmd[0] == "docker"]
        self.assertEqual(len(docker), 2)
        self.assertIn("--max-used-space", docker[0])
        self.assertIn("10GiB", docker[0])
        for cmd in docker:
            self.assertIn("--config", cmd)
            self.assertIn(f"unix://{socket}", cmd)
            self.assertNotIn("--all", cmd)
            self.assertNotIn("volume", cmd)
            self.assertNotIn("container", cmd)

    def test_tool_failure_is_reported_and_dry_run_does_not_prune(self):
        with patch.object(cleanup.shutil, "disk_usage", return_value=shutil_usage(120)), \
                patch.object(cleanup.Usage, "read", return_value=self.idle), \
                patch.object(cleanup, "run", side_effect=subprocess.CalledProcessError(1, ["nh"])) as run:
            result = cleanup.cleanup(self.root, False)
        self.assertEqual(result["failures"], 1)
        run.assert_called_once()
        self.assertIn("--dry", run.call_args.args[0])
        self.assertIn("--no-gc", run.call_args.args[0])
        self.assertTrue(self.target.exists())

    def test_report_candidates_and_ignored_secrets_are_never_deleted(self):
        repo = self.repo()
        with patch.object(cleanup.Usage, "read", return_value=self.idle):
            report = cleanup.repository_report([repo], self.root)
            self.assertEqual(report["review_candidates"], 1)
            (repo / ".git/info/exclude").write_text(".env\n")
            (repo / ".env").write_text("fixture-secret")
            report = cleanup.repository_report([repo], self.root)
        self.assertFalse(report["deletion_enabled"])
        self.assertIn("ignored_data", report["repositories"][0]["reasons"])
        self.assertEqual((repo / ".env").read_text(), "fixture-secret")
        self.assertNotIn("fixture-secret", json.dumps(report))

    def test_report_preserves_stash_local_commits_nested_and_active_repos(self):
        repo = self.repo()
        (repo / "README").write_text("change")
        self.git(repo, "stash", "push", "-qm", "fixture")
        self.git(repo, "commit", "--allow-empty", "-qm", "local")
        nested = repo / "nested"
        nested.mkdir()
        busy = cleanup.Usage({}, {repo / "README"}, {})
        with patch.object(cleanup.Usage, "read", return_value=busy):
            report = cleanup.repository_report([repo, nested], self.root)
        reasons = report["repositories"][0]["reasons"]
        for expected in ("stash", "local_commits", "nested_repository", "active_project"):
            self.assertIn(expected, reasons)
        self.assertEqual(report["review_candidates"], 0)
        self.assertTrue(repo.is_dir())

    def test_docker_environment_cannot_select_a_remote_builder(self):
        with patch.dict(os.environ, {"DOCKER_CONTEXT": "remote", "BUILDX_BUILDER": "remote"}), \
                patch.object(cleanup.subprocess, "run") as run:
            run.return_value.stdout = ""
            cleanup.run(["docker", "version"])
        self.assertNotIn("DOCKER_CONTEXT", run.call_args.kwargs["env"])
        self.assertNotIn("BUILDX_BUILDER", run.call_args.kwargs["env"])

    def test_private_atomic_reports(self):
        path = self.root / "report.json"
        cleanup.write_json(path, {"value": 1})
        cleanup.write_json(path, {"value": 2})
        self.assertEqual(json.loads(path.read_text()), {"value": 2})
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def observe(self, paths):
        with patch.object(cleanup.Usage, "read", return_value=self.idle):
            report = cleanup.repository_report(paths, self.root)
        return cleanup.update_inventory(report, self.root)

    def ledger(self):
        return json.loads((self.root / "Develop/developer-cleanup/repositories.json").read_text())["repositories"]

    def test_inventory_distinguishes_commit_creation_edit_and_observation_dates(self):
        repo = self.repo()
        os.utime(repo / "README", (1_000_000_000, 1_000_000_000))
        now = time.time()
        with patch.object(cleanup.time, "time", return_value=now):
            report = self.observe([repo])
        record = next(iter(self.ledger().values()))
        self.assertEqual(record["last_tracked_file_modified_at"], 1_000_000_000)
        self.assertGreater(record["last_tracked_file_changed_at"], 1_000_000_000)
        self.assertEqual(record["directory_created_at"], getattr(repo.stat(), "st_birthtime", None))
        self.assertEqual(record["head"], self.git(repo, "rev-parse", "HEAD").stdout.strip())
        self.assertEqual(record["first_seen_at"], now)
        self.assertEqual(record["unchanged_since"], now)
        self.assertFalse(record["age_review_candidate"])
        self.assertEqual(report["inventory"]["recorded"], 1)

    def test_inventory_requires_thirty_observed_days_and_resets_after_gaps(self):
        repo = self.repo()
        now = time.time()
        details = cleanup.repository_details(repo)
        for key in ("directory_created_at", "directory_changed_at", "last_tracked_file_modified_at", "last_tracked_file_changed_at"):
            details[key] = now - 40 * 86400
        def observe(day, reasons=None):
            reasons = reasons or []
            report = {"repositories": [{"path": "Develop/repo", "review_candidate": not reasons, "reasons": reasons}]}
            with patch.object(cleanup.time, "time", return_value=now + day * 86400), \
                    patch.object(cleanup, "repository_details", return_value=dict(details)):
                cleanup.update_inventory(report, self.root)
            return next(iter(self.ledger().values()))
        self.assertFalse(observe(0)["age_review_candidate"])
        for day in range(1, 30):
            self.assertFalse(observe(day)["age_review_candidate"])
        self.assertTrue(observe(30)["age_review_candidate"])
        self.assertFalse(observe(33)["age_review_candidate"])
        self.assertEqual(observe(34, ["active_project"])["unchanged_since"], now + 34 * 86400)
        self.assertEqual(observe(35)["unchanged_since"], now + 35 * 86400)

    def test_inventory_tracks_edits_and_ref_changes_without_file_contents(self):
        repo = self.repo()
        self.observe([repo])
        before = next(iter(self.ledger().values()))
        (repo / "README").write_text("private fixture text")
        self.observe([repo])
        edited = next(iter(self.ledger().values()))
        self.assertNotEqual(before["fingerprint"], edited["fingerprint"])
        self.assertIn("dirty", edited["reasons"])
        self.assertFalse(edited["age_review_candidate"])
        self.git(repo, "restore", "README")
        self.git(repo, "branch", "extra")
        self.observe([repo])
        self.assertNotEqual(edited["fingerprint"], next(iter(self.ledger().values()))["fingerprint"])
        data = self.root / "Develop/developer-cleanup"
        self.assertNotIn("private fixture text", "".join(path.read_text() for path in data.iterdir()))

    def test_missing_clone_retains_restoration_reference_and_single_missing_event(self):
        repo = self.repo()
        self.observe([repo])
        before = next(iter(self.ledger().values()))
        shutil.rmtree(repo)
        self.observe([])
        self.observe([])
        record = next(iter(self.ledger().values()))
        self.assertEqual(record["status"], "missing")
        for key in ("origin_url", "head", "first_seen_at", "last_seen_at", "directory_created_at"):
            self.assertEqual(record[key], before[key])
        data = self.root / "Develop/developer-cleanup"
        events = [json.loads(line) for line in (data / "repository-events.jsonl").read_text().splitlines()]
        self.assertEqual([event["type"] for event in events], ["first_seen", "missing"])
        self.assertNotIn("deleted", {event["type"] for event in events})
        self.assertIn(before["head"], (data / "repositories.md").read_text())
        self.assertIn("missing", (data / "repositories.md").read_text())

    def test_replaced_clone_keeps_both_identities(self):
        repo = self.repo()
        self.observe([repo])
        moved = repo.with_name("old-repo")
        repo.rename(moved)
        self.repo()
        self.observe([repo])
        records = list(self.ledger().values())
        self.assertEqual(len(records), 2)
        self.assertEqual({row["status"] for row in records}, {"present", "replaced"})
        self.assertNotEqual(records[0]["filesystem_identity"], records[1]["filesystem_identity"])
        self.assertTrue(moved.is_dir())

    def test_inventory_does_not_call_missing_a_workspace_outage(self):
        repo = self.repo()
        (self.root / "Workspaces").mkdir()
        repo = repo.rename(self.root / "Workspaces/repo")
        self.observe([repo])
        (self.root / "Workspaces").rename(self.root / "unmounted")
        self.observe([])
        self.assertEqual(next(iter(self.ledger().values()))["status"], "unverifiable")

    def test_inventory_does_not_recreate_an_unavailable_develop_directory(self):
        repo = self.repo()
        self.observe([repo])
        before = (self.root / "Develop/developer-cleanup/repositories.json").read_bytes()
        (self.root / "Develop").rename(self.root / "unmounted")
        with self.assertRaises(RuntimeError):
            self.observe([])
        self.assertFalse((self.root / "Develop").exists())
        self.assertEqual((self.root / "unmounted/developer-cleanup/repositories.json").read_bytes(), before)

    def test_inventory_protects_mobileandon_and_rejects_unsafe_paths(self):
        repo = self.repo("alias")
        self.git(repo, "remote", "set-url", "origin", "https://example.invalid/MobileAndon.git")
        report = {"repositories": [{"path": "Develop/alias", "review_candidate": True, "reasons": []}]}
        cleanup.update_inventory(report, self.root)
        self.assertEqual(self.ledger(), {})
        for path in ("../outside", "/tmp/outside", "Library/repo"):
            with self.assertRaises(RuntimeError):
                cleanup.inventory_path(self.root, path)

    def test_inventory_strips_remote_credentials_and_has_private_permissions(self):
        repo = self.repo()
        self.git(repo, "remote", "set-url", "origin", "https://fixture-token:fixture-password@example.invalid/repo.git?token=fixture-query#fixture-fragment")
        self.observe([repo])
        data = self.root / "Develop/developer-cleanup"
        combined = "".join(path.read_text() for path in data.iterdir())
        for secret in ("fixture-token", "fixture-password", "fixture-query", "fixture-fragment"):
            self.assertNotIn(secret, combined)
        self.assertIn("https://example.invalid/repo.git", combined)
        self.assertEqual(data.stat().st_mode & 0o777, 0o700)
        for path in data.iterdir():
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(cleanup.safe_origin("git@example.invalid:owner/repo.git"), "git@example.invalid:owner/repo.git")
        self.assertEqual(cleanup.safe_origin("fixture-token@example.invalid:repo.git"), "example.invalid:repo.git")
        self.assertEqual(cleanup.safe_origin("ssh://git@example.invalid:2222/owner/repo.git"), "ssh://git@example.invalid:2222/owner/repo.git")
        self.assertIsNone(cleanup.safe_origin("https://example.invalid/repo\ninvalid"))

    def test_inventory_journal_survives_a_summary_write_failure(self):
        repo = self.repo()
        self.observe([repo])
        before = self.ledger()
        (repo / "README").write_text("change")
        with patch.object(cleanup, "write_json", side_effect=OSError("fixture write failure")):
            with self.assertRaises(OSError):
                self.observe([repo])
        self.assertEqual(self.ledger(), before)
        events = (self.root / "Develop/developer-cleanup/repository-events.jsonl").read_text().splitlines()
        self.assertEqual(json.loads(events[-1])["type"], "changed")

    def test_inventory_only_refreshes_candidates_without_cleanup_or_losing_full_report(self):
        repo = self.repo()
        state = self.root / ".local/state/developer-cleanup"
        state.mkdir(parents=True)
        with patch.object(cleanup.Usage, "read", return_value=self.idle):
            report = cleanup.repository_report([repo], self.root)
        report["repositories"].append({"path": "Develop/blocked", "review_candidate": False, "reasons": ["dirty"]})
        cleanup.write_json(state / "repo-report.json", report)
        original = (state / "repo-report.json").read_bytes()
        with patch.object(cleanup.Usage, "read", return_value=self.idle), patch.object(cleanup, "run") as run:
            result = cleanup.refresh_inventory(self.root, state)
        run.assert_not_called()
        self.assertEqual(result["recorded"], 1)
        self.assertEqual((state / "repo-report.json").read_bytes(), original)
        self.assertTrue((state / "inventory-report.json").exists())
        shutil.rmtree(repo)
        with patch.object(cleanup.Usage, "read", return_value=self.idle):
            cleanup.refresh_inventory(self.root, state)
        self.assertEqual(next(iter(self.ledger().values()))["status"], "missing")

    def test_inventory_only_preserves_nested_topology_from_full_report(self):
        repo = self.repo()
        state = self.root / ".local/state/developer-cleanup"
        state.mkdir(parents=True)
        cleanup.write_json(state / "repo-report.json", {"repositories": [
            {"path": "Develop/repo", "review_candidate": True, "reasons": []},
            {"path": "Develop/repo/nested", "review_candidate": False, "reasons": ["dirty"]}]})
        with patch.object(cleanup.Usage, "read", return_value=self.idle):
            cleanup.refresh_inventory(self.root, state)
        report = json.loads((state / "inventory-report.json").read_text())
        self.assertIn("nested_repository", report["repositories"][0]["reasons"])
        self.assertEqual(self.ledger(), {})

    def test_corrupt_inventory_is_preserved_and_stops_refresh(self):
        repo = self.repo()
        data = self.root / "Develop/developer-cleanup"
        data.mkdir(parents=True)
        (data / "repositories.json").write_text("invalid fixture")
        with self.assertRaises(ValueError):
            self.observe([repo])
        self.assertEqual((data / "repositories.json").read_text(), "invalid fixture")

    def test_daily_creates_inventory_and_keeps_clones_in_dry_run(self):
        repo = self.repo()
        state = self.root / ".local/state/developer-cleanup"
        state.mkdir(parents=True)
        with patch.object(cleanup.shutil, "disk_usage", return_value=shutil_usage(120)), \
                patch.object(cleanup.Usage, "read", return_value=self.idle), \
                patch.object(cleanup, "run", return_value=""):
            result = cleanup.cleanup(self.root, False, state=state)
        self.assertEqual(result["failures"], 0)
        self.assertEqual(len(self.ledger()), 1)
        report = json.loads((state / "repo-report.json").read_text())
        self.assertEqual(report["inventory"]["recorded"], 1)
        self.assertFalse(report["deletion_enabled"])
        self.assertTrue((repo / "README").exists())

    def test_daily_reports_inventory_failure_without_overwriting_corrupt_data(self):
        self.repo()
        state = self.root / ".local/state/developer-cleanup"
        state.mkdir(parents=True)
        data = self.root / "Develop/developer-cleanup"
        data.mkdir(parents=True)
        (data / "repositories.json").write_text("invalid fixture")
        with patch.object(cleanup.shutil, "disk_usage", return_value=shutil_usage(120)), \
                patch.object(cleanup.Usage, "read", return_value=self.idle), \
                patch.object(cleanup, "run", return_value=""):
            result = cleanup.cleanup(self.root, False, state=state)
        self.assertEqual(result["failures"], 1)
        self.assertEqual((data / "repositories.json").read_text(), "invalid fixture")
        self.assertEqual(json.loads((state / "repo-report.json").read_text())["review_candidates"], 1)


def shutil_usage(gib):
    from collections import namedtuple
    return namedtuple("usage", "total used free")(1000 * cleanup.GIB, (1000 - gib) * cleanup.GIB, gib * cleanup.GIB)


if __name__ == "__main__":
    unittest.main()
