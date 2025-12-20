{config, username, ...}: {
  xdg.configFile."karabiner/karabiner.json".source =
    config.lib.file.mkOutOfStoreSymlink "/Users/${username}/dotfiles/karabiner/karabiner.json";
}
