{username, ...}: {
  imports = [
    ./programs/git.nix
    ./programs/zsh.nix
    ./programs/neovim.nix
    ./programs/ghostty.nix
    ./programs/karabiner.nix
    ./programs/packages.nix
  ];

  home = {
    username = username;
    homeDirectory = "/Users/${username}";
    stateVersion = "25.05";
  };

  programs.home-manager.enable = true;
  programs.claude-code.enable = true;
}
