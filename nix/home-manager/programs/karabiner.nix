{config, username, pkgs, lib, ...}: {
  # macOS only - Karabiner config
  xdg.configFile."karabiner/karabiner.json" = lib.mkIf pkgs.stdenv.isDarwin {
    source = config.lib.file.mkOutOfStoreSymlink "/Users/${username}/dotfiles/karabiner/karabiner.json";
  };
}
