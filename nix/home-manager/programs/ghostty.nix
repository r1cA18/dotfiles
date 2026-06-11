{...}:
{
  programs.ghostty = {
    enable = true;
    package = null;
    systemd.enable = false;
    enableZshIntegration = true;
    settings = {
      theme = "TokyoNight";
      maximize = true;
      font-family = "PlemolJP35 Console NF";
      font-size = 20;
      font-thicken = true;
      adjust-cell-height = 2;
      background-opacity = 0.8;
      macos-titlebar-style = "tabs";
      background-blur = false;
      window-inherit-working-directory = true;
      shell-integration = "detect";
      keybind = [
        "ctrl+h=goto_split:left"
        "ctrl+j=goto_split:down"
        "ctrl+k=goto_split:up"
        "ctrl+l=goto_split:right"
        "cmd+alt+left=previous_tab"
        "cmd+alt+right=next_tab"
      ];
    };
  };
}
