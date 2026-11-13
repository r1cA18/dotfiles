#!/usr/bin/env bun
// SessionStart hook shared by Claude Code and Codex: tell the agent which
// catalog capabilities match the project, once per project.
//
// It runs `r1hn capability suggest --json <cwd>`, and prints the matches as
// `additionalContext` the first time a project shows them (and again when the
// set changes). The agent must ask the owner before enabling any of them; the
// r1hn-capabilities skill says how.
//
// Seen sets are kept in `${XDG_STATE_HOME:-~/.local/state}/agent-hooks/capability-suggest.json`
// (`CAPABILITY_SUGGEST_STATE` overrides it). Without r1hn, a catalog or a
// match the hook prints nothing. It always exits 0.
import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

const done = (): never => process.exit(0);

let input: any = {};
try {
  input = JSON.parse(readFileSync(0, "utf8"));
} catch {
  // Codex may start the hook without a body; use the working directory.
}
const cwd = typeof input?.cwd === "string" ? input.cwd : process.cwd();
const event = typeof input?.hook_event_name === "string" ? input.hook_event_name : "SessionStart";
const r1hn = process.env.CAPABILITY_SUGGEST_R1HN ?? "r1hn";

let result: ReturnType<typeof Bun.spawnSync>;
try {
  result = Bun.spawnSync([r1hn, "capability", "suggest", "--json", cwd], {
    stdout: "pipe",
    stderr: "ignore",
    timeout: 4000,
  });
} catch {
  done();
}
if (result!.exitCode !== 0) done();

let answer: { project?: string; suggestions?: { id: string; description?: string; signal?: string }[] };
try {
  answer = JSON.parse(result!.stdout!.toString());
} catch {
  done();
}
const suggestions = answer!.suggestions ?? [];
const project = answer!.project ?? cwd;
if (suggestions.length === 0) done();

const stateFile =
  process.env.CAPABILITY_SUGGEST_STATE ??
  join(process.env.XDG_STATE_HOME ?? join(homedir(), ".local/state"), "agent-hooks/capability-suggest.json");
let seen: Record<string, string> = {};
try {
  if (existsSync(stateFile)) seen = JSON.parse(readFileSync(stateFile, "utf8"));
} catch {
  seen = {};
}
const key = suggestions
  .map((s) => s.id)
  .sort()
  .join(",");
if (seen[project] === key) done();
seen[project] = key;
try {
  mkdirSync(dirname(stateFile), { recursive: true });
  const tmp = `${stateFile}.${process.pid}`;
  writeFileSync(tmp, JSON.stringify(seen, null, 2) + "\n");
  renameSync(tmp, stateFile);
} catch {
  // Not remembering only means the note shows again next time.
}

const lines = suggestions.map((s) => `- ${s.id}: ${s.description ?? ""} (${s.signal ?? "match"})`);
console.log(
  JSON.stringify({
    hookSpecificOutput: {
      hookEventName: event,
      additionalContext: [
        `r1hn capability catalog entries match this project (${project}) and are not enabled here:`,
        ...lines,
        "If one would help the current task, ask the owner first. Only after a yes run `r1hn capability enable ID --project .` (see the r1hn-capabilities skill). Do not enable anything without asking.",
      ].join("\n"),
    },
  }),
);
