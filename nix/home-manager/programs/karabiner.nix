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
  # macOS only - Karabiner config
  xdg.configFile."karabiner/karabiner.json" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/karabiner/karabiner.json";
    force = true;
  };
}
