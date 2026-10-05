# nix-darwin configuration
{
  inputs,
  lib,
  pkgs,
  username,
  hostname,
  system,
  profile ? "workstation",
  # Set to false when using Determinate Nix installer
  nixEnable ? true,
  ...
}:
let
  isServer = profile == "server";
in
{
  nixpkgs = {
    overlays = [
      inputs.self.overlays.additions
    ];
    config.allowUnfree = true;
  };

  # nix.enable = false when using Determinate Nix installer (manages its own daemon)
  nix = {
    enable = nixEnable;
    settings = lib.mkIf nixEnable {
      experimental-features = "nix-command flakes";
      extra-substituters = [ "https://r1ca18.cachix.org" ];
      extra-trusted-public-keys = [
        "r1ca18.cachix.org-1:1QuS/Gqqw3o1atOCkrgl+5hQoLlEvTiRN8OwQT6e6lc="
      ];
    };
    optimise.automatic = lib.mkIf nixEnable true;
    gc = lib.mkIf nixEnable {
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
    onActivation.autoUpdate = true;
    taps = [
      "stablyai/orca"
    ];
    casks =
      lib.optionals (!isServer) [
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
        "stablyai/orca/orca"
        "raycast"
        "steam"
        "stirling-pdf"
        "tailscale-app"
        "utm"
        "zed"
      ]
      ++ lib.optionals isServer [
        "ghostty"
        "stablyai/orca/orca"
        "tailscale-app"
      ];
    masApps = lib.mkIf (!isServer) {
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

  services.openssh.enable = isServer;

  launchd.daemons.orca-server = lib.mkIf isServer {
    serviceConfig = {
      Label = "com.r1ca18.orca-server";
      UserName = username;
      GroupName = "staff";
      ProgramArguments = [
        "/Applications/Orca.app/Contents/Resources/bin/orca"
        "serve"
        "--pairing-address"
        "100.118.19.51"
        "--mobile-pairing"
      ];
      EnvironmentVariables = {
        HOME = "/Users/${username}";
        PATH = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
      WorkingDirectory = "/Users/${username}";
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Background";
      StandardOutPath = "/Users/${username}/Library/Logs/Orca/server.log";
      StandardErrorPath = "/Users/${username}/Library/Logs/Orca/server.log";
    };
  };

  networking.hostName = hostname;

  users.users.${username} = {
    home = "/Users/${username}";
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = lib.optionals isServer [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILNxnu47vU4SYsjtsnToaCeOZSarXXRiJkIxQ7NJJ9i5"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEDYx2wE/80gbRnZBXJgHKTacQTIFrvrpcBfy6PKoZ9x"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPKPp1TXz+Ypy+kIDNWRMVOKtY6PWPJP+R/u9e9Q/pqw"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOqtfY/qQhM1LSHkFZwV+KPlKG1QC0ixkG3OpVHDMQ+5 access-to-mbp187"
    ];
  };

  programs.zsh.enable = true;

  nixpkgs.hostPlatform = system;
}
