{
  username,
  pkgs,
  lib,
  profile ? "workstation",
  ...
}:
let
  isServer = profile == "server";
in
{
  imports = [
    ./programs/nh.nix
    ./programs/git.nix
    ./programs/ssh.nix
    ./programs/zsh.nix
    ./programs/atuin.nix
    ./programs/zoxide.nix
    ./programs/neovim.nix
    ./programs/packages.nix
    ./programs/syncthing.nix
    ./programs/agent-skills.nix
    ./programs/antigravity.nix
    ./programs/ccspace.nix
    ./programs/devin.nix
    ./programs/claude-code.nix
    ./programs/claude-code-proxy.nix
    ./programs/codex.nix
    ./programs/nix-index.nix
  ]
  ++ lib.optionals (!isServer) [
    ./programs/ghostty.nix
    ./programs/aerospace.nix
    ./programs/linux-desktop.nix
    ./programs/karabiner.nix
    ./programs/orca.nix
    ./programs/zed.nix
  ];

  home = {
    inherit username;
    homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
    stateVersion = "25.05";
    enableNixpkgsReleaseCheck = false;
  };

  programs.home-manager.enable = true;
}
