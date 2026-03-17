{
  username,
  pkgs,
  ...
}:
{
  imports = [
    ./programs/nh.nix
    ./programs/git.nix
    ./programs/zsh.nix
    ./programs/atuin.nix
    ./programs/zoxide.nix
    ./programs/neovim.nix
    ./programs/packages.nix
    ./programs/ghostty.nix
    ./programs/karabiner.nix
    ./programs/syncthing.nix
    ./programs/agent-skills.nix
    ./programs/claude-code.nix
    ./programs/codex.nix
    ./programs/nix-index.nix
  ];

  home = {
    inherit username;
    homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
    stateVersion = "25.05";
  };

  programs.home-manager.enable = true;
}
