#!/usr/bin/env bash
# PostToolUse: 今回追加されたprint/logの装飾だけを通知する。
set -euo pipefail

exec bun -e '
let input;
try { input = await Bun.stdin.json(); } catch { process.exit(0); }
const file = input?.tool_input?.file_path;
const content = input?.tool_input?.new_string ?? input?.tool_input?.content;
if (typeof file !== "string" || typeof content !== "string") process.exit(0);
const pattern = file.endsWith(".py")
  ? /print\(\s*[fFrR]?["\x27][^\n]*[=*-]{3,}/
  : /\.(?:[cm]?js|jsx|ts|tsx)$/.test(file)
    ? /console\.(?:log|info|warn)\(\s*["\x27\x60][^\n]*[=*-]{3,}/ : null;
if (pattern?.test(content)) {
  console.log(JSON.stringify({ hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: "The inserted text contains decorative separators in a print or console message. Shared writing rules prefer plain diagnostic output."
  }}));
}
'
