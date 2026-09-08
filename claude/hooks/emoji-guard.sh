#!/usr/bin/env bash
# PreToolUse: emoji候補を通知する。product dataを含むためblockしない。
set -euo pipefail

exec bun -e '
let input;
try { input = await Bun.stdin.json(); } catch { process.exit(0); }
const content = input?.tool_name === "Edit" ? input.tool_input?.new_string
  : input?.tool_name === "Write" ? input.tool_input?.content : null;
if (typeof content !== "string") process.exit(0);
if (/\p{Extended_Pictographic}|\p{Regional_Indicator}|\u20e3/u.test(content)) {
  console.log(JSON.stringify({ hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: "Emoji-like symbols occur in this edit. Shared writing rules exclude decorative emoji from comments and Markdown; product data or explicit requirements may be intentional."
  }}));
}
'
