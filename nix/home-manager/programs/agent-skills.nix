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
      # Global skills only. Domain-specific skills are in packs
      # (nix/lib/skill-packs.nix) and loaded per-project via devShell.
      enable = [
        # custom (global)
        "agent-browser"
        "agent-reach"
        "pdf"
        "xlsx"
        "post-review"
        "skill-builder"
        "skill-auditor"
        "autonomous-dev"
        "project-init"
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
        # vault (global)
        "knowledge-extract"
        # taste-skill collection (anti-slop frontend). Managed as one unit:
        # comment out this block to disable all 13 at once.
        # IDs are directory names; the frontmatter `name` (what triggers) differs.
        "taste-skill" # name: design-taste-frontend (flagship, contextual anti-slop)
        "taste-skill-v1" # name: design-taste-frontend-v1 (backward-compat)
        "soft-skill" # name: high-end-visual-design (high-end agency aesthetic)
        "minimalist-skill" # name: minimalist-ui (editorial minimalism)
        "brutalist-skill" # name: industrial-brutalist-ui (tactical terminal)
        "gpt-tasteskill" # name: gpt-taste (GSAP motion-heavy frontend)
        "redesign-skill" # name: redesign-existing-projects (audit + upgrade)
        "output-skill" # name: full-output-enforcement (anti-truncation)
        "stitch-skill" # name: stitch-design-taste (Google Stitch DESIGN.md)
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
