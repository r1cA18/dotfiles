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
    ".." = {cmd = "cd .."; desc = "Go up one directory";};
    "..." = {cmd = "cd ../.."; desc = "Go up two directories";};
    nv = {cmd = "nvim"; desc = "Open Neovim";};
    dot = {cmd = "cd ~/dotfiles"; desc = "Go to dotfiles";};
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
    dev = {cmd = "cd ~/Develop/"; desc = "Go to Develop";};
    drive = {cmd = "cd ~/Google\\ Drive/My\\ Drive/Vault/"; desc = "Go to Google Drive";};
    kosen = {cmd = "cd ~/Google\\ Drive/My\\ Drive/Vault/20_Areas/Kosen/4y/fall_semester/"; desc = "Go to Kosen";};
    downloads = {cmd = "cd ~/Downloads/"; desc = "Go to Downloads";};
  };

  # Directory (Linux)
  dirLinuxAliases = {
    dev = {cmd = "cd ~/develop/"; desc = "Go to develop";};
    downloads = {cmd = "cd ~/Downloads/"; desc = "Go to Downloads";};
  };

  # Claude Code
  claudeAliases = {
    cc = {cmd = "claude"; desc = "Start Claude Code";};
    ccc = {cmd = "claude --continue"; desc = "Continue last session";};
    ccr = {cmd = "claude --resume"; desc = "Resume session (picker)";};
    ccd = {cmd = "claude --dangerously-skip-permissions"; desc = "Skip all permissions";};
    ccu = {cmd = "claude update"; desc = "Check for updates";};
    ccs = {cmd = "bunx ccusage"; desc = "Show Claude Code usage";};
  };

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

  # 全カテゴリのエイリアス定義をマージ
  allDefinitions =
    generalAliases
    // nixCommonAliases
    // (if isDarwin then nixDarwinAliases else nixLinuxAliases)
    // (if isDarwin then dirDarwinAliases else dirLinuxAliases)
    // claudeAliases;

  # ヘルプ用エイリアス（手動定義、循環参照回避）
  helpSection = "=== Help ===\n  h - Show this help\n  hv - Show commands";
  helpSectionVerbose = "=== Help ===\n  h = echo '...'\n  hv = echo '...'";

  # カテゴリ別ヘルプを生成（簡潔）
  helpText = lib.concatStringsSep "\n\n" (lib.filter (x: x != "") [
    (mkCategoryHelp "General" generalAliases)
    (mkCategoryHelp "Nix" (nixCommonAliases // (if isDarwin then nixDarwinAliases else nixLinuxAliases)))
    (mkCategoryHelp "Directory" (if isDarwin then dirDarwinAliases else dirLinuxAliases))
    (mkCategoryHelp "Claude Code" claudeAliases)
    helpSection
  ]);

  # カテゴリ別ヘルプを生成（詳細）
  helpTextVerbose = lib.concatStringsSep "\n\n" (lib.filter (x: x != "") [
    (mkCategoryHelpVerbose "General" generalAliases)
    (mkCategoryHelpVerbose "Nix" (nixCommonAliases // (if isDarwin then nixDarwinAliases else nixLinuxAliases)))
    (mkCategoryHelpVerbose "Directory" (if isDarwin then dirDarwinAliases else dirLinuxAliases))
    (mkCategoryHelpVerbose "Claude Code" claudeAliases)
    helpSectionVerbose
  ]);

  # 最終的なエイリアス
  finalAliases = mkAliases allDefinitions // {
    h = "echo '${helpText}'";
    hv = "echo '${helpTextVerbose}'";
  };
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
    ];

    # 自動生成されたエイリアス（h でヘルプ表示）
    shellAliases = finalAliases;

    initContent = ''
      # powerlevel10k configuration
      [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
    '';
  };
}
