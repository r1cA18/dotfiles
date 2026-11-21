{ lib, pkgs, ... }:
let
  # Syncthing never syncs .stignore itself, so every device needs its own
  # copy. It is installed as a real file: Syncthing reading it through a
  # Home Manager symlink has not been verified. ~/Develop is not synced: a
  # session move carries the git workspace between workers.
  # The vault is committed by homelab only (programs/vault-commit.nix), so .git
  # is never synced. Ignored paths are not deleted on either side. Obsidian's
  # per-device UI state and the trash stay local.
  vaultIgnore = pkgs.writeText "vault-stignore" ''
    // Managed by dotfiles (nix/home-manager/programs/syncthing.nix); edits here are overwritten.
    .git
    .trash
    .obsidian/workspace.json
    .obsidian/workspace-mobile.json
    .obsidian/workspaces.json
  '';
in
{
  services.syncthing = {
    enable = true;
  };

  home.activation.syncthingVaultIgnore = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -d "$HOME/vault" ] && ! ${pkgs.diffutils}/bin/cmp -s "${vaultIgnore}" "$HOME/vault/.stignore"; then
      run install -D -m 644 "${vaultIgnore}" "$HOME/vault/.stignore"
    fi
  '';
}
