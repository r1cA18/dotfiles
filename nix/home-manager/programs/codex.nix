{
  config,
  inputs,
  lib,
  username,
  pkgs,
  ...
}:
let
  homeDir = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
  dotfilesDir = "${homeDir}/dotfiles";

  tomlFormat = pkgs.formats.toml { };

  # home, dotfiles, vault は homeDir 由来で両OS共通。
  # Develop 配下の個別プロジェクトは macOS にしか無いので Darwin 限定。
  trustedProjects = [
    homeDir
    dotfilesDir
    "${homeDir}/vault"
  ]
  ++ lib.optionals pkgs.stdenv.isDarwin [
    "/Users/r1ca18/Develop/github.com/r1cA18/syoki"
    "/Users/r1ca18/Develop/github.com/r1cA18/NomadPad-app"
    "/Users/r1ca18/Develop/github.com/r1cA18/mado"
    "/Users/r1ca18/Develop/github.com/r1cA18/zmk-config-ZaruBall-r1cA18"
    "/Users/r1ca18/Develop/github.com/r1cA18/RaycastExtensions"
    "/Users/r1ca18/Develop/github.com/C-Style-team/MobileAndon"
    "/Users/r1ca18/Develop/github.com/C-Style-team/MobileAndon/MobileAndon-Revised"
    "/Users/r1ca18/Develop/github.com/C-Style-team/meeting-logs/aipf-pkg-gijiroku-frontend"
  ];

  enabledPlugins = [
    "claude-code-advisor@claude-plugin-codex"
    "google-calendar@openai-curated"
    "github@openai-curated"
    "browser-use@openai-bundled"
    "documents@openai-primary-runtime"
    "spreadsheets@openai-primary-runtime"
    "presentations@openai-primary-runtime"
  ];

  codexSettings = {
    # Top-level model is the default for `codex` with no --profile (= the cx abbr).
    # Profiles below override per-invocation: cxh = heavy, cxsp = spark.
    model = "gpt-5.5";
    model_reasoning_effort = "high";

    project_doc_fallback_filenames = [
      "CODEX.md"
      "AGENTS.md"
      "CLAUDE.md"
    ];

    tool_output_token_limit = 25000;
    model_auto_compact_token_limit = 233000;
    web_search = "live";

    suppress_unstable_features_warning = true;

    features = {
      skills = true;
      shell_snapshot = true;
      apply_patch_freeform = true;
      multi_agent = true;
    };

    tui.status_line = [
      "model-with-reasoning"
      "context-remaining"
      "current-dir"
      "git-branch"
      "context-used"
      "five-hour-limit"
    ];

    projects = lib.listToAttrs (
      map (p: lib.nameValuePair p { trust_level = "trusted"; }) trustedProjects
    );

    plugins = lib.listToAttrs (map (p: lib.nameValuePair p { enabled = true; }) enabledPlugins);

    marketplaces.claude-plugin-codex = {
      source_type = "local";
      source = "${inputs.claude-plugin-codex}";
    };

    # No profiles.default: top-level fields above are the default.
    # `codex --profile heavy` → gpt-5.5 high, `codex --profile spark` → spark.
    profiles = {
      heavy = {
        model = "gpt-5.5";
        model_reasoning_effort = "high";
      };
      spark = {
        model = "gpt-5.3-codex-spark";
        model_reasoning_effort = "medium";
      };
    };
  };

  codexConfigFile = tomlFormat.generate "codex-config.toml" codexSettings;
in
{
  # NOTE: we deliberately do NOT use programs.codex.settings.
  # That option creates a symlink to /nix/store/... which is read-only.
  # Codex tries to persist runtime state (model migration prompts, /model
  # selection, default model preference) and fails with errors like:
  #   "Failed to save default model: failed to persist config.toml at /nix/store/..."
  #
  # Instead we copy the generated toml as a real writable file each dr.
  # Codex can write at runtime; next dr resets dotfiles defaults.

  home = {
    file = {
      # AGENTS.md is shared with Claude (edit-and-go, no rebuild needed for content updates)
      ".codex/AGENTS.md".source =
        config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/agents/INSTRUCTIONS.md";
      ".codex/prompts".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/codex/prompts";

      # Sub-account: mirror primary config via symlinks (matches ~/.claude-sub pattern).
      # auth.json (OAuth tokens) stays separate; everything else is shared.
      ".codex-sub/config.toml".source =
        config.lib.file.mkOutOfStoreSymlink "${homeDir}/.codex/config.toml";
      ".codex-sub/AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink "${homeDir}/.codex/AGENTS.md";
      ".codex-sub/skills".source = config.lib.file.mkOutOfStoreSymlink "${homeDir}/.codex/skills";
      ".codex-sub/prompts".source = config.lib.file.mkOutOfStoreSymlink "${homeDir}/.codex/prompts";
    };

    activation = {
      codexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        install -d "$HOME/.codex"
        # Remove possible old symlink-to-store (from previous programs.codex.settings setup),
        # then install fresh writable copy of the Nix-generated toml.
        rm -f "$HOME/.codex/config.toml"
        install -m 644 "${codexConfigFile}" "$HOME/.codex/config.toml"
      '';

      codexPlugins = lib.hm.dag.entryAfter [ "codexConfig" ] ''
        if command -v codex >/dev/null 2>&1; then
          CODEX_HOME="$HOME/.codex" codex plugin add claude-code-advisor@claude-plugin-codex >/dev/null 2>&1 || true
        fi
      '';
    };
  };
}
