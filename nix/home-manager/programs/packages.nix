{
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isDarwin;
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

  # 共通パッケージ (両OS)
  commonPackages = with pkgs; [
    # Development
    bun
    nodejs_22
    codex
    gemini-cli

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
    agentSkillPath
    difit
    _1password-cli
  ];

  # macOS専用パッケージ
  darwinPackages = with pkgs; [
    # TeX (重いのでmacOSのみ)
    texliveFull

    # Fonts (macOS側でレンダリングするので必要)
    nerd-fonts.jetbrains-mono

    # CLI-only macOS tools
    fastlane
    mas
    xcodegen

    # CLI alternatives for GUI apps
    # Linux 側は apt + systemd で入れるため Nix 管理しない (CLI/daemon
    # 二重インストールによるバージョン skew を避ける)
    ollama
    tailscale
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
      "$HOME/.antigravity/antigravity/bin"
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
