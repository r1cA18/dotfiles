import { afterEach, expect, test } from "bun:test";
import { chmodSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const script = join(import.meta.dir, "capability-suggest.ts");
const dirs: string[] = [];

afterEach(() => {
  for (const dir of dirs.splice(0)) rmSync(dir, { recursive: true, force: true });
});

// A stand-in r1hn that answers `capability suggest --json DIR` with $ANSWER.
function fixture(answer: string, status = 0) {
  const dir = mkdtempSync(join(tmpdir(), "capability-suggest-"));
  dirs.push(dir);
  const bin = join(dir, "r1hn");
  writeFileSync(bin, `#!/usr/bin/env bash\n[ "$1 $2 $3" = "capability suggest --json" ] || exit 9\ncat <<'JSON'\n${answer}\nJSON\nexit ${status}\n`);
  chmodSync(bin, 0o755);
  return { bin, state: join(dir, "state.json") };
}

function run(bin: string, state: string, cwd = "/repo") {
  const result = Bun.spawnSync([process.execPath, script], {
    stdin: new TextEncoder().encode(JSON.stringify({ cwd, hook_event_name: "SessionStart" })),
    env: { ...process.env, CAPABILITY_SUGGEST_R1HN: bin, CAPABILITY_SUGGEST_STATE: state },
  });
  expect(result.exitCode).toBe(0);
  return result.stdout.toString().trim();
}

const answer = JSON.stringify({
  project: "/repo",
  suggestions: [{ id: "swift-dev-toolkit", description: "Swift", signal: "file Package.swift" }],
});

test("tells the agent once per project and asks it to ask the owner", () => {
  const { bin, state } = fixture(answer);
  const first = JSON.parse(run(bin, state));
  const context = first.hookSpecificOutput.additionalContext;
  expect(first.hookSpecificOutput.hookEventName).toBe("SessionStart");
  expect(context).toContain("swift-dev-toolkit");
  expect(context).toContain("ask the owner first");
  expect(run(bin, state)).toBe("");
});

test("says nothing without matches or without r1hn", () => {
  const empty = fixture(JSON.stringify({ project: "/repo", suggestions: [] }));
  expect(run(empty.bin, empty.state)).toBe("");
  const failing = fixture("{}", 1);
  expect(run(failing.bin, failing.state)).toBe("");
  expect(run("/nonexistent/r1hn", failing.state)).toBe("");
});
