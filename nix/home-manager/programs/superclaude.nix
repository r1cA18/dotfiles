# SuperClaude Framework — cherry-picked agents for Claude Code / Codex.
#
# Agents are self-contained markdown personas with no @import or MCP
# dependencies. They are deployed as sc-*.md into both ~/.claude/agents/
# and ~/.codex/prompts/ so both platforms can use them.
#
# Update: `nix flake update superclaude --flake ~/dotfiles` then `dr`.
{
  inputs,
  lib,
  ...
}:
let
  scAgentsDir = "${inputs.superclaude}/plugins/superclaude/agents";

  # Agents to deploy. All are self-contained (no @import / MCP deps).
  # Excluded: deep-research* (existing skill), quality-engineer / self-review
  # (post-review covers), pm-agent (autonomous-dev covers), python-expert
  # (environment-specific), learning-guide (socratic-mentor covers),
  # repo-index (meta utility).
  selectedAgents = [
    "system-architect"
    "backend-architect"
    "frontend-architect"
    "devops-architect"
    "performance-engineer"
    "security-engineer"
    "root-cause-analyst"
    "refactoring-expert"
    "requirements-analyst"
    "technical-writer"
    "business-panel-experts"
    "socratic-mentor"
  ];

  mkAgentEntries =
    targetPrefix:
    lib.listToAttrs (
      map (name: {
        name = "${targetPrefix}/sc-${name}.md";
        value = {
          source = "${scAgentsDir}/${name}.md";
        };
      }) selectedAgents
    );
in
{
  home.file = mkAgentEntries ".claude/agents" // mkAgentEntries ".codex/prompts";
}
