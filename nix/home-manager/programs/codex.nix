{
  config,
  lib,
  username,
  pkgs,
  ...
}:
let
  homeDir = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/${username}" else "/home/${username}";
  dotfilesDir = "${homeDir}/dotfiles";

  tomlFormat = pkgs.formats.toml { };
  codexAgentInstructions = import ../../lib/agent-instructions.nix {
    inherit lib pkgs;
    extraFiles = [ ../../../codex/rules/orchestration.md ];
  };
  installCodex = ''
    ${pkgs.coreutils}/bin/install -d "$HOME/.codex" "$HOME/.local/bin"
    ${pkgs.curl}/bin/curl -fsSL https://chatgpt.com/codex/install.sh \
      | PATH="$HOME/.local/bin:${
        lib.makeBinPath (
          with pkgs;
          [
            curl
            gnutar
            gzip
            gawk
            coreutils
            bash
          ]
        )
      }:$PATH:/usr/bin:/bin" \
        CODEX_HOME="$HOME/.codex" \
        CODEX_INSTALL_DIR="$HOME/.local/bin" \
        CODEX_NON_INTERACTIVE=1 \
        ${pkgs.bash}/bin/bash
  '';

  # home, dotfiles, vault は homeDir 由来で両OS共通。
  # Develop 配下の個別プロジェクトは macOS にしか無いので Darwin 限定。
  trustedProjects = [
    homeDir
    dotfilesDir
    "${homeDir}/vault"
  ]
  ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    "/Users/r1ca18/Develop/github.com/r1cA18/syoki"
    "/Users/r1ca18/Develop/github.com/r1cA18/NomadPad-app"
    "/Users/r1ca18/Develop/github.com/r1cA18/mado"
    "/Users/r1ca18/Develop/github.com/r1cA18/zmk-config-ZaruBall-r1cA18"
    "/Users/r1ca18/Develop/github.com/r1cA18/RaycastExtensions"
    "/Users/r1ca18/Develop/github.com/C-Style-team/MobileAndon"
    "/Users/r1ca18/Develop/github.com/C-Style-team/MobileAndon/MobileAndon-Revised"
    "/Users/r1ca18/Develop/github.com/C-Style-team/meeting-logs/aipf-pkg-gijiroku-frontend"
  ];

  codexSettings = {
    # Top-level model is the default. Named config layers are generated as
    # $CODEX_HOME/<name>.config.toml below.
    # Do not pin the default model here; let Codex use its own default or the
    # runtime /model selection.
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
      multi_agent = false;
    };

    tui.status_line = [
      "model-with-reasoning"
      "context-remaining"
      "current-dir"
      "git-branch"
      "context-used"
      "five-hour-limit"
    ];

  };

  # Trusted projects are entries: projects the owner trusts inside Codex stay.
  codexProjects = lib.listToAttrs (
    map (p: lib.nameValuePair p { trust_level = "trusted"; }) trustedProjects
  );

  codexConfigProfiles = {
    heavy = {
      model_reasoning_effort = "high";
    };
    spark = {
      model_reasoning_effort = "medium";
    };
  };

  merge = import ../../lib/merge-managed.nix { inherit pkgs lib; };
  codexConfigProfileFiles = lib.mapAttrs (
    name: settings: tomlFormat.generate "codex-${name}-config.toml" settings
  ) codexConfigProfiles;

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

  updateCodex = pkgs.writeShellApplication {
    name = "dot-update-codex";
    text = ''
      echo "[codex] updating to latest..."
      ${installCodex}
      "$HOME/.local/bin/codex" --version
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
  # Instead each dr merges the managed keys into the live writable file:
  # top-level settings are reset to these values, trusted projects are
  # added, and everything Codex or the owner added (plugins, MCP servers,
  # trust decisions) stays. Plugins and MCP servers come from the capability
  # catalog (r1hn on macOS, capabilities.nix elsewhere).

  home = {
    packages = [
      updateCodex
    ];

    file = {
      # Shared instructions plus the Codex-specific single-agent policy.
      ".codex/AGENTS.md".source = codexAgentInstructions;

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

      codexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] (
        ''
          install -d "$HOME/.codex"
          # An old generation linked config.toml into the store.
          if [ -L "$HOME/.codex/config.toml" ]; then
            target=$(readlink "$HOME/.codex/config.toml")
            case "$target" in /nix/store/*) rm -f "$HOME/.codex/config.toml" ;; esac
          fi
        ''
        + merge {
          format = "toml";
          target = "$HOME/.codex/config.toml";
          name = "codex-config";
          fragment = {
            set = codexSettings;
            entries.projects = codexProjects;
          };
        }
        + ''
          # Codex 0.134.0+ loads named config layers from
          # $CODEX_HOME/<name>.config.toml.
          ${lib.concatStringsSep "\n        " (
            lib.mapAttrsToList (name: file: ''
              rm -f "$HOME/.codex/${name}.config.toml"
              install -m 644 "${file}" "$HOME/.codex/${name}.config.toml"
            '') codexConfigProfileFiles
          )}
        ''
      );

      # Codex CLI native 版の初回導入。更新は dot update の
      # codex 段階が担う。
      setupCodex = lib.hm.dag.entryAfter [ "codexConfig" ] ''
        bin="$HOME/.local/bin/codex"
        log="$HOME/.local/state/codex/install.log"
        if [ ! -x "$bin" ]; then
          echo "[codex] installing Codex CLI..."
          mkdir -p "$(dirname "$log")"
          if ! (
            set -o pipefail
            ${installCodex}
          ) >>"$log" 2>&1; then
            echo "[codex] install failed, see $log" >&2
          fi
        fi
      '';

      codexPlugins = lib.hm.dag.entryAfter [ "setupCodex" ] ''
        bin="$HOME/.local/bin/codex"
        if [ -x "$bin" ]; then
          CODEX_HOME="$HOME/.codex" "$bin" plugin add claude-code-advisor@claude-plugin-codex >/dev/null 2>&1 || true
        fi
      '';
    };
  };
}
