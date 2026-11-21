{
  pkgs,
  username,
  ...
}:
let
  flakePath =
    if pkgs.stdenv.hostPlatform.isDarwin then
      "/Users/${username}/dotfiles"
    else
      "/home/${username}/dotfiles";
in
{
  programs.nh = {
    enable = true;
    # Darwin user profiles are cleaned by developer-cleanup; system GC runs separately.
    clean = {
      enable = !pkgs.stdenv.hostPlatform.isDarwin;
      dates = "weekly";
      # Same retention as `dot clean`.
      extraArgs = "--keep 5 --keep-since 14d";
    };

    darwinFlake = if pkgs.stdenv.hostPlatform.isDarwin then flakePath else null;

    homeFlake = if pkgs.stdenv.hostPlatform.isLinux then flakePath else null;
  };
}
