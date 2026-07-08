# nix-darwin configuration
{
  inputs,
  lib,
  pkgs,
  username,
  hostname,
  system,
  # Set to false when using Determinate Nix installer
  nixEnable ? true,
  ...
}:
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
    casks = [ "notunes" ];
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
