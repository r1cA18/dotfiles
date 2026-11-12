# nix-darwin configuration
{
  inputs,
  pkgs,
  username,
  hostname,
  system,
  ...
}:
{
  nixpkgs = {
    overlays = [
      inputs.self.overlays.additions
    ];
    config.allowUnfree = true;
  };

  nix = {
    settings = {
      experimental-features = "nix-command flakes";
      extra-substituters = [ "https://r1ca18.cachix.org" ];
      extra-trusted-public-keys = [
        "r1ca18.cachix.org-1:1QuS/Gqqw3o1atOCkrgl+5hQoLlEvTiRN8OwQT6e6lc="
      ];
    };
    optimise.automatic = true;
    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 2;
        Minute = 0;
      };
      options = "--delete-older-than 30d";
    };
  };

  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
  ];

  documentation.doc.enable = false;
  system.tools.darwin-uninstaller.enable = false;

  homebrew = {
    enable = true;
    # Homebrew is updated by `dot update`, not on activation.
    onActivation.autoUpdate = false;
    taps = [
      {
        name = "r1cA18/orca";
        clone_target = "https://github.com/r1cA18/orca.git";
        trusted = true;
      }
    ];
    casks = [
      "1password"
      "affinity"
      "alt-tab"
      "amical"
      "arc"
      "nikitabobko/tap/aerospace"
      "audacity"
      "autodesk-fusion"
      "balenaetcher"
      "bambu-studio"
      "beeper"
      "chatgpt"
      "claude"
      "discord"
      "figma"
      "ghostty"
      "google-chrome"
      "google-drive"
      "google-japanese-ime"
      "karabiner-elements"
      "keyboardcleantool"
      "microsoft-excel"
      "microsoft-outlook"
      "microsoft-powerpoint"
      "microsoft-word"
      "notunes"
      "ollama-app"
      "orbstack"
      "r1cA18/orca/orca-personal"
      "raycast"
      "steam"
      "stirling-pdf"
      "tailscale-app"
      "utm"
      "zed"
    ];
    masApps = {
      "Developer" = 640199958;
      "Keynote" = 361285480;
      "Kindle" = 302584613;
      "Numbers" = 361304891;
      "Pages" = 361309726;
      "RunCat Neo" = 6757801838;
      "Swift Playgrounds" = 1496833156;
      "TestFlight" = 899247664;
      "Windows App" = 1295203466;
      "Xcode" = 497799835;
    };
  };

  system = {
    primaryUser = username;
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
    stateVersion = 6;

    defaults = {
      dock = {
        autohide = true;
        show-recents = false;
        showAppExposeGestureEnabled = true;
        showDesktopGestureEnabled = true;
        showMissionControlGestureEnabled = true;
      };
      finder = {
        AppleShowAllExtensions = true;
        FXEnableExtensionChangeWarning = false;
        _FXShowPosixPathInTitle = true;
      };
      NSGlobalDomain = {
        KeyRepeat = 2;
        InitialKeyRepeat = 15;
      };
      trackpad = {
        Clicking = false;
        ForceSuppressed = true;
        TrackpadPinch = true;
        TrackpadRightClick = true;
        TrackpadRotate = true;
        TrackpadThreeFingerDrag = false;
        TrackpadThreeFingerHorizSwipeGesture = 2;
        TrackpadThreeFingerTapGesture = 2;
        TrackpadThreeFingerVertSwipeGesture = 2;
        TrackpadTwoFingerDoubleTapGesture = true;
        TrackpadTwoFingerFromRightEdgeSwipeGesture = 3;
      };
      screencapture.location = "~/Downloads";
    };

    keyboard.enableKeyMapping = true;
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  networking.hostName = hostname;

  users.users.${username} = {
    home = "/Users/${username}";
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;

  nixpkgs.hostPlatform = system;
}
