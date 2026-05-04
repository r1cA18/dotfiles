{
  config,
  lib,
  username,
  pkgs,
  ...
}:
let
  homeDir = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
  dotfilesDir = "${homeDir}/dotfiles";

  trustedProjects = [
    "/Users/r1ca18"
    "/Users/r1ca18/dotfiles"
    "/Users/r1ca18/vault"
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
    "google-calendar@openai-curated"
    "github@openai-curated"
    "browser-use@openai-bundled"
    "documents@openai-primary-runtime"
    "spreadsheets@openai-primary-runtime"
    "presentations@openai-primary-runtime"
  ];
in
{
  programs.codex = {
    enable = true;
    package = null; # installed via packages.nix instead, keeps install in one place

    settings = {
      # No top-level `model` / `model_reasoning_effort`: defaults come from
      # `profiles.default` and the `cx()` shell function always passes
      # `--profile default` (or --heavy / --spark). This avoids two-place
      # maintenance when changing the default model.

      project_doc_fallback_filenames = [
        "CODEX.md"
        "AGENTS.md"
        "CLAUDE.md"
      ];

      tool_output_token_limit = 25000;
      model_auto_compact_token_limit = 233000;
      web_search = "live";

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

      mcp_servers.linear.url = "https://mcp.linear.app/mcp";

      projects = lib.listToAttrs (
        map (p: lib.nameValuePair p { trust_level = "trusted"; }) trustedProjects
      );

      plugins = lib.listToAttrs (map (p: lib.nameValuePair p { enabled = true; }) enabledPlugins);

      profiles = {
        default = {
          model = "gpt-5.4";
          model_reasoning_effort = "medium";
        };
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
  };

  home.file = {
    # AGENTS.md is shared with Claude (edit-and-go, no rebuild needed for content updates)
    ".codex/AGENTS.md".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/shared/GLOBAL_INSTRUCTIONS.md";

    # Sub-account: mirror primary config via symlinks (matches ~/.claude-sub pattern).
    # auth.json (OAuth tokens) stays separate; everything else is shared.
    ".codex-sub/config.toml".source =
      config.lib.file.mkOutOfStoreSymlink "${homeDir}/.codex/config.toml";
    ".codex-sub/AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink "${homeDir}/.codex/AGENTS.md";
    ".codex-sub/skills".source = config.lib.file.mkOutOfStoreSymlink "${homeDir}/.codex/skills";
  };
}
