#!/usr/bin/env bun
// vault の 20_Knowledge/_index.md のカバレッジ検査。エージェント非依存の共有hook。
//
// 使い方:
//   (default)          Claude Code PostToolUse: stdin の hook JSON から
//                      tool_input.file_path を読み、20_Knowledge 配下の
//                      ノート編集時のみ検査する
//   --all              stdin を無視して全件検査 (手動 / CI)
//   --stop             Stop JSON を読み、最初の停止時だけ全件検査する
//   --if-cwd <dir>     --all / --stop と併用。対象 cwd 以外では何もしない
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
const stopMode = args.includes("--stop");
const ifCwdIdx = args.indexOf("--if-cwd");
const ifCwd = ifCwdIdx >= 0 ? args[ifCwdIdx + 1] : null;

if ((ifCwdIdx >= 0 && (!ifCwd || ifCwd.startsWith("--"))) || (allMode && stopMode)) {
  console.error("Usage: check-knowledge-index.ts [--all | --stop] [--if-cwd <dir>]");
  process.exit(1);
}

if (!allMode) {
  let input;
  try {
    input = JSON.parse(readFileSync(0, "utf8"));
  } catch {
    process.exit(0);
  }
  if (stopMode) {
    if (input?.hook_event_name !== "Stop" || input.stop_hook_active === true) process.exit(0);
    const cwd = typeof input.cwd === "string" ? input.cwd : process.cwd();
    if (ifCwd && !isWithin(cwd, ifCwd)) process.exit(0);
  } else {
    const filePath = input?.tool_input?.file_path ?? input?.tool_response?.filePath;
    if (typeof filePath !== "string" || !filePath.endsWith(".md")) process.exit(0);
    const cwd = typeof input?.cwd === "string" ? input.cwd : process.cwd();
    if (!isWithin(resolve(cwd, filePath), knowledgeDir)) process.exit(0);
  }
} else if (ifCwd && !isWithin(process.cwd(), ifCwd)) {
  process.exit(0);
}

// macOS のファイル名は NFD、index 本文は NFC のことがあるので両方 NFC に揃える
let index: string;
try {
  index = readFileSync(join(knowledgeDir, "_index.md"), "utf8").normalize("NFC");
} catch {
  process.exit(0); // vault が無い環境では何もしない
}
const linkedNotes = new Set(
  Array.from(index.matchAll(/\[\[([^\]\n]+)\]\]/g), ([, link]) =>
    link.split(/[|#]/, 1)[0].replace(/^20_Knowledge\//, "").replace(/\.md$/, ""),
  ),
);
const missing = readdirSync(knowledgeDir)
  .filter((f) => f.endsWith(".md") && f !== "_index.md")
  .map((f) => f.replace(/\.md$/, "").normalize("NFC"))
  .filter((name) => !linkedNotes.has(name));

if (missing.length > 0) {
  console.error(
    `20_Knowledge/_index.md に未掲載のノートがある。1行説明を添えて適切なセクションに追記すること:\n${missing.map((m) => `- [[${m}]]`).join("\n")}`,
  );
  process.exit(2);
}
process.exit(0);
