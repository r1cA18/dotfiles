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
