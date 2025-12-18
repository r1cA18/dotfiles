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
      # directory aliases
      "dev" = "cd ~/Develop/";
      "drive" = "cd ~/Google\\ Drive/My\\ Drive/MainFolder/";
      "kosen" = "cd ~/Google\\ Drive/My\\ Drive/MainFolder/20_Areas/Kosen/4y/fall_semester/";
      "downloads" = "cd ~/Downloads/";
      # nvim aliases
      "nv" = "nvim";
      # Nix aliases
      rebuild = "sudo darwin-rebuild switch --flake ~/dotfiles/nix";
    };

    initContent = ''
      # Add any additional zsh configuration here
    '';
  };
}
