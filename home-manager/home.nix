# home-manager configuration
# This is your user-level configuration
{
  inputs,
  lib,
  config,
  pkgs,
  username,
  ...
}: {
  # Import other home-manager modules here
  imports = [
    # ./programs/git.nix
    # ./programs/zsh.nix
    # ./programs/neovim.nix
  ];

  # Home directory settings
  home = {
    username = username;
    homeDirectory = "/Users/${username}";

    # User packages
    packages = with pkgs; [
      # Development
      nodejs_latest

      # CLI tools
      # nodejs
      nodePackages.pnpm
      # ripgrep
      # fd
      # fzf
      # eza
      # bat
      # jq
      # gh

      # Languages
      # python3
      # go
      # rustup
    ];

    # PATH additions (from original .zshrc)
    sessionPath = [
      "$HOME/.npm-global/bin"
      "$HOME/.antigravity/antigravity/bin"
      "$HOME/.local/bin"
    ];

    # Environment variables
    sessionVariables = {
      EDITOR = "vim";
    };

    # Dotfiles (symlinked to home directory)
    # file = {
    #   ".config/some-app".source = ./config/some-app;
    # };

    # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    stateVersion = "25.05";
  };

  # Git configuration
  programs.git = {
    enable = true;
    userName = "r1cA18";
    userEmail = "r1cA18@proton.me";
    ignores = [
      ".DS_Store"
      "*.swp"
      ".direnv"
      ".envrc"
    ];
    extraConfig = {
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = true;
    };
  };

  # Zsh configuration
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # Shell aliases
    shellAliases = {
      ll = "ls -la";
      ".." = "cd ..";
      "..." = "cd ../..";
      # directory aliases
      "dev" = "cd ~/Develop/";
      "drive" = "cd ~/Google\\ Drive/My\\ Drive/MainFolder/";
      "kosen" = "cd ~/Google\\ Drive/My\\ Drive/MainFolder/20_Areas/Kosen/4y/fall_semester/";
      "downloads" = "cd ~/Downloads/";
      # Nix aliases
      rebuild = "sudo darwin-rebuild switch --flake ~/dotfiles";
    };

    # Additional zsh configuration
    initExtra = ''
      # Add any additional zsh configuration here
    '';
  };

  # Let home-manager manage itself
  programs.home-manager.enable = true;

  # Claude Code
  programs.claude-code.enable = true;
}




