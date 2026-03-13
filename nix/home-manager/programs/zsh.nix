{
  pkgs,
  lib,
  config,
  username,
  ...
}: let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;

  # ========================================
  # エイリアス定義 (cmd + desc)
  # ========================================

  # General (両OS共通)
  generalAliases = {
    ll = {cmd = "ls -la"; desc = "List all files";};
    nv = {cmd = "nvim"; desc = "Open Neovim";};
    dot = {cmd = "cd ~/dotfiles"; desc = "Go to dotfiles";};
    gacm = {cmd = "git add -A && git commit -m"; desc = "Add all + commit";};
  };

  # Nix (両OS共通)
  nixCommonAliases = {
    nx = {cmd = "cd ~/dotfiles/nix"; desc = "Go to nix config";};
    du = {cmd = "nix flake update --flake ~/dotfiles/nix"; desc = "Update flake";};
    ds = {cmd = "nix search nixpkgs"; desc = "Search nixpkgs";};
    dg = {cmd = "nix-collect-garbage -d"; desc = "Garbage collect";};
    nd = {cmd = "nix develop"; desc = "Enter nix develop shell";};
  };

  # Nix (macOS)
  nixDarwinAliases = {
    dr = {cmd = "sudo darwin-rebuild switch --flake ~/dotfiles/nix#RMB"; desc = "Rebuild nix config";};
    db = {cmd = "darwin-rebuild build --flake ~/dotfiles/nix#RMB"; desc = "Build nix config";};
    dp = {cmd = "sudo darwin-rebuild switch --rollback"; desc = "Rollback nix config";};
  };

  # Nix (Linux)
  nixLinuxAliases = {
    dr = {cmd = "home-manager switch --flake ~/dotfiles/nix#${username}@linux"; desc = "Rebuild home-manager";};
    dp = {cmd = "home-manager generations"; desc = "List generations";};
  };

  # Directory (macOS)
  dirDarwinAliases = {
    dev = {cmd = "cd ~/Develop/"; desc = "Go to Develop (use 'devg' for repo picker)";};
    drive = {cmd = "cd ~/Library/CloudStorage/GoogleDrive-ryo20061018@gmail.com/My\\ Drive/"; desc = "Go to Google Drive";};
    storage = {cmd = "cd ~/Library/CloudStorage/GoogleDrive-ryo20061018@gmail.com/My\\ Drive/Storage/"; desc = "Go to Storage";};
    vault = {cmd = "cd ~/vault/"; desc = "Go to Vault";};
    kosen = {cmd = "cd ~/vault/31_Areas/Kosen/4y/fall_semester/"; desc = "Go to Kosen";};
    downloads = {cmd = "cd ~/Downloads/"; desc = "Go to Downloads";};
  };

  # Directory (Linux)
  dirLinuxAliases = {
    dev = {cmd = "cd ~/develop/"; desc = "Go to develop";};
    downloads = {cmd = "cd ~/Downloads/"; desc = "Go to Downloads";};
  };

  # Claude Code (-w: work API key, -s: sub account)
  claudeAliases = {
    clc = {cmd = "cl --continue"; desc = "Continue last session";};
    clcd = {cmd = "cl --continue --dangerously-skip-permissions"; desc = "Continue + skip permissions";};
    clr = {cmd = "cl --resume"; desc = "Resume session (picker)";};
    cld = {cmd = "cl --dangerously-skip-permissions"; desc = "Skip all permissions";};
    clu = {cmd = "claude update"; desc = "Check for updates";};
    cls = {cmd = "bunx ccusage"; desc = "Show Claude Code usage";};
  };

  # Codex
  codexAliases = {
    cx = {cmd = "codex"; desc = "Start Codex";};
    cxc = {cmd = "codex resume --last"; desc = "Continue last session";};
    cxcd = {cmd = "codex resume --last --dangerously-bypass-approvals-and-sandbox"; desc = "Continue + skip approvals";};
    cxr = {cmd = "codex resume"; desc = "Resume session (picker)";};
    cxf = {cmd = "codex fork --last"; desc = "Fork last session";};
    cxd = {cmd = "codex --dangerously-bypass-approvals-and-sandbox"; desc = "Skip all approvals";};
    cxa = {cmd = "codex --full-auto"; desc = "Full auto (sandboxed)";};
    cxe = {cmd = "codex exec"; desc = "Non-interactive exec";};
    cxrev = {cmd = "codex review"; desc = "Code review";};
    cxap = {cmd = "codex apply"; desc = "Apply latest diff";};
  };

  # abbr 非対応のエイリアス（特殊文字を含む名前）
  aliasOnlyDefs = {
    ".." = {cmd = "cd .."; desc = "Go up one directory";};
    "..." = {cmd = "cd ../.."; desc = "Go up two directories";};
  };

  # abbr 対応のエイリアス（aliasOnlyDefs 以外すべて）
  abbrDefs =
    (lib.filterAttrs (n: _: n != ".." && n != "...") generalAliases)
    // nixCommonAliases
    // (if isDarwin then nixDarwinAliases else nixLinuxAliases)
    // (if isDarwin then dirDarwinAliases else dirLinuxAliases)
    // claudeAliases
    // codexAliases;

  # abbr 定義の initContent 用テキスト生成
  mkAbbrInit = defs: lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: v: "abbr -S -qq ${name}='${v.cmd}'") defs
  );

  # ========================================
  # ヘルプ生成関数
  # ========================================

  # エイリアス定義からcmdだけ抽出
  mkAliases = defs: lib.mapAttrs (name: v: v.cmd) defs;

  # カテゴリ別ヘルプテキスト生成（簡潔）
  mkCategoryHelp = category: defs: let
    lines = lib.mapAttrsToList (name: v: "  ${name} - ${v.desc}") defs;
  in
    if defs == {}
    then ""
    else "=== ${category} ===\n${lib.concatStringsSep "\n" lines}";

  # カテゴリ別ヘルプテキスト生成（詳細：コマンド内容のみ）
  mkCategoryHelpVerbose = category: defs: let
    lines = lib.mapAttrsToList (name: v: "  ${name} = ${v.cmd}") defs;
  in
    if defs == {}
    then ""
    else "=== ${category} ===\n${lib.concatStringsSep "\n" lines}";

  # ヘルプ用エイリアス（手動定義、循環参照回避）
  helpSection = "=== Help ===\n  h - Show this help\n  hv - Show commands";
  helpSectionVerbose = "=== Help ===\n  h = echo '...'\n  hv = echo '...'";

  # カテゴリ別ヘルプを生成（簡潔）
  helpText = lib.concatStringsSep "\n\n" (lib.filter (x: x != "") [
    (mkCategoryHelp "General" (generalAliases // aliasOnlyDefs))
    (mkCategoryHelp "Nix" (nixCommonAliases // (if isDarwin then nixDarwinAliases else nixLinuxAliases)))
    (mkCategoryHelp "Directory" (if isDarwin then dirDarwinAliases else dirLinuxAliases))
    (mkCategoryHelp "Claude Code (-w: work key, -s: sub account)" claudeAliases)
    (mkCategoryHelp "Codex" codexAliases)
    helpSection
  ]);

  # カテゴリ別ヘルプを生成（詳細）
  helpTextVerbose = lib.concatStringsSep "\n\n" (lib.filter (x: x != "") [
    (mkCategoryHelpVerbose "General" (generalAliases // aliasOnlyDefs))
    (mkCategoryHelpVerbose "Nix" (nixCommonAliases // (if isDarwin then nixDarwinAliases else nixLinuxAliases)))
    (mkCategoryHelpVerbose "Directory" (if isDarwin then dirDarwinAliases else dirLinuxAliases))
    (mkCategoryHelpVerbose "Claude Code (-w: work key, -s: sub account)" claudeAliases)
    (mkCategoryHelpVerbose "Codex" codexAliases)
    helpSectionVerbose
  ]);

in {
  home.file.".p10k.zsh".source = ./p10k.zsh;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git" # git エイリアス (gst, gco, gp, gl など)
        "z" # ディレクトリ間の高速移動
        "docker" # docker コマンド補完
        "sudo" # ESC 2回で sudo を先頭に追加
        "extract" # x コマンドで様々な圧縮形式を解凍
      ];
    };

    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
      {
        name = "zsh-abbr";
        src = pkgs.zsh-abbr;
        file = "share/zsh/zsh-abbr/zsh-abbr.plugin.zsh";
      }
    ];

    # alias: 特殊文字名 + ヘルプのみ、他は abbr で管理
    shellAliases = mkAliases aliasOnlyDefs // {
      h = "echo '${helpText}'";
      hv = "echo '${helpTextVerbose}'";
    };

    initContent = ''
      # powerlevel10k configuration
      [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

      # Abbreviations (auto-expand on Enter)
      ${mkAbbrInit abbrDefs}

      # Load secrets
      [[ -f ~/.config/secrets/appstore.env ]] && source ~/.config/secrets/appstore.env
      [[ -f ~/.config/secrets/claude.env ]] && source ~/.config/secrets/claude.env

      # ghq + fzf repo picker (git repos + local projects)
      devg() {
        local repo=$( (ghq list -p; find ~/Develop/local -maxdepth 1 -mindepth 1 -type d) 2>/dev/null | fzf --reverse --height 40%)
        [ -n "$repo" ] && cd "$repo"
      }

      # Claude Code launcher (-w: work API key, -s: sub account)
      cl() {
        local args=()
        local use_alt=0
        local use_sub=0
        for arg in "$@"; do
          if [[ "$arg" == "-w" ]]; then
            use_alt=1
          elif [[ "$arg" == "-s" ]]; then
            use_sub=1
          else
            args+=("$arg")
          fi
        done
        if (( use_alt )); then
          ANTHROPIC_API_KEY="''${CLAUDE_CSTYLE_API_KEY}" claude "''${args[@]}"
        elif (( use_sub )); then
          CLAUDE_CONFIG_DIR=~/.claude-sub claude "''${args[@]}"
        else
          claude "''${args[@]}"
        fi
      }
    '';
  };
}
