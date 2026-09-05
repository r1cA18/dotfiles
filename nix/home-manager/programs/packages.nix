{
  inputs,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isDarwin;
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
  commonPackages = with pkgs; [
    # Development
    bun
    nodejs_22
    pnpm
    codex
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
    mdv
    cloudflared
    tmux
    ffmpeg
    agent-browser
    inputs.herdr.packages.${pkgs.system}.default
    agentSkillPath
    difit
    _1password-cli
    updateGithubApps
    updateClaudeCode
  ];

  # macOS専用パッケージ
  darwinPackages = with pkgs; [
    # TeX (重いのでmacOSのみ)
    texliveFull

    # Fonts (macOS側でレンダリングするので必要)
    nerd-fonts.jetbrains-mono
    plemoljp-nf

    # CLI-only macOS tools
    fastlane
    mas
    xcodegen

    # CLI alternatives for GUI apps
    # Linux 側は apt + systemd で入れるため Nix 管理しない (CLI/daemon
    # 二重インストールによるバージョン skew を避ける)
    ollama
    tailscale

    # GUI apps (Homebrew cask / nixpkgs に無いため .dmg を自前パッケージ化)
    # home-manager が ~/Applications/Home Manager Apps/ に配置する
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
    packages = commonPackages ++ (if isDarwin then darwinPackages else linuxPackages);
    sessionPath = [
      "$HOME/.local/bin"
    ];
    sessionVariables = {
      EDITOR = "nvim";
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
