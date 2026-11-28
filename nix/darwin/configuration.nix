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
    # cleanup stays "none": removing an entry only stops managing the app,
    # so apps removed by hand are dropped here without uninstalling anything.
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
      "aqua-voice"
      "aside"
      "nikitabobko/tap/aerospace"
      "autodesk-fusion"
      "balenaetcher"
      "bambu-studio"
      "beeper"
      "figma"
      "ghostty"
      "google-chrome"
      "google-drive"
      "google-japanese-ime"
      "karabiner-elements"
      "keyboardcleantool"
      "microsoft-powerpoint"
      "microsoft-word"
      "notion"
      "notunes"
      "ollama-app"
      "orbstack"
      # Personal Orca build; kept until Orca is retired.
      "r1cA18/orca/orca-personal"
      "raycast"
      "stirling-pdf"
      "switchbar"
      "tailscale-app"
      "zed"
    ];
    # Installed by hand and not declared here:
    # - casks exist but the apps were not installed by Homebrew; declaring one
    #   needs `brew install --cask --adopt <cask>` first: AWS VPN Client
    #   (aws-vpn-client)
    # - no cask: AutoRaise, Blackmagic Proxy Generator Lite, Blackmagic RAW,
    #   DaVinci Resolve, Overshell, CCSpace (~/Applications)
    masApps = {
      "Developer" = 640199958;
      "Numbers" = 361304891;
      "Pages" = 361309726;
      "RunCat Neo" = 6757801838;
      "TestFlight" = 899247664;
      "WeChat" = 836500024;
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
