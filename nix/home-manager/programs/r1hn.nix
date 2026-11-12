{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  # r1hn comes from a private flake input (see flake.nix). Flake inputs are
  # fetched only when read, so a host with this switch off never needs access
  # to that repository. homelab and CI stay off until they have credentials.
  options.dotfiles.r1hn.enable = lib.mkOption {
    type = lib.types.bool;
    default = pkgs.stdenv.hostPlatform.isDarwin;
    description = "Install r1hn and point cl / cx at it.";
  };

  config = lib.mkIf config.dotfiles.r1hn.enable {
    home.packages = [ inputs.r1hn.packages.${pkgs.stdenv.hostPlatform.system}.r1hn ];
  };
}
