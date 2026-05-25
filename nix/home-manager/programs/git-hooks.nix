{ pkgs, lib, config, ... }:
let
  homeDir = config.home.homeDirectory;
  dotfilesDir = "${homeDir}/dotfiles";

  postCommitHook = pkgs.writeShellScript "post-commit" ''
    if git diff --name-only HEAD~1 HEAD 2>/dev/null | grep -qE '\.nix$|flake\.lock$'; then
      echo "nix files changed, rebuilding in background..."
      (cd "${dotfilesDir}" && nh darwin switch . -H "$(hostname -s)" &>/dev/null &)
    fi
  '';
in
{
  home.activation.installGitHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    hooks_dir="${dotfilesDir}/.git/hooks"
    if [ -d "${dotfilesDir}/.git" ]; then
      mkdir -p "$hooks_dir"
      ln -sf "${postCommitHook}" "$hooks_dir/post-commit"
    fi
  '';
}
