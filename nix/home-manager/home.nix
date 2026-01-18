{
  username,
  pkgs,
  ...
}: {
  imports = [
    ./programs/git.nix
    ./programs/zsh.nix
    ./programs/neovim.nix
    ./programs/packages.nix
    ./programs/ghostty.nix
    ./programs/karabiner.nix
  ];

  home = {
    username = username;
    homeDirectory =
      if pkgs.stdenv.isDarwin
      then "/Users/${username}"
      else "/home/${username}";
    stateVersion = "25.05";
  };

  programs.home-manager.enable = true;
}
