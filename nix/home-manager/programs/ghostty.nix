{pkgs, lib, ...}: {
  # macOS only - Ghostty config path
  home.file."Library/Application Support/com.mitchellh.ghostty/config" = lib.mkIf pkgs.stdenv.isDarwin {
    source = ../../../ghostty/config;
  };
}
