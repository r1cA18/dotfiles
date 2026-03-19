{
  pkgs,
  username,
  ...
}:
let
  flakePath =
    if pkgs.stdenv.isDarwin then "/Users/${username}/dotfiles" else "/home/${username}/dotfiles";
in
{
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.dates = "weekly";

    darwinFlake = if pkgs.stdenv.isDarwin then flakePath else null;

    homeFlake = if pkgs.stdenv.isLinux then flakePath else null;
  };
}
