---
name: aside
description: >-
  Use the owner's Aside browser on macOS for tasks that need their logged-in sites, cookies, browsing history or Aside memory: Slack, Gmail, Notion, Google apps, shopping, bookings, dashboards and other sites behind a login. Prefer `aside exec` or the `aside` MCP `exec` tool; use `aside repl` only to inspect screenshots or DOM directly. Do not use for Web search or reading public pages; use the built-in Web tools. Triggers: "use my browser", "check Slack", "look at my Gmail", "do it in Aside". 日本語トリガー:「ブラウザで」「Asideで」「ログインしてるサイトで」「Slack見て」「Gmail確認して」
---

# Aside

Aside is the owner's main browser on macOS. It holds their sign-ins and has
its own agent, site skills and memory.

## Before the first call

Run `aside guide` and read it. The CLI ships the current usage text and it
changes with releases. Run `aside guide repl` before using `aside repl`.

## Choosing the interface

- `aside exec "<task>"` or the MCP `exec` tool: delegate a whole browser task. Default choice
- `aside repl` or the MCP `repl` tool: Playwright-style control when screenshots or DOM are needed
- `aside memory search "<query>" --json`: read the owner's context before asking them about it
- `agent-browser`: isolated headless checks such as a local dev server
- From Linux hosts: `aside host list`, then `--host <mac>`. This needs `aside login` on that host and Remote Control enabled in Aside
- Fallback: when Aside does not answer (the Mac is asleep or offline), use `agent-browser` without the owner's sign-ins and tell the owner which steps need their login

## Rules

- Ask the owner before an action that sends a message, posts, buys, books, deletes or changes account settings, unless the request already says to do exactly that
- Pass the confirmed text verbatim when the task sends a message
- Do not edit Aside memory files; route remember requests through `aside exec`
- Run `aside session delete` only after the owner approves it
- Report the session id so the owner can resume it with `aside session resume <id>`
- Do not print cookies, tokens or one-time codes that appear in pages or outputs
