# Shared Agent Instructions

These instructions apply to Codex, Claude Code, and Antigravity/Gemini.

The Nix configuration builds the global instruction file by concatenating this
file with every file listed in `nix/lib/agent-instructions.nix`.

Project-local `AGENTS.md` and `CLAUDE.md` files may add or override rules for a
specific repository.

Product-specific behavior stays separate:

- Shared behavior belongs in `agents/rules/`
- Claude Code-only behavior belongs in `claude/rules/`
- Codex-only behavior belongs in `codex/rules/`
- Reusable workflows belong in `agents/skills/`
