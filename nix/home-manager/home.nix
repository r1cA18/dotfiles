{
  inputs,
  lib,
  config,
  pkgs,
  username,
  ...
}: {
  imports = [
    ./programs/git.nix
    ./programs/zsh.nix
  ];

  home = {
    username = username;
    homeDirectory = "/Users/${username}";

    packages = with pkgs; [
      # Development
      nodejs_latest
      neovim
      bun

      # CLI tools
      nodePackages.pnpm
      nodePackages."@antfu/ni"
      ripgrep
      fd

      # TeX
      texliveFull
    ];

    sessionPath = [
      "$HOME/.npm-global/bin"
      "$HOME/.antigravity/antigravity/bin"
      "$HOME/.local/bin"
    ];

    sessionVariables = {
      EDITOR = "nvim";
    };

    stateVersion = "25.05";
  };

  xdg.configFile = {
    "nvim".source = ../../nvim;
    "~/Library/Application\ Support/com.mitchellh.ghostty/config".source = ../../ghostty/config;
    "karabiner/karabiner.json".source = config.lib.file.mkOutOfStoreSymlink "/Users/${username}/dotfiles/karabiner/karabiner.json";
  };

  programs.home-manager.enable = true;
  programs.claude-code.enable = true;
}
