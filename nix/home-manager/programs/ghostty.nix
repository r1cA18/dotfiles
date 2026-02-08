{pkgs, lib, ...}: {
  # Ghostty config (macOS only)
  home.file."Library/Application Support/com.mitchellh.ghostty/config" = lib.mkIf pkgs.stdenv.isDarwin {
    source = ../../../ghostty/config;
  };

  # Ghostty terminfo (Linux only)
  home.activation.ghosttyTerminfo = lib.mkIf pkgs.stdenv.isLinux (
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      if ! infocmp xterm-ghostty &>/dev/null; then
        TERMINFO_SRC=$(mktemp)
        ${pkgs.curl}/bin/curl -fsSL https://raw.githubusercontent.com/ghostty-org/ghostty/main/src/terminfo/ghostty.terminfo -o "$TERMINFO_SRC"
        ${pkgs.ncurses}/bin/tic -x "$TERMINFO_SRC"
        rm "$TERMINFO_SRC"
      fi
    ''
  );
}
