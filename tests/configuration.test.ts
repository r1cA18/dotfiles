import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const repoRoot = resolve(import.meta.dir, "..");
const supportedPlatform =
  (process.platform === "darwin" && process.arch === "arm64") ||
  (process.platform === "linux" && process.arch === "x64");
const nixTest = test.skipIf(
  process.env.DOTFILES_TEST_NIX !== "1" || !supportedPlatform,
);

function sourceReference(path: string): string {
  const configuration = process.platform === "darwin"
    ? "darwinConfigurations.RMB.config.home-manager.users.r1ca18"
    : 'homeConfigurations."r1ca18@homelab".config';
  return `path:${repoRoot}#${configuration}.home.file.${JSON.stringify(path)}.source`;
}

function buildSource(path: string): string {
  const result = Bun.spawnSync([
    "nix",
    "build",
    "--no-write-lock-file",
    "--no-link",
    "--print-out-paths",
    sourceReference(path),
  ], { stdout: "pipe", stderr: "pipe" });
  expect(result.exitCode, result.stderr.toString()).toBe(0);
  const outputs = result.stdout.toString().trim().split("\n").filter(Boolean);
  expect(outputs).toHaveLength(1);
  return outputs[0];
}

nixTest("generated global instructions keep the Codex-only policy boundary", () => {
  const commonSources = [
    "agents/INSTRUCTIONS.md",
    "agents/rules/engineering.md",
    "agents/rules/orchestration.md",
    "agents/rules/style.md",
    "agents/rules/environment.md",
    "agents/rules/tool-preferences.md",
  ];
  const common = commonSources
    .map((path) => readFileSync(join(repoRoot, path), "utf8"))
    .join("\n\n");
  const codexOnly = readFileSync(
    join(repoRoot, "codex/rules/orchestration.md"),
    "utf8",
  );

  const claude = readFileSync(buildSource(".claude/CLAUDE.md"), "utf8");
  const gemini = readFileSync(buildSource(".gemini/GEMINI.md"), "utf8");
  const codex = readFileSync(buildSource(".codex/AGENTS.md"), "utf8");

  expect(claude).toBe(common);
  expect(gemini).toBe(common);
  expect(claude).not.toContain(codexOnly.trim());
  expect(gemini).not.toContain(codexOnly.trim());
  expect(codex).toBe(`${common}\n\n${codexOnly}`);
  expect(codex.indexOf(common)).toBe(0);
  expect(codex.indexOf(codexOnly)).toBe(common.length + 2);
});
