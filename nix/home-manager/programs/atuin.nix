_: {
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    flags = [
      "--disable-up-arrow"
    ];
    settings = {
      auto_sync = false;
      enter_accept = true;
      filter_mode = "global";
      inline_height = 20;
      style = "compact";
      update_check = false;
    };
  };
}
