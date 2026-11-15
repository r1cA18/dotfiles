{ lib, pkgs, ... }:
let
  # Syncthing never syncs .stignore itself, so every device needs its own
  # copy. It is installed as a real file: Syncthing reading it through a
  # Home Manager symlink has not been verified.
  developIgnore = pkgs.writeText "develop-stignore" ''
    // Managed by dotfiles (nix/home-manager/programs/syncthing.nix); edits here are overwritten.
    // Live service data that must not be synced bidirectionally (homelab is authoritative).
    /github.com/r1cA18/home-assistant
    /github.com/r1cA18/olympus/data
    // Regenerable build output: never synced, and deleting it locally must not reach peers.
    // (?d) lets Syncthing remove these when they block deleting a parent directory.
    (?d)target
    (?d)node_modules
    (?d).venv
    (?d)DerivedData
    (?d).build
    (?d).next
  '';

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

  home.activation.syncthingDevelopIgnore = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! ${pkgs.diffutils}/bin/cmp -s "${developIgnore}" "$HOME/Develop/.stignore"; then
      run install -D -m 644 "${developIgnore}" "$HOME/Develop/.stignore"
    fi
  '';

  home.activation.syncthingVaultIgnore = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -d "$HOME/vault" ] && ! ${pkgs.diffutils}/bin/cmp -s "${vaultIgnore}" "$HOME/vault/.stignore"; then
      run install -D -m 644 "${vaultIgnore}" "$HOME/vault/.stignore"
    fi
  '';
}
