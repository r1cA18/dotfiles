{pkgs, lib, ...}: {
  # Ghostty config (macOS only)
  home.file."Library/Application Support/com.mitchellh.ghostty/config" = lib.mkIf pkgs.stdenv.isDarwin {
    source = ../../../ghostty/config;
  };

  # Ghostty terminfo (Linux)
  home.packages = lib.mkIf pkgs.stdenv.isLinux [
    pkgs.ghostty.terminfo
  ];
}
