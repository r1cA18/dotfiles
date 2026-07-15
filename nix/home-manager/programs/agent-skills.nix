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

      # Typst document authoring
      typst-skills = {
        path = inputs.typst-skills;
      };

      # taste-skill: anti-slop frontend skill collection
      # subdir = "skills": recursive discovery finds skills/<variant>/SKILL.md
      # (same one-level nesting as anthropic source; no maxDepth needed).
      taste-skill = {
        path = inputs.taste-skill;
        subdir = "skills";
      };

      # text-to-lottie: Lottie (Bodymovin) animation authoring in a skia player
      # subdir = "skills": discovery finds skills/text-to-lottie/SKILL.md.
      lottie = {
        path = inputs.lottie;
        subdir = "skills";
      };

    };

    skills = {
      # All skills are global. Keep project flakes focused on ordinary Nix
      # dev environments, not agent runtime switching.
      enable = [
        # custom (global)
        "agent-browser"
        "pdf"
        "xlsx"
        "post-review"
        "skill-builder"
        "skill-auditor"
        "idea-to-ship"
        "project-init"
        "swift-dev-toolkit"
        "ios-device-build"
        "codex-app-screenshots"
        # shipswift-* disabled: requires the shipswift MCP server, which is not
        # configured. Re-add the three IDs here after setting up the server.
        "vercel-react-best-practices"
        "remotion-best-practices"
        "session-documentation"
        "design-capture"
        "forms-archive"
        "x-article-publisher"
        "x-research"
        # design (global)
        "frontend-design"
        "baseline-ui"
        "web-design-guidelines"
        # difit
        "difit"
        "difit-review"
        # notebooklm
        "notebooklm-skill"
        # vault (global)
        "knowledge-extract"
        # app screenshots
        "app-store-screenshots"
        # research / publishing helpers
        "typst-author"
        "touying-author"
        # media helpers
        "text-to-lottie"
        # taste-skill collection (anti-slop frontend), trimmed to the variants
        # in active use (2026-07 skill audit). Style variants (taste-skill-v1 /
        # soft-skill / minimalist-skill / brutalist-skill / gpt-tasteskill /
        # stitch-skill) remain in the flake input; re-add IDs here to enable.
        # IDs are directory names; the frontmatter `name` (what triggers) differs.
        "taste-skill" # name: design-taste-frontend (flagship, contextual anti-slop)
        "redesign-skill" # name: redesign-existing-projects (audit + upgrade)
        "output-skill" # name: full-output-enforcement (anti-truncation)
        "image-to-code-skill" # name: image-to-code (image-first then implement)
        "brandkit" # name: brandkit (brand identity image generation)
        "imagegen-frontend-web" # name: imagegen-frontend-web (web reference images)
        "imagegen-frontend-mobile" # name: imagegen-frontend-mobile (mobile images)
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
