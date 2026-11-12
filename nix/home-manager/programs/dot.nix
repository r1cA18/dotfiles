# dot: single entry point for dotfiles operations (apply, build, update, ...).
# Each update stage is a dot-update-<stage> executable owned by its module.
{
  hostname ? null,
  lib,
  pkgs,
  username,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
  dot = pkgs.writeShellApplication {
    name = "dot";
    runtimeInputs = [
      pkgs.jq
      pkgs.nh
      pkgs.nix
    ];
    text = ''
      dot_kind=${if isDarwin then "darwin" else "home"}
      dot_target=${
        lib.escapeShellArg (
          if isDarwin then
            hostname
          else if hostname == null then
            "${username}@linux"
          else
            "${username}@${hostname}"
        )
      }
      ${builtins.readFile ./dot.sh}
    '';
  };
in
{
  home.packages = [ dot ];
}
