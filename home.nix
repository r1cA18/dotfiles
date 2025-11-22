{ config, pkgs, ... }:

{
  home.username = "r1ca18";
  home.homeDirectory = "/Users/r1ca18";

  home.packages = with pkgs; [
    nodejs_latest
  ];

  programs.git = {
    enable = true;
    settings.user.name = "r1cA18";
    settings.user.email = "r1cA18@proton.me";
    ignores = [ ".DS_Store" ];
  };

  home.stateVersion = "25.05";
}
