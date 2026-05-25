{ inputs, ... }:
{
  programs.agent-skills = {
    enable = true;

    sources = {
      # 自作スキル (dotfiles/skills/)
      # maxDepth = 1: recursive discovery (default since PR #20) + symlink-tree
      # causes Permission denied when parent is symlinked and children try to
      # create inside it (e.g. swift-dev-toolkit/skills/build/).
      custom = {
        path = ../../../skills;
        filter.maxDepth = 1;
      };

      # Anthropic 公式スキル
      anthropic = {
        path = inputs.anthropic-skills;
        subdir = "skills";
      };

      # difit スキル
      difit = {
        path = inputs.difit-skills;
        subdir = "skills";
      };

    };

    skills = {
      # Global skills only. Domain-specific skills are in packs
      # (nix/lib/skill-packs.nix) and loaded per-project via devShell.
      enable = [
        # custom (global)
        "agent-browser"
        "pdf"
        "xlsx"
        "post-review"
        "skill-builder"
        "skill-auditor"
        "autonomous-dev"
        # difit
        "difit"
        "difit-review"
      ];
    };

    # Claude / Codex に同期
    targets = {
      claude = {
        dest = "\${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills";
        structure = "symlink-tree";
        enable = true;
        systems = [ ];
      };
      codex = {
        dest = "\${CODEX_HOME:-$HOME/.codex}/skills";
        structure = "symlink-tree";
        enable = true;
        systems = [ ];
      };
      opencode.enable = false;
    };
  };
}
