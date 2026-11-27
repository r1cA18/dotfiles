import { afterEach, describe, expect, test } from "bun:test";
import { chmodSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const fixtures: string[] = [];
const script = join(import.meta.dir, "run-repo-check.ts");

// scripts/check fast fails for any file that contains "BAD" and prints its arguments.
const failingCheck = `#!/usr/bin/env bash
[ "$1" = fast ] || exit 2
shift
status=0
for file in "$@"; do
  if grep -q BAD "$file"; then echo "$file:1: contains BAD"; status=1; fi
done
exit $status
`;

function fixture({ check = failingCheck, remote = "git@github.com:someone/sample.git", trusted = "github.com/someone/" } = {}) {
  const home = mkdtempSync(join(tmpdir(), "repo-check-hook-"));
  fixtures.push(home);
  const repo = join(home, "repo");
  mkdirSync(join(repo, "scripts"), { recursive: true });
  Bun.spawnSync(["git", "init", "-q", repo]);
  Bun.spawnSync(["git", "-C", repo, "remote", "add", "origin", remote]);
  if (check) {
    writeFileSync(join(repo, "scripts", "check"), check);
    chmodSync(join(repo, "scripts", "check"), 0o755);
  }
  writeFileSync(join(repo, "good.txt"), "fine\n");
  writeFileSync(join(repo, "bad.txt"), "BAD\n");
  const trustFile = join(home, "trusted-remotes");
  writeFileSync(trustFile, `# owner repos\n${trusted}\n`);
  return { home, repo, trustFile };
}

function run(trustFile: string, input: unknown, env: Record<string, string> = {}) {
  const result = Bun.spawnSync([process.execPath, script], {
    env: { ...process.env, REPO_CHECK_TRUSTED: trustFile, ...env },
    stdin: Buffer.from(typeof input === "string" ? input : JSON.stringify(input)),
    stdout: "pipe",
    stderr: "pipe",
  });
  return { code: result.exitCode, out: result.stdout.toString() };
}

afterEach(() => {
  for (const root of fixtures.splice(0)) rmSync(root, { recursive: true, force: true });
});

describe("repo check hook", () => {
  test("stays silent when the check passes", () => {
    const { repo, trustFile } = fixture();
    const result = run(trustFile, { tool_input: { file_path: join(repo, "good.txt") } });
    expect(result).toEqual({ code: 0, out: "" });
  });

  test("reports a failing check as context without blocking", () => {
    const { repo, trustFile } = fixture();
    const result = run(trustFile, {
      hook_event_name: "PostToolUse",
      tool_input: { file_path: join(repo, "bad.txt") },
    });
    expect(result.code).toBe(0);
    const output = JSON.parse(result.out).hookSpecificOutput;
    expect(output.hookEventName).toBe("PostToolUse");
    expect(output.additionalContext).toContain("bad.txt:1: contains BAD");
  });

  test("reads the paths of a Codex apply_patch relative to cwd", () => {
    const { repo, trustFile } = fixture();
    const patch = "*** Begin Patch\n*** Update File: bad.txt\n@@\n-x\n+BAD\n*** Add File: good.txt\n+fine\n*** End Patch";
    const result = run(trustFile, { cwd: repo, tool_name: "apply_patch", tool_input: { command: patch } });
    expect(result.code).toBe(0);
    expect(JSON.parse(result.out).hookSpecificOutput.additionalContext).toContain("bad.txt:1: contains BAD");
  });

  test("does nothing for an untrusted remote", () => {
    const { repo, trustFile } = fixture({ remote: "https://github.com/stranger/sample.git" });
    expect(run(trustFile, { tool_input: { file_path: join(repo, "bad.txt") } })).toEqual({ code: 0, out: "" });
  });

  test("does nothing without a trust list or without scripts/check", () => {
    const first = fixture();
    expect(
      run(join(first.home, "missing"), { tool_input: { file_path: join(first.repo, "bad.txt") } }),
    ).toEqual({ code: 0, out: "" });
    const second = fixture({ check: "" });
    expect(run(second.trustFile, { tool_input: { file_path: join(second.repo, "bad.txt") } })).toEqual({
      code: 0,
      out: "",
    });
  });

  test("gives up silently when the check is too slow", () => {
    const { repo, trustFile } = fixture({ check: "#!/usr/bin/env bash\nsleep 5\nexit 1\n" });
    const result = run(trustFile, { tool_input: { file_path: join(repo, "bad.txt") } }, { REPO_CHECK_TIMEOUT_MS: "300" });
    expect(result).toEqual({ code: 0, out: "" });
  });

  test("ignores malformed input", () => {
    const { trustFile } = fixture();
    expect(run(trustFile, "not json")).toEqual({ code: 0, out: "" });
    expect(run(trustFile, { tool_input: { file_path: 7 } })).toEqual({ code: 0, out: "" });
  });
});
