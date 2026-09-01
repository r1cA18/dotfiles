{
  username,
  pkgs,
  ...
}:
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
    ./programs/ghostty.nix
    ./programs/linux-desktop.nix
    ./programs/karabiner.nix
    ./programs/syncthing.nix
    ./programs/agent-skills.nix
    ./programs/antigravity.nix
    ./programs/claude-code.nix
    ./programs/claude-code-proxy.nix
    ./programs/codex.nix
    ./programs/zed.nix
    ./programs/nix-index.nix
  ];

  home = {
    inherit username;
    homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
    stateVersion = "25.05";
    enableNixpkgsReleaseCheck = false;
  };

  programs.home-manager.enable = true;
}
