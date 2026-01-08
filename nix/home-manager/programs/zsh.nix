{
  pkgs,
  lib,
  config,
  username,
  ...
}: let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;

  # Common aliases (両OS共通)
  commonAliases = {
    ll = "ls -la";
    ".." = "cd ..";
    "..." = "cd ../..";

    # Neovim
    nv = "nvim";

    # Nix (共通)
    nx = "cd ~/dotfiles/nix";
    du = "nix flake update --flake ~/dotfiles/nix";
    ds = "nix search nixpkgs";
    dg = "nix-collect-garbage -d";
    nd = "nix develop";
  };

  # macOS-specific aliases
  darwinAliases = {
    # Directory (macOS paths)
    dev = "cd ~/Develop/";
    drive = "cd ~/Google\\ Drive/My\\ Drive/MainFolder/";
    kosen = "cd ~/Google\\ Drive/My\\ Drive/MainFolder/20_Areas/Kosen/4y/fall_semester/";
    downloads = "cd ~/Downloads/";

    # Nix / Darwin
    dr = "sudo darwin-rebuild switch --flake ~/dotfiles/nix#RMB";
    db = "darwin-rebuild build --flake ~/dotfiles/nix#RMB";
    dp = "sudo darwin-rebuild switch --rollback";
  };

  # Linux-specific aliases
  linuxAliases = {
    # Directory (Linux paths)
    dev = "cd ~/develop/";
    downloads = "cd ~/Downloads/";

    # home-manager (Linux)
    dr = "home-manager switch --flake ~/dotfiles/nix#${username}@linux";
    dp = "home-manager generations";
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

    # OS別エイリアスをマージ
    shellAliases =
      commonAliases
      // (
        if isDarwin
        then darwinAliases
        else linuxAliases
      );

    initContent = ''
      # powerlevel10k configuration
      [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
    '';
  };
}
