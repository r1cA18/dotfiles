{pkgs, lib, ...}: {
  # Ghostty config (macOS only)
  # Linux/Server はCLI専用なのでGUI設定は不要
  home.file."Library/Application Support/com.mitchellh.ghostty/config" = lib.mkIf pkgs.stdenv.isDarwin {
    source = ../../../ghostty/config;
  };
}
