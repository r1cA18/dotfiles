import { afterEach, describe, expect, test } from "bun:test";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const fixtures: string[] = [];
const script = join(import.meta.dir, "check-knowledge-index.ts");

function fixture(index = "") {
  const root = mkdtempSync(join(tmpdir(), "knowledge-hook-"));
  fixtures.push(root);
  const knowledge = join(root, "20_Knowledge");
  mkdirSync(knowledge);
  writeFileSync(join(knowledge, "_index.md"), index);
  writeFileSync(join(knowledge, "Note.md"), "Note\n");
  return { root, knowledge };
}

function run(root: string, args: string[], input: unknown = {}) {
  const result = Bun.spawnSync([process.execPath, script, ...args], {
    cwd: root,
    env: { ...process.env, VAULT_DIR: root },
    stdin: Buffer.from(typeof input === "string" ? input : JSON.stringify(input)),
    stdout: "pipe",
    stderr: "pipe",
  });
  return { code: result.exitCode, out: result.stdout.toString(), err: result.stderr.toString() };
}

afterEach(() => {
  for (const root of fixtures.splice(0)) rmSync(root, { recursive: true, force: true });
});

describe("knowledge index hook", () => {
  test("reports a missing note in explicit full checks", () => {
    const { root } = fixture();
    const result = run(root, ["--all"]);
    expect(result.code).toBe(2);
    expect(result.err).toContain("[[Note]]");
  });

  test.each(["[[Note]]", "[[Note|Label]]", "[[Note#Section]]", "[[20_Knowledge/Note.md|Label]]"])(
    "accepts an existing wiki link: %s",
    (index) => {
      const { root } = fixture(index);
      expect(run(root, ["--all"]).code).toBe(0);
    },
  );

  test("does not treat a different folder's note as coverage", () => {
    const { root } = fixture("[[Elsewhere/Note]]");
    expect(run(root, ["--all"]).code).toBe(2);
  });

  test("does not continue a Stop-triggered continuation again", () => {
    const { root } = fixture();
    const result = run(root, ["--stop", "--if-cwd", root], {
      hook_event_name: "Stop",
      cwd: root,
      stop_hook_active: true,
    });
    expect(result.code).toBe(0);
    expect(result.out + result.err).toBe("");
  });

  test("checks the first Stop within the vault", () => {
    const { root } = fixture();
    expect(run(root, ["--stop", "--if-cwd", root], {
      hook_event_name: "Stop", cwd: root, stop_hook_active: false,
    }).code).toBe(2);
  });

  test("ignores Stop from a sibling directory", () => {
    const { root } = fixture();
    expect(run(root, ["--stop", "--if-cwd", root], {
      hook_event_name: "Stop", cwd: `${root}-other`, stop_hook_active: false,
    }).code).toBe(0);
  });

  test("does not read transcripts or fail on malformed event data", () => {
    const { root } = fixture();
    expect(run(root, ["--stop"], "invalid").code).toBe(0);
    expect(run(root, [], { tool_input: { file_path: 123 } }).code).toBe(0);
  });

  test("checks an edited index and ignores non-note edits", () => {
    const { root, knowledge } = fixture();
    expect(run(root, [], { tool_input: { file_path: join(knowledge, "_index.md") } }).code).toBe(2);
    expect(run(root, [], { tool_input: { file_path: join(knowledge, "asset.png") } }).code).toBe(0);
  });

  test("requires a directory after --if-cwd", () => {
    const { root } = fixture();
    expect(run(root, ["--all", "--if-cwd"]).code).toBe(1);
  });
});
