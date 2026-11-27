#!/usr/bin/env bun
// 編集されたfileのrepoにある`scripts/check fast <file>...`を呼び、結果を知らせる共有hook。
// 規則は持たない。何を検査するかは各repoの`scripts/check`が決める。
//
// 入力: Claude CodeのPostToolUse(`tool_input.file_path`)と、Codexの
// PostToolUse(`tool_input.command`にapply_patchのpatch本文)。
//
// 実行する条件:
//   1. 編集されたfileがgit repoの中にある
//   2. repo直下に実行可能な`scripts/check`がある
//   3. repoのremote `origin`が信頼一覧の接頭辞のどれかに一致する
//      一覧は`${XDG_CONFIG_HOME:-~/.config}/repo-check/trusted-remotes`(1行に1つ。
//      例: `github.com/<owner>/`)。`REPO_CHECK_TRUSTED`で別のfileを指せる
//
// 失敗しても作業は止めない。stdoutへ`additionalContext`のJSONを返し、常にexit 0。
// 制限時間を超えた検査は何も出さずに終わる。
import { existsSync, readFileSync, realpathSync, statSync } from "node:fs";
import { dirname, isAbsolute, join, relative, resolve } from "node:path";

const timeoutMs = Number(process.env.REPO_CHECK_TIMEOUT_MS ?? 12000);
const maxLines = 40;

const done = (): never => process.exit(0);

let input: any;
try {
  input = JSON.parse(readFileSync(0, "utf8"));
} catch {
  done();
}
const cwd = typeof input?.cwd === "string" ? input.cwd : process.cwd();
const event = typeof input?.hook_event_name === "string" ? input.hook_event_name : "PostToolUse";

// apply_patchの見出し行から追加と更新と移動先のpathを取る。削除は検査しない
const patchPaths = (patch: string): string[] =>
  Array.from(patch.matchAll(/^\*\*\* (?:Add File|Update File|Move to): (.+)$/gm), ([, path]) => path.trim());

const editedPaths = (): string[] => {
  const toolInput = input?.tool_input;
  const paths: string[] = [];
  if (typeof toolInput?.file_path === "string") paths.push(toolInput.file_path);
  if (typeof toolInput?.command === "string") paths.push(...patchPaths(toolInput.command));
  if (typeof toolInput === "string") paths.push(...patchPaths(toolInput));
  return paths
    .map((path) => resolve(cwd, path))
    .filter((path) => existsSync(path) && statSync(path).isFile())
    .map((path) => realpathSync(path));
};

const git = (dir: string, ...args: string[]): string | null => {
  const result = Bun.spawnSync(["git", "-C", dir, ...args], { stdout: "pipe", stderr: "ignore" });
  return result.exitCode === 0 ? result.stdout.toString().trim() : null;
};

// `git@host:owner/repo.git`と`https://host/owner/repo`を`host/owner/repo`に揃える
const normalizeRemote = (url: string): string =>
  url
    .replace(/^[a-z+]+:\/\//, "")
    .replace(/^[^@/]+@/, "")
    .replace(/^([^/:]+):(?!\d)/, "$1/")
    .replace(/\.git$/, "")
    .toLowerCase();

const trustedPrefixes = (): string[] => {
  const file =
    process.env.REPO_CHECK_TRUSTED ??
    join(process.env.XDG_CONFIG_HOME ?? join(process.env.HOME ?? "", ".config"), "repo-check", "trusted-remotes");
  try {
    return readFileSync(file, "utf8")
      .split("\n")
      .map((line) => line.trim())
      .filter((line) => line && !line.startsWith("#"))
      .map(normalizeRemote);
  } catch {
    return [];
  }
};

const paths = editedPaths();
if (paths.length === 0) done();
const prefixes = trustedPrefixes();
if (prefixes.length === 0) done();

const byRepo = new Map<string, string[]>();
for (const path of paths) {
  const top = git(dirname(path), "rev-parse", "--show-toplevel");
  if (!top) continue;
  const root = realpathSync(top);
  const rel = relative(root, path);
  if (rel.startsWith("..") || isAbsolute(rel)) continue;
  byRepo.set(root, [...(byRepo.get(root) ?? []), rel]);
}

const reports: string[] = [];
for (const [root, files] of byRepo) {
  const check = join(root, "scripts", "check");
  try {
    if ((statSync(check).mode & 0o111) === 0) continue;
  } catch {
    continue;
  }
  const remote = git(root, "remote", "get-url", "origin");
  if (!remote) continue;
  const normalized = normalizeRemote(remote);
  if (!prefixes.some((prefix) => normalized.startsWith(prefix))) continue;

  const result = Bun.spawnSync([check, "fast", ...files], {
    cwd: root,
    stdin: "ignore",
    stdout: "pipe",
    stderr: "pipe",
    timeout: timeoutMs,
  });
  if (result.exitCode === 0 || result.exitCode === null || result.signalCode) continue;
  const output = `${result.stdout.toString()}${result.stderr.toString()}`.trimEnd().split("\n");
  const shown = output.slice(0, maxLines).join("\n");
  const more = output.length > maxLines ? `\n(${output.length - maxLines} more lines)` : "";
  reports.push(`scripts/check fast failed in ${root} (exit ${result.exitCode}):\n${shown}${more}`);
}

if (reports.length > 0) {
  console.log(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: event,
        additionalContext: `${reports.join("\n\n")}\nFix these before finishing, or explain why they are expected.`,
      },
    }),
  );
}
done();
