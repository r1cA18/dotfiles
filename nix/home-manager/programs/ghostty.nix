{ pkgs, lib, ... }:
let
  inherit (pkgs.stdenv) isDarwin;
in
{
  programs.ghostty = {
    enable = true;
    package = null;
    systemd.enable = false;
    enableZshIntegration = true;
    settings = {
      theme = "TokyoNight";
      maximize = true;
      font-family = if isDarwin then "PlemolJP35 Console NF" else "JetBrainsMono Nerd Font";
      font-size = 20;
      font-thicken = true;
      adjust-cell-height = 2;
      background-opacity = 0.8;
      background-blur = false;
      window-inherit-working-directory = true;
      shell-integration = "detect";
      keybind = [
        "ctrl+h=goto_split:left"
        "ctrl+j=goto_split:down"
        "ctrl+k=goto_split:up"
        "ctrl+l=goto_split:right"
      ]
      ++ lib.optionals isDarwin [
        "cmd+alt+left=previous_tab"
        "cmd+alt+right=next_tab"
      ];
    }
    // lib.optionalAttrs isDarwin {
      macos-titlebar-style = "tabs";
    };
  };
}
