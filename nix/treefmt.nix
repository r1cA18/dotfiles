{ pkgs, ... }:
{
  projectRootFile = "flake.nix";

  programs = {
    nixfmt.enable = true;
    shfmt.enable = true;
    prettier = {
      enable = true;
      includes = [ "*.md" "*.json" "*.yaml" "*.yml" ];
    };
  };

  settings.global.excludes = [
    "flake.lock"
    "*.patch"
    "result"
    "nvim/**"
    "skills/**"
    "claude/**"
    "shared/**"
  ];
}
