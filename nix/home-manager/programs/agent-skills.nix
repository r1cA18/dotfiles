{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  # Which skills exist and their tier come from the capability catalog
  # (agents/capabilities/catalog.nix). Where r1hn projects it, the bundle
  # holds every catalog skill and r1hn links them per entry, so this module
  # installs nothing itself (its sync would delete skills added inside a
  # client). Elsewhere it installs the baseline skills as before.
  caps = config.dotfiles.capabilities;
  projected = caps.projectedByR1hn;
  skillEntries = lib.filterAttrs (_: e: e.kind == "skill" && (e.source or null) == null) caps.entries;
  wanted = builtins.attrNames (
    if projected then skillEntries else lib.filterAttrs (_: e: e.tier == "baseline") skillEntries
  );
  explicitIds = builtins.attrNames config.programs.agent-skills.skills.explicit;
  installed = id: builtins.elem id wanted;
in
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

      openai = {
        path = inputs.openai-skills;
        subdir = "skills/.curated";
        filter.nameRegex = "(gh-fix-ci|security-best-practices)";
      };

      trailofbits = {
        path = inputs.trailofbits-skills;
        subdir = "plugins/property-based-testing/skills";
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

      # unslop: discovery finds skills/unslop/SKILL.md (same layout as lottie).
      unslop = {
        path = inputs.unslop;
        subdir = "skills";
      };

      # Orca skills
      orca = {
        path = inputs.orca-skills;
        subdir = "skills";
      };

      # Hugging Face skills (Apache-2.0): Python and ML catalog entries.
      huggingface = {
        path = inputs.huggingface-skills;
        subdir = "skills";
      };

      # last30days (MIT): recent discussion research.
      last30days = {
        path = inputs.last30days-skill;
        subdir = "skills";
      };

      # SwiftUI Pro (MIT): skill directory swiftui-pro at the repository root.
      swiftui = {
        path = inputs.swiftui-agent-skill;
        filter.nameRegex = "swiftui-pro";
      };

    };

    skills = {
      # Ids and tiers live in agents/capabilities/catalog.nix. Skills with a
      # transform are selected through `explicit` below instead.
      enable = builtins.filter (id: !(builtins.elem id explicitIds)) wanted;

      # Transform API: rewrite SKILL.md at build time to inject Nix store paths.
      explicit = {
        gh-fix-ci = {
          enable = installed "gh-fix-ci";
          from = "openai";
          packages = [ pkgs.gh ];
          # Use current gh JSON commands instead of the legacy Python helper.
          transform =
            { dependencies, ... }:
            builtins.readFile ../../../agents/skills/upstream-adapters/gh-fix-ci.md + "\n" + dependencies;
        };

        property-based-testing = {
          enable = installed "property-based-testing";
          from = "trailofbits";
          transform =
            { original, ... }:
            builtins.replaceStrings [ "effort: low\n" ] [ "" ] original
            + ''

              ## Distribution

              By Trail of Bits, from https://github.com/trailofbits/skills.
              Distributed under CC-BY-SA-4.0. Local changes remove the provider-specific
              effort metadata and add these distribution notes.
              Full license: ${inputs.trailofbits-skills}/LICENSE.
              Use the target project's existing test runner and dependency manager.
            '';
        };

        unslop = {
          enable = installed "unslop";
          from = "unslop";
          # Upstream tells the agent to hand out an install command when
          # Playwright or ffmpeg is missing; its scripts suggest npm and brew.
          transform =
            { original, ... }:
            original
            + ''

              ## Local environment (Nix)

              This note is a local addition; the skill above is unchanged.
              Original by Damir Sokolovsky, https://github.com/heydamir/unslop, CC BY 4.0.

              - This machine is managed with Nix. Do not run or suggest `npm install -g`,
                `brew install`, or `npx playwright install`, including when a script's
                error message recommends them.
              - ffmpeg and Node.js are already installed through Nix.
              - Playwright: use the target project's existing devDependency. Otherwise
                run the tool temporarily with `, <cmd>`, `nix shell`, or `nix run`.
              - If a dependency is still missing, report it and skip the story video or
                snapshot step instead of installing anything.
            '';
        };

        video-editing = {
          enable = installed "video-editing";
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

    # Claude / Codex / Antigravity に同期 (r1hn が投影しない host だけ)
    targets = {
      claude = {
        dest = "\${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills";
        structure = "symlink-tree";
        enable = !projected;
        systems = [ ];
      };
      codex = {
        dest = "\${CODEX_HOME:-$HOME/.codex}/skills";
        structure = "symlink-tree";
        enable = !projected;
        systems = [ ];
      };
      antigravity = {
        dest = "$HOME/.gemini/antigravity/skills";
        structure = "symlink-tree";
        enable = !projected;
        systems = [ ];
      };
      # agy (the CLI) reads ~/.gemini/config/skills.
      agy = {
        dest = "$HOME/.gemini/config/skills";
        structure = "symlink-tree";
        enable = !projected;
        systems = [ ];
      };
      opencode.enable = false;
    };
  };
}
