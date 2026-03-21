{
  config,
  username,
  pkgs,
  ...
}:
let
  dotfilesDir =
    if pkgs.stdenv.isDarwin then "/Users/${username}/dotfiles" else "/home/${username}/dotfiles";
in
{
  home.file = {
    ".codex/AGENTS.md" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/shared/GLOBAL_INSTRUCTIONS.md";
      force = true;
    };
    ".codex/config.toml" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/codex/config.toml";
      force = true;
    };
  };
}
