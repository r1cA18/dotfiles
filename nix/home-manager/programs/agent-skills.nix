{ inputs, pkgs, ... }:
{
  programs.agent-skills = {
    enable = true;

    sources = {
      # 自作スキル (dotfiles/agents/skills/)
      # maxDepth = 1: recursive discovery (default since PR #20) + symlink-tree
      # causes Permission denied when parent is symlinked and children try to
      # create inside it (e.g. swift-dev-toolkit/skills/build/).
      custom = {
        path = ../../../agents/skills;
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

      # App Store screenshot generation
      app-store-screenshots = {
        path = inputs.app-store-screenshots;
        subdir = "skills";
      };

      # NotebookLM integration
      notebooklm-skill = {
        path = inputs.notebooklm-skill;
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
        # design (global)
        "frontend-design"
        "baseline-ui"
        "ui-skills"
        "web-design-guidelines"
        # difit
        "difit"
        "difit-review"
        # notebooklm
        "notebooklm-skill"
      ];

      # Transform API: rewrite SKILL.md at build time to inject Nix store paths.
      explicit = {
        video-editing = {
          from = "custom";
          packages = [ pkgs.ffmpeg ];
          transform =
            { original, dependencies }:
            builtins.replaceStrings
              [
                "- **FFmpeg** - `brew install ffmpeg`"
                "- **Bun** - `curl -fsSL https://bun.sh/install | bash`"
                "- **Whisper**（オプション）- `pip install whisper-timestamped`"
              ]
              [
                "- **FFmpeg** - available via Nix"
                "- **Bun** - available via Nix"
                "- **Whisper**（オプション）- `nix run nixpkgs#whisper-ctranslate2`"
              ]
              original
            + "\n"
            + dependencies;
        };
      };
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
