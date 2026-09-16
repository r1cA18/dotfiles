# Local Session Lookup

Use an available native session reader first. When it cannot access the source
account, inspect local transcripts with `rg` and `jq`. These paths describe this
dotfiles environment; custom homes elsewhere must be resolved from the user's
configuration.

| Product | Primary | Additional accounts |
| --- | --- | --- |
| Codex | `~/.codex/sessions` | ccspace space home, e.g. `~/.codex-<name>/sessions` |
| Claude Code | `~/.claude/projects` | ccspace space home, e.g. `~/.claude-<name>/projects` |

An explicit `CODEX_HOME` or `CLAUDE_CONFIG_DIR` can identify another current home.
In this repository, ccspace launchers (`cx-<name>` for Codex, `cc-<name>` for
Claude Code) set these; `ccspace list` shows registered launchers and `ccspace
doctor` checks their homes.
Use paths only; reading `auth.json`, `.claude.json`, or keychains is unnecessary.

## Find A Candidate

Start with a known date or project and list files. Search only transcript
directories, not the entire account home and its plugin caches.

```bash
rg --files "$session_root" -g '*.jsonl'
rg -l -F -g '*.jsonl' -- 'distinctive task phrase' "$session_root"
```

Use Codex `session_meta.payload` to inspect `id`/`session_id`, `cwd`, `timestamp`,
and `source`. Claude records carry `sessionId`, `cwd`, and `timestamp` at the top
level. A child session may repeat the parent's request; distinguish it using
session metadata and its own actual messages.

## Read Plaintext Messages

Run the bundled jq filter against one selected transcript:

```bash
jq -c -f <skill-dir>/scripts/messages.jq "$session_file" | tail -n 20
```

The filter emits role/text objects for Codex `response_item.message` and Claude
`user`/`assistant` messages. It excludes system/developer roles, tool payloads,
reasoning, and encrypted content. It does not redact secrets from message text.
Inspect only relevant excerpts and keep them out of public artifacts.

An empty result is not proof that the conversation was empty. Inspect record
types when formats differ. Older Codex `event_msg` may contain `user_message` or
`agent_message`; use those as a fallback when `response_item.message` is absent.
Do not concatenate both representations and count duplicate messages as new work.

Read selected `function_call` / `custom_tool_call` and corresponding output
records only when needed to establish a decision or verify a claimed action.
Do not replay recorded commands automatically. Some Codex Desktop inter-agent
messages contain only `encrypted_content`; use the child session's plaintext
tool records or repeat the missing narrow check instead.

## Account Boundaries

`cx-<name> resume <id>` searches the selected launcher's account home; `--all`
broadens the directory filter, not the set of account homes. Likewise
`cc-<name> --resume <id>` uses that Claude launcher's history.
Passing another account's ID does not import its session.

For a handoff to a different account/provider, read the relevant source history
into the current task or use a portable summary. Native conversion is a separate
operation requiring source/target homes and a compatible import implementation.
