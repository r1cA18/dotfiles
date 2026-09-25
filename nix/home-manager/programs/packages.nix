{
  pkgs,
  lib,
  profile ? "workstation",
  ...
}:
let
  inherit (pkgs.stdenv) isDarwin;
  isServer = profile == "server";
  mkGithubReleaseApp = pkgs.callPackage ../../lib/github-app.nix { };
  recordlyPackage = pkgs.callPackage ../../pkgs/recordly { inherit mkGithubReleaseApp; };
  agentSkillPath = pkgs.writeShellApplication {
    name = "agent-skill-path";
    text = ''
      set -euo pipefail

      if [ "$#" -lt 1 ]; then
        echo "usage: agent-skill-path <skill-name> [relative/path]" >&2
        exit 64
      fi

      skill_name="$1"
      shift
      relative_path="''${1-}"

      declare -a roots=()

      if [ -n "''${AGENT_SKILLS_DIR:-}" ]; then
        roots+=("''${AGENT_SKILLS_DIR}")
      fi
      if [ -n "''${CLAUDE_CONFIG_DIR:-}" ]; then
        roots+=("''${CLAUDE_CONFIG_DIR}/skills")
      fi
      if [ -n "''${CODEX_HOME:-}" ]; then
        roots+=("''${CODEX_HOME}/skills")
      fi

      roots+=(
        "$HOME/.claude/skills"
        "$HOME/.codex/skills"
      )

      for root in "''${roots[@]}"; do
        candidate="$root/$skill_name"
        if [ -e "$candidate" ]; then
          if [ -n "$relative_path" ]; then
            printf '%s\n' "$candidate/$relative_path"
          else
            printf '%s\n' "$candidate"
          fi
          exit 0
        fi
      done

      echo "agent-skill-path: skill not found: $skill_name" >&2
      exit 1
    '';
  };

  # Jev (TypeSafe System One) CLI wrapper.
  # The API key is never embedded; it is injected by 1Password `op run`.
  jev = pkgs.writeShellApplication {
    name = "jev";
    runtimeInputs = [
      pkgs._1password-cli
      pkgs.python3
      agentSkillPath
    ];
    text = ''
      set -euo pipefail
      env_file="''${OP_ENV_FILE:-$HOME/.config/op/env/typesafe.env}"
      if [[ ! -f "$env_file" ]]; then
        echo "error: 1Password env file not found: $env_file" >&2
        echo "Create it with: TYPESAFE_API_KEY=op://<vault>/<item>/<field>" >&2
        exit 1
      fi
      if ! command -v op >/dev/null 2>&1; then
        echo "error: 1Password CLI (op) is not installed" >&2
        exit 1
      fi
      script_path="$(agent-skill-path op-api-keys scripts/jev.py)"
      exec op run --env-file "$env_file" -- python3 "$script_path" "$@"
    '';
  };

  # GitHub release アプリ (Recordly 等) の version/hash を最新へ更新する。
  # 対象は nix/pkgs/github-apps.json レジストリで管理。ファイル書換のみで
  # commit/rebuild はしない (update-all が呼ぶ -> git diff 確認 -> dr)。
  updateGithubApps = pkgs.writeShellApplication {
    name = "update-github-apps";
    runtimeInputs = with pkgs; [
      gh
      jq
      curl
      gnused
      coreutils
      nix
    ];
    text = ''
      repo_root="''${DOTFILES_DIR:-$HOME/dotfiles}"
      registry="$repo_root/nix/pkgs/github-apps.json"
      [ -f "$registry" ] || {
        echo "registry not found: $registry" >&2
        exit 1
      }

      changed=0
      for app in $(jq -r 'keys[]' "$registry"); do
        owner=$(jq -r --arg a "$app" '.[$a].owner' "$registry")
        repo=$(jq -r --arg a "$app" '.[$a].repo' "$registry")
        tmpl=$(jq -r --arg a "$app" '.[$a].assetTemplate' "$registry")
        strip=$(jq -r --arg a "$app" '.[$a].stripVPrefix' "$registry")
        nixfile="$repo_root/$(jq -r --arg a "$app" '.[$a].nixFile' "$registry")"

        tag=$(gh release view --repo "$owner/$repo" --json tagName -q .tagName 2>/dev/null) \
          || tag=$(curl -fsSL "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r .tag_name)

        if [ "$strip" = "true" ]; then version="''${tag#v}"; else version="$tag"; fi
        asset="''${tmpl//__VERSION__/$version}"
        url="https://github.com/$owner/$repo/releases/download/$tag/$asset"

        cur=$(sed -nE 's/^[[:space:]]*version = "([^"]+)";/\1/p' "$nixfile" | head -1)
        if [ "$cur" = "$version" ]; then
          echo "$app: up to date ($version)"
          continue
        fi

        echo "$app: $cur -> $version"
        hash=$(nix store prefetch-file --json "$url" | jq -r .hash)

        sed -i.bak -E \
          -e "s|^([[:space:]]*version = \")[^\"]+(\";)|\1$version\2|" \
          -e "s|^([[:space:]]*hash = \")[^\"]+(\";)|\1$hash\2|" \
          "$nixfile"
        rm -f "$nixfile.bak"
        changed=1
      done

      if [ "$changed" = "1" ]; then
        echo "github-apps updated; review 'git diff' then run dr."
      else
        echo "all github apps up to date."
      fi
    '';
  };

  # Claude Code (native) を managed-channel に従い更新する。update-all が呼ぶ。
  # claude-code.nix の activation が ~/.claude/managed-channel を書き出す。
  updateClaudeCode = pkgs.writeShellApplication {
    name = "update-claude-code";
    runtimeInputs = with pkgs; [
      curl
      bash
    ];
    text = ''
      channel=$(cat "$HOME/.claude/managed-channel" 2>/dev/null || echo latest)
      if [ "$channel" = "latest" ]; then
        echo "[claude-code] updating to latest..."
        curl -fsSL https://claude.ai/install.sh | bash
      else
        echo "[claude-code] pinned to $channel; skipping (edit claudeChannel + dr to change)"
      fi
    '';
  };

  # 共通パッケージ (両OS)
  commonPackages =
    with pkgs;
    [
      # Development
      bun
      nodejs_22
      pnpm
      gemini-cli

      # Typesetting
      typst

      # CLI tools
      ast-grep
      bat
      bottom
      eza
      fzf
      ghq
      jq
      ripgrep
      fd
      cloudflared
      tmux
      ffmpeg
      agent-browser
      agentSkillPath
      _1password-cli
      updateGithubApps
      updateClaudeCode

      # Research / media ingestion
      yt-dlp
      whisper-ctranslate2
      python313Packages.feedparser

      # API-key-wrapped tools (1Password-injected)
      jev
    ]
    ++ pkgs.lib.optionals (pkgs ? indexion) [
      pkgs.indexion
      pkgs.workspace
    ];

  darwinCliPackages = with pkgs; [
    fastlane
    mas
    xcodegen
    ollama
    tailscale
  ];

  darwinGuiPackages = with pkgs; [
    nerd-fonts.jetbrains-mono
    plemoljp-nf
    recordlyPackage
  ];

  # Linux 専用パッケージ
  linuxPackages = with pkgs; [
    # ターミナル (Ghostty 等) で Nerd Font グリフを使うため
    nerd-fonts.jetbrains-mono
  ];

in
{
  home = {
    packages =
      commonPackages
      ++ (if isDarwin then darwinCliPackages else linuxPackages)
      ++ lib.optionals (isDarwin && !isServer) darwinGuiPackages;
    sessionPath = [
      "$HOME/.local/bin"
    ];
    sessionVariables = {
      EDITOR = "nvim";
    };
  };

  # Create a 1Password env-file template on first activation so API keys are
  # never committed, but the expected path/shape is documented.
  home.activation = {
    setupOpApiKeyEnv = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            target="$HOME/.config/op/env"
            mkdir -p "$target"
            if [ ! -f "$target/typesafe.env" ]; then
              cat > "$target/typesafe.env" <<'EOF'
      # 1Password reference for TypeSafe / Jev API key.
      # Replace the vault/item/field names with your own 1Password setup.
      TYPESAFE_API_KEY=op://AI/TypeSafe/api-key
      EOF
              echo "[op-api-keys] created $target/typesafe.env template" >&2
            fi
    '';
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
