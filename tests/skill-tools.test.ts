import { afterEach, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const roots: string[] = [];
afterEach(() => { for (const root of roots.splice(0)) rmSync(root, { recursive: true, force: true }); });
const validator = resolve("agents/skills/skill-builder/scripts/validate-skill.ts");
const smoke = resolve("agents/skills/skill-auditor/scripts/trigger_smoke_test.py");

test("maintained skill entrypoints have valid metadata and local references", () => {
  for (const name of ["skill-builder", "skill-auditor", "codex-app-screenshots", "x-article-publisher", "indexion-workspace", "session-handoff"]) {
    const result = Bun.spawnSync([process.execPath, validator, resolve("agents/skills", name)], { stdout: "pipe", stderr: "pipe" });
    expect(result.exitCode, `${name}: ${result.stderr.toString()}`).toBe(0);
  }
});

function fixture() {
  const root = mkdtempSync(join(tmpdir(), "skill-tools-"));
  roots.push(root);
  const skill = join(root, "example-skill");
  mkdirSync(skill);
  writeFileSync(join(skill, "SKILL.md"), "---\nname: example-skill\ndescription: |\n  Validate example input.\n---\n# Example\n");
  return { root, skill };
}

test("skill validator parses multiline YAML and rejects malformed metadata", () => {
  const { skill } = fixture();
  const check = () => Bun.spawnSync([process.execPath, validator, skill]);
  expect(check().exitCode).toBe(0);
  for (const metadata of ["name: [broken", "name: example-skill\ndescription: 42", "- not-a-mapping"]) {
    writeFileSync(join(skill, "SKILL.md"), `---\n${metadata}\n---\n`);
    expect(check().exitCode).toBe(1);
  }
});

test("skill validator checks real references but ignores fenced examples", () => {
  const { skill } = fixture();
  const head = "---\nname: example-skill\ndescription: Check references.\n---\n";
  writeFileSync(join(skill, "SKILL.md"), head + "```md\n[example](missing.md)\n```\n`[text](url)`\n[web](https://example.invalid)\n");
  expect(Bun.spawnSync([process.execPath, validator, skill]).exitCode).toBe(0);
  writeFileSync(join(skill, "SKILL.md"), head + "[reference](reference.md)\n");
  expect(Bun.spawnSync([process.execPath, validator, skill]).exitCode).toBe(1);
  writeFileSync(join(skill, "reference.md"), "Reference");
  expect(Bun.spawnSync([process.execPath, validator, skill]).exitCode).toBe(0);
});

test("trigger adapter distinguishes observations from failed runs without an actual agent", () => {
  const { root, skill } = fixture();
  const bin = join(root, "bin");
  mkdirSync(bin);
  const mock = (name: string, source: string) => writeFileSync(join(bin, name), `#!${process.execPath}\n${source}\n`, { mode: 0o755 });
  mock("agent-skill-path", `console.log(${JSON.stringify(skill)});`);
  mock("claude", 'process.stdout.write(process.env.MOCK_STREAM || ""); process.exit(Number(process.env.MOCK_EXIT || 0));');
  const run = (events: unknown[], exit = "0") => Bun.spawnSync([Bun.which("python3")!, smoke, "fixture prompt", "example-skill"], {
    env: { ...process.env, PATH: bin, MOCK_EXIT: exit, MOCK_STREAM: events.map(event => JSON.stringify(event)).join("\n") },
    stdout: "pipe", stderr: "pipe",
  });
  const success = { type: "result", subtype: "success", is_error: false };
  const invocation = { type: "assistant", message: { content: [{ type: "tool_use", name: "Skill", input: { skill: "example-skill" } }] } };
  expect(run([invocation, success]).exitCode).toBe(0);
  expect(run([success]).exitCode).toBe(1);
  expect(run([invocation]).exitCode).toBe(2);
  expect(run([success], "1").exitCode).toBe(2);
  expect(run([{ type: "result", subtype: "error_max_budget_usd" }]).exitCode).toBe(2);
});
