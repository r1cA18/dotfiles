import { afterEach, describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const fixtures: string[] = [];
function hook(name: string, input: unknown, cwd = import.meta.dir) {
  const result = Bun.spawnSync(["bash", join(import.meta.dir, name)], {
    cwd,
    stdin: Buffer.from(JSON.stringify(input)),
    stdout: "pipe",
    stderr: "pipe",
  });
  return { code: result.exitCode, out: result.stdout.toString(), err: result.stderr.toString() };
}

function git(cwd: string, ...args: string[]) {
  const result = Bun.spawnSync(["git", "-C", cwd, ...args], { stdout: "pipe", stderr: "pipe" });
  expect(result.exitCode).toBe(0);
}

afterEach(() => {
  for (const root of fixtures.splice(0)) rmSync(root, { recursive: true, force: true });
});

describe("Claude advisory hooks", () => {
  test("emoji in product data is advisory and never a permission decision", () => {
    const result = hook("emoji-guard.sh", {
      tool_name: "Write", tool_input: { file_path: "data.json", content: String.fromCodePoint(0x1f600) },
    });
    expect(result.code).toBe(0);
    const output = JSON.parse(result.out).hookSpecificOutput;
    expect(output.hookEventName).toBe("PreToolUse");
    expect(output.additionalContext).toContain("Emoji");
    expect(output.permissionDecision).toBeUndefined();
  });

  test("plain text produces no emoji warning", () => {
    expect(hook("emoji-guard.sh", { tool_name: "Edit", tool_input: { new_string: "hello" } }).out).toBe("");
  });

  test("large-file threshold uses UTF-8 bytes and emits structured context", () => {
    const result = hook("large-file-guard.sh", { tool_input: { file_path: "article.md", content: "\u3042".repeat(18000) } });
    expect(result.code).toBe(0);
    const output = JSON.parse(result.out).hookSpecificOutput;
    expect(output.hookEventName).toBe("PreToolUse");
    expect(output.additionalContext).toContain("52");
  });

  test("decoration scan only considers inserted text", () => {
    const root = mkdtempSync(join(tmpdir(), "slop-hook-"));
    fixtures.push(root);
    const file = join(root, "app.ts");
    writeFileSync(file, 'console.log("=== old ===");\nconst count = 1;\n');
    expect(hook("ai-slop-guard.sh", { tool_input: { file_path: file, new_string: "const count = 1;" } }).out).toBe("");
    const result = hook("ai-slop-guard.sh", { tool_input: { file_path: file, new_string: 'console.log("=== new ===");' } });
    expect(JSON.parse(result.out).hookSpecificOutput.hookEventName).toBe("PostToolUse");
  });

  test("commit reminder reads staged content even after the working file is cleaned", () => {
    const root = mkdtempSync(join(tmpdir(), "commit-hook-"));
    fixtures.push(root);
    git(root, "init", "--quiet");
    const file = join(root, "app.ts");
    writeFileSync(file, "console.log('debug');\n");
    git(root, "add", "app.ts");
    writeFileSync(file, "export const value = 1;\n");
    const result = hook("debug-print-guard.sh", { cwd: root, tool_input: { command: "git commit -m fix" } }, root);
    expect(result.code).toBe(0);
    expect(JSON.parse(result.out).hookSpecificOutput.additionalContext).toContain("app.ts");
    const redirected = hook("debug-print-guard.sh", {
      cwd: import.meta.dir, tool_input: { command: `git -C '${root}' commit -m fix` },
    });
    expect(JSON.parse(redirected.out).hookSpecificOutput.additionalContext).toContain("app.ts");
  });

  test("commit text inside an unrelated command does not trigger a scan", () => {
    expect(hook("debug-print-guard.sh", { tool_input: { command: "printf '%s' 'git commit'" } }).out).toBe("");
  });

  test("unstaged diagnostics do not warn when staged content is clean", () => {
    const root = mkdtempSync(join(tmpdir(), "clean-index-hook-"));
    fixtures.push(root);
    git(root, "init", "--quiet");
    writeFileSync(join(root, "app.ts"), "export const value = 1;\n");
    git(root, "add", "app.ts");
    writeFileSync(join(root, "app.ts"), "console.log('debug');\n");
    expect(hook("debug-print-guard.sh", { cwd: root, tool_input: { command: "git commit -m fix" } }, root).out).toBe("");
  });

  test("equality expressions are not decorative output", () => {
    expect(hook("ai-slop-guard.sh", {
      tool_input: { file_path: "app.ts", new_string: "console.log(value === other);" },
    }).out).toBe("");
  });
});
