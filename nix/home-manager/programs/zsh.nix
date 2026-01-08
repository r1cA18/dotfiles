{ pkgs, ... }: {
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

    shellAliases = {
      ll = "ls -la";
      ".." = "cd ..";
      "..." = "cd ../..";

      # Directory
      dev = "cd ~/Develop/";
      drive = "cd ~/Google\\ Drive/My\\ Drive/MainFolder/";
      kosen = "cd ~/Google\\ Drive/My\\ Drive/MainFolder/20_Areas/Kosen/4y/fall_semester/";
      downloads = "cd ~/Downloads/";

      # Neovim
      nv = "nvim";

      # Nix / Darwin
      nx = "cd ~/dotfiles/nix";
      dr = "sudo darwin-rebuild switch --flake ~/dotfiles/nix#RMB";
      db = "darwin-rebuild build --flake ~/dotfiles/nix#RMB";
      dp = "sudo darwin-rebuild switch --rollback";
      du = "nix flake update --flake ~/dotfiles/nix";
      ds = "nix search nixpkgs";
      dg = "nix-collect-garbage -d";
      nd = "nix develop";
    };

    initContent = ''
      # Add any additional zsh configuration here
    '';
  };
}
