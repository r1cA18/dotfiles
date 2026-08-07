#!/usr/bin/env bun
// vault の 20_Knowledge/_index.md のカバレッジ検査。エージェント非依存の共有hook。
//
// 使い方:
//   (default)          Claude Code PostToolUse: stdin の hook JSON から
//                      tool_input.file_path を読み、20_Knowledge 配下の
//                      ノート編集時のみ検査する
//   --all              stdin を無視して全件検査 (Codex Stop hook / 手動 / CI)
//   --if-cwd <dir>     --all と併用。cwd が <dir> 配下でなければ何もしない
//
// 未掲載ノートがあれば stderr に一覧を出して exit 2 (エージェントに
// フィードバックされる)。それ以外は exit 0。
import { readdirSync, readFileSync } from "node:fs";
import { isAbsolute, join, relative, resolve, sep } from "node:path";

const isWithin = (candidate: string, parent: string): boolean => {
  const pathFromParent = relative(resolve(parent), resolve(candidate));
  return (
    pathFromParent === "" ||
    (pathFromParent !== ".." && !pathFromParent.startsWith(`..${sep}`) && !isAbsolute(pathFromParent))
  );
};

const vaultDir = process.env.VAULT_DIR ?? join(process.env.HOME ?? "", "vault");
const knowledgeDir = join(vaultDir, "20_Knowledge");

const args = process.argv.slice(2);
const allMode = args.includes("--all");
const ifCwdIdx = args.indexOf("--if-cwd");
const ifCwd = ifCwdIdx >= 0 ? args[ifCwdIdx + 1] : null;

if (allMode) {
  if (ifCwd && !isWithin(process.cwd(), ifCwd)) {
    process.exit(0);
  }
} else {
  // hook mode: 対象ファイルが 20_Knowledge 配下のノートのときだけ検査する
  let input = "";
  try {
    input = readFileSync(0, "utf8");
  } catch {
    process.exit(0);
  }
  let filePath = "";
  try {
    const json = JSON.parse(input);
    filePath = json?.tool_input?.file_path ?? json?.tool_response?.filePath ?? "";
  } catch {
    process.exit(0);
  }
  if (!filePath) process.exit(0);
  const resolved = resolve(filePath);
  if (!isWithin(resolved, knowledgeDir)) process.exit(0);
  if (resolved.endsWith("_index.md")) process.exit(0);
}

// macOS のファイル名は NFD、index 本文は NFC のことがあるので両方 NFC に揃える
let index: string;
try {
  index = readFileSync(join(knowledgeDir, "_index.md"), "utf8").normalize("NFC");
} catch {
  process.exit(0); // vault が無い環境では何もしない
}
const missing = readdirSync(knowledgeDir)
  .filter((f) => f.endsWith(".md") && f !== "_index.md")
  .map((f) => f.replace(/\.md$/, "").normalize("NFC"))
  .filter((name) => !index.includes(`[[${name}]]`));

if (missing.length > 0) {
  console.error(
    `20_Knowledge/_index.md に未掲載のノートがある。1行説明を添えて適切なセクションに追記すること:\n${missing.map((m) => `- [[${m}]]`).join("\n")}`,
  );
  process.exit(2);
}
process.exit(0);
