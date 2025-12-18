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
      neovim
      bun

      # CLI tools
      nodePackages.pnpm
      nodePackages."@antfu/ni"
      ripgrep  # LazyVim の telescope で必要
      fd       # LazyVim の telescope で必要
      # fzf
      # eza
      # bat
      # jq
      # gh

      # Languages
      # python3
      # go
      # rustup

      # TeX
      texliveFull
    ];

    # PATH additions (from original .zshrc)
    sessionPath = [
      "$HOME/.npm-global/bin"
      "$HOME/.antigravity/antigravity/bin"
      "$HOME/.local/bin"
    ];

    # Environment variables
    sessionVariables = {
      EDITOR = "nvim";
    };

    # Dotfiles (symlinked to home directory)
    # file = {
    #   ".config/some-app".source = ./config/some-app;
    # };
  };

  # XDG config files (symlinked to ~/.config/)
  xdg.configFile = {
    "nvim".source = ../../nvim;
    "~/Library/Application\ Support/com.mitchellh.ghostty/config".source = ../../ghostty/config;
    # Karabiner-Elements (writable symlink for GUI changes)
    "karabiner/karabiner.json".source = config.lib.file.mkOutOfStoreSymlink "/Users/${username}/dotfiles/karabiner/karabiner.json";
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.05";

  # Git configuration
  programs.git = {
    enable = true;
    ignores = [
      ".DS_Store"
      "*.swp"
      ".direnv"
      ".envrc"
    ];
    settings = {
      user.name = "r1cA18";
      user.email = "r1cA18@proton.me";
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
      # nvim aliases
      "nv" = "nvim";
      # Nix aliases
      rebuild = "sudo darwin-rebuild switch --flake ~/dotfiles/nix";
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




