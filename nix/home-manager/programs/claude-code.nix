{
  config,
  username,
  pkgs,
  lib,
  ...
}:
let
  dotfilesDir = "/Users/${username}/dotfiles";
in
{
  home.file = lib.mkIf pkgs.stdenv.isDarwin {
    ".claude/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/claude/settings.json";
    ".claude/CLAUDE.md".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/shared/GLOBAL_INSTRUCTIONS.md";
    ".claude/commands".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/claude/commands";
    ".claude/agents".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/claude/agents";
    ".claude/hooks".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/claude/hooks";
    ".claude/rules".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/claude/rules";
  };
}
