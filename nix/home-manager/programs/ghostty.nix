{pkgs, lib, ...}: {
  # Ghostty config (macOS only)
  home.file."Library/Application Support/com.mitchellh.ghostty/config" = lib.mkIf pkgs.stdenv.isDarwin {
    source = ../../../ghostty/config;
  };

  # Ghostty terminfo (Linux) - ncurses 6.5+ includes xterm-ghostty
  home.packages = lib.mkIf pkgs.stdenv.isLinux [
    pkgs.ncurses
  ];
}
