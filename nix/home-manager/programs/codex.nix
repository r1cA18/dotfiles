{
  config,
  inputs,
  lib,
  username,
  hostname,
  pkgs,
  ...
}:
let
  isDarwin = pkgs.stdenv.isDarwin;
  isHomelabLinux = pkgs.stdenv.isLinux && hostname == "homelab";
  homeDir = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
  dotfilesDir = "${homeDir}/dotfiles";
  olympusLinuxRoot = "/home/r1ca18/Develop/github.com/r1cA18/olympus";
  olympusMcpEntry = "${olympusLinuxRoot}/apps/mcp/src/index.ts";

  tomlFormat = pkgs.formats.toml { };
  sharedAgentInstructions = import ../../lib/agent-instructions.nix { inherit lib pkgs; };
  mkAgentProfileManager = import ../../lib/agent-profile-manager.nix { inherit lib; };

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
    "pdf@openai-primary-runtime"
    "spreadsheets@openai-primary-runtime"
    "presentations@openai-primary-runtime"
    "browser@openai-bundled"
    "chrome@openai-bundled"
  ];

  codexSettings = {
    # Top-level model is the default. Named config layers are generated as
    # $CODEX_HOME/<name>.config.toml below.
    model = "gpt-5.5";
    model_reasoning_effort = "medium";

    # Account profiles rely on CODEX_HOME isolation. Force file storage so
    # credentials do not collapse into one shared OS keychain entry.
    cli_auth_credentials_store = "file";

    # Keep normal commands automatic inside the workspace. Commands that need
    # broader access request escalation and are reviewed by the policy engine.
    approval_policy = "on-request";
    approvals_reviewer = "auto_review";
    sandbox_mode = "workspace-write";

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

    mcp_servers = lib.optionalAttrs (isDarwin || isHomelabLinux) {
      olympus =
        if isDarwin then
          {
            command = "/usr/bin/ssh";
            args = [
              "-T"
              "homelab"
              "/home/r1ca18/.nix-profile/bin/bun"
              "run"
              olympusMcpEntry
            ];
          }
        else
          {
            command = "${pkgs.bun}/bin/bun";
            args = [
              "run"
              olympusMcpEntry
            ];
          };
    };

  };

  codexConfigProfiles = {
    heavy = {
      model = "gpt-5.5";
      model_reasoning_effort = "high";
    };
    spark = {
      model = "gpt-5.3-codex-spark";
      model_reasoning_effort = "medium";
    };
  };

  codexConfigFile = tomlFormat.generate "codex-config.toml" codexSettings;
  codexConfigProfileFiles = lib.mapAttrs (
    name: settings: tomlFormat.generate "codex-${name}-config.toml" settings
  ) codexConfigProfiles;

  codexProfileSharedPaths = [
    "AGENTS.md"
    "config.toml"
    "hooks.json"
    "prompts"
    "skills"
  ]
  ++ map (name: "${name}.config.toml") (builtins.attrNames codexConfigProfiles);
  codexProfileCommon = mkAgentProfileManager {
    productName = "Codex";
    profileStatePath = "codex/profiles";
    primaryConfigPath = ".codex";
    primaryMetadataPath = ".codex/auth.json";
    profileMetadataName = "auth.json";
    sharedPaths = codexProfileSharedPaths;
  };

  # Individual file symlinks for .codex/prompts/. All prompts (including the
  # repo-owned sc-*.md personas) live in codex/prompts/ and are deployed here.
  # readDir uses the flake-relative path (pure-eval safe); symlinks point to
  # the mutable dotfilesDir so edits take effect without rebuild.
  promptFiles = lib.mapAttrs' (
    name: _:
    lib.nameValuePair ".codex/prompts/${name}" {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/codex/prompts/${name}";
      force = true;
    }
  ) (builtins.readDir ../../../codex/prompts);

  codexProfile = pkgs.writeShellApplication {
    name = "cxp";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.fzf
      pkgs.jq
    ];
    text = ''
      ${codexProfileCommon}

      profile_command="cxp"
      codex_bin="$(command -v codex || true)"

      require_codex() {
        if [[ -z "$codex_bin" || ! -x "$codex_bin" ]]; then
          echo "Codex CLI was not found in PATH." >&2
          exit 1
        fi
      }

      profile_email() {
        local auth_file="$1"
        local token payload padding

        [[ -f "$auth_file" ]] || return 0
        token="$(jq -r '.tokens.id_token // empty' "$auth_file" 2>/dev/null || true)"
        [[ -n "$token" ]] || return 0
        payload="''${token#*.}"
        payload="''${payload%%.*}"

        padding=$(( (4 - ''${#payload} % 4) % 4 ))
        case "$padding" in
          1) payload="''${payload}=" ;;
          2) payload="''${payload}==" ;;
          3) payload="''${payload}===" ;;
        esac

        printf '%s' "$payload" \
          | tr '_-' '/+' \
          | base64 --decode 2>/dev/null \
          | jq -r '.email // empty' 2>/dev/null \
          || true
      }

      run_for_profile() {
        local profile="$1"
        shift

        local config_dir
        config_dir="$(resolve_profile "$profile")"
        ensure_shared_config "$config_dir"

        if [[ -n "$config_dir" ]]; then
          export CODEX_HOME="$config_dir"
        else
          unset CODEX_HOME
        fi
        exec "$codex_bin" "$@"
      }

      add_profile() {
        local email="$1"
        local config_dir actual_email

        validate_profile_email "$email"
        if resolve_profile "$email" >/dev/null 2>&1; then
          echo "Codex profile already exists: $email" >&2
          return 1
        fi

        config_dir="$profile_root/$email"
        install -d -m 700 "$config_dir"
        ensure_shared_config "$config_dir"

        CODEX_HOME="$config_dir" "$codex_bin" login
        actual_email="$(profile_email "$config_dir/auth.json")"
        if [[ -n "$actual_email" && "$actual_email" != "$email" ]]; then
          echo "Signed in as $actual_email but the profile path is named $email." >&2
          return 1
        fi
      }

      usage() {
        cat <<'EOF'
      Usage: cxp <command> [arguments]

      Commands:
        list                  List profiles and their signed-in email addresses
        complete              Print profile candidates for shell completion
        add <email>           Create a profile and sign in
        login [profile]       Sign in again for a profile selected by email or fzf
        status [profile]      Show authentication status
        path [profile]        Print the profile CODEX_HOME
        run [profile] [args]  Start Codex with a profile selected by email or fzf
      EOF
      }

      require_codex
      command="''${1:-}"
      if [[ $# -gt 0 ]]; then
        shift
      fi

      case "$command" in
        list)
          list_profiles
          ;;
        complete)
          completion_profiles
          ;;
        add)
          [[ $# -eq 1 ]] || { usage >&2; exit 2; }
          add_profile "$1"
          ;;
        login)
          [[ $# -le 1 ]] || { usage >&2; exit 2; }
          profile="$(select_profile "''${1:-}")"
          run_for_profile "$profile" login
          ;;
        status)
          [[ $# -le 1 ]] || { usage >&2; exit 2; }
          profile="$(select_profile "''${1:-}")"
          run_for_profile "$profile" login status
          ;;
        path)
          [[ $# -le 1 ]] || { usage >&2; exit 2; }
          profile="$(select_profile "''${1:-}")"
          config_dir="$(resolve_profile "$profile")"
          printf '%s\n' "''${config_dir:-$HOME/.codex}"
          ;;
        run)
          profile="$(select_profile "''${1:-}")"
          if [[ $# -gt 0 ]]; then
            shift
          fi
          run_for_profile "$profile" "$@"
          ;;
        help|-h|--help|"")
          usage
          ;;
        *)
          echo "Unknown command: $command" >&2
          usage >&2
          exit 2
          ;;
      esac
    '';
  };
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
    packages = [ codexProfile ];

    file = {
      # Built from agents/INSTRUCTIONS.md + agents/rules/*.md.
      ".codex/AGENTS.md".source = sharedAgentInstructions;

      # Lifecycle hooks (Claude 互換スキーマ)。スクリプト本体は
      # agents/hooks/ に置き Claude Code と共有する。内容を変えたら
      # codex 側で /hooks から再 trust が必要。
      ".codex/hooks.json" = {
        source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/codex/hooks.json";
        force = true;
      };
    }
    // promptFiles;

    activation = {
      cleanBrokenCodexPromptSymlinks = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        target="$HOME/.codex/prompts"
        if [ -L "$target" ] && [ ! -e "$target" ]; then
          rm -f "$target"
        fi
      '';

      codexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        install -d "$HOME/.codex"
        # Remove possible old symlink-to-store (from previous programs.codex.settings setup),
        # then install fresh writable copy of the Nix-generated toml.
        rm -f "$HOME/.codex/config.toml"
        install -m 644 "${codexConfigFile}" "$HOME/.codex/config.toml"

        # Codex 0.134.0+ loads named config layers from
        # $CODEX_HOME/<name>.config.toml.
        ${lib.concatStringsSep "\n        " (
          lib.mapAttrsToList (name: file: ''
            rm -f "$HOME/.codex/${name}.config.toml"
            install -m 644 "${file}" "$HOME/.codex/${name}.config.toml"
          '') codexConfigProfileFiles
        )}
      '';

      codexPlugins = lib.hm.dag.entryAfter [ "codexConfig" ] ''
        if command -v codex >/dev/null 2>&1; then
          CODEX_HOME="$HOME/.codex" codex plugin add claude-code-advisor@claude-plugin-codex >/dev/null 2>&1 || true
        fi
      '';
    };
  };
}
