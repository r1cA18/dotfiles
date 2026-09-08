#!/usr/bin/env bash
# PreToolUse: UTF-8で50KiBを超える書き込みを通知する。
set -euo pipefail

exec bun -e '
let input;
try { input = await Bun.stdin.json(); } catch { process.exit(0); }
const content = input?.tool_input?.content;
if (typeof content !== "string") process.exit(0);
const bytes = Buffer.byteLength(content, "utf8");
if (bytes > 51200) {
  console.log(JSON.stringify({ hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: `This write contains ${Math.floor(bytes / 1024)}KiB of UTF-8 content. Large generated files may belong outside source control.`
  }}));
}
'
