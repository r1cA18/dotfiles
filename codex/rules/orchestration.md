# Codex Single-Agent Execution

This Codex-specific policy overrides the shared delegation preferences until the
owner explicitly changes it. Perform all work in the current agent.

- Do not spawn, resume, or assign work to sub-agents, including exploration, implementation, and review agents
- Do not delegate through another CLI, product bridge, or background agent as a workaround
- Perform investigation, implementation, review, and verification locally in the current session
- If earlier delegated work is still running, stop it without assigning further tasks and inspect its partial changes yourself
- Ordinary tools, test processes, and builds are allowed; parallel tool execution is not agent delegation
- Do not change the main-session model or global model defaults to implement this policy

Keep this restriction in Codex-specific instructions; it does not change the
delegation policy of independently used Claude Code or Antigravity sessions.

## Efficient Tool Waiting

- Prefer completion notifications or a supported blocking wait over repeated status-only calls
- While a tool or build runs, continue useful independent work in this session when available
- When waiting is necessary, estimate the remaining duration and choose a timeout around twice that estimate within the active tool limits and higher-priority responsiveness requirements; use the tool's default when no estimate is available
- Do not repeat minimal-timeout polls just to check unchanged state; after a timeout update the estimate and use a longer permitted wait when appropriate
- Distinguish tool completion from a tool yielding a running session; resume only the returned session with its matching wait mechanism
- Keep output scoped to new evidence and avoid repeatedly loading unchanged logs or files; do not omit required review or verification to save tokens

This does not authorize `wait_agent`, agent spawning, or delegated reviews. Do not
add inactive multi-agent tuning or re-enable multi-agent features to follow an
article. Verify setting support against the installed CLI before any future
change. Treat reported token or credit savings as unverified for this environment
unless measured here; do not change the model or reasoning effort automatically.
