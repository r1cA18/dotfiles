---
name: find-skills
description: Discover reusable agent skills without installing unmanaged global files. Use when the user asks whether a skill exists or wants to extend agent capabilities.
---

# Find Skills

Search the public skill catalog when a reusable workflow may already exist.

## Search

Use the temporary CLI through Bun.

```bash
bunx skills find <query>
```

Present relevant candidates with their source repository and intended use.
Inspect the selected `SKILL.md`, supporting scripts, and license before proposing installation.

## Installation Boundary

Do not run `skills add -g` or write to `~/.agents/skills`.

Persistent skills are managed through this dotfiles repository:

1. Add or reuse a pinned flake input for the upstream repository.
2. Register the source and skill ID in `nix/home-manager/programs/agent-skills.nix`.
3. Use `agents/skills/` only for repository-owned or intentionally adapted skills.
4. Apply with `dr` after the user approves the source and scope.

If no skill is suitable, handle the task directly. Create a new skill only for a workflow that is expected to be reused.
