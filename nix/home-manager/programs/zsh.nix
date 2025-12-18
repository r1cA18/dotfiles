{ ... }: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

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
