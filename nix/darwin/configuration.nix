# nix-darwin configuration
# This is your system-level macOS configuration
{
  inputs,
  lib,
  config,
  pkgs,
  username,
  hostname,
  system,
  ...
}: {
  # Import other darwin modules here
  imports = [
    # ./homebrew.nix  # Uncomment when ready
  ];

  # Nixpkgs configuration
  nixpkgs = {
    overlays = [
      inputs.self.overlays.additions
      inputs.self.overlays.modifications
      inputs.self.overlays.stable-packages
    ];
    config = {
      allowUnfree = true;
    };
  };

  # Nix settings
  nix = {
    settings = {
      experimental-features = "nix-command flakes";
    };
    # Optimize storage
    optimise.automatic = true;
    # Garbage collection
    gc = {
      automatic = true;
      interval = { Weekday = 0; Hour = 2; Minute = 0; };
      options = "--delete-older-than 30d";
    };
  };

  # System packages (available system-wide)
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
  ];

  # Homebrew configuration
  # This manages Homebrew packages, casks, and Mac App Store apps
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";  # Remove unlisted packages
      upgrade = true;
    };
    # Third-party taps
    taps = [
      "manaflow-ai/cmux"
    ];
    # CLI tools from Homebrew
    brews = [
    ];
    # GUI applications
    casks = [
      # Browsers
      "arc"
      "google-chrome"
      "thebrowsercompany-dia"
      # Terminals
      "ghostty"
      "cmux"
      # Development
      "visual-studio-code"
      "cursor"
      "orbstack"
      "codex"
      "figma"
      "kicad"
      "autodesk-fusion"
      # AI
      "claude"
      "claude-code"
      "chatgpt-atlas"
      "ollama-app"
      "amical"
      # Communication
      "discord"
      "beeper"
      "microsoft-teams"
      "zoom"
      # Productivity
      "raycast"
      "obsidian"
      "notion"
      "google-drive"
      "onedrive"
      "nani"
      # Microsoft Office
      "microsoft-word"
      "microsoft-excel"
      "microsoft-powerpoint"
      "microsoft-outlook"
      "microsoft-onenote"
      # System utilities
      "karabiner-elements"
      "alt-tab"
      "linearmouse"
      "tailscale-app"
      "rustdesk"
      # Media / Other
      "steam"
      "balenaetcher"
      "affinity"
    ];
    # Mac App Store apps (requires `mas` CLI)
    masApps = {
      "RunCat" = 1429033973;
      "Xcode" = 497799835;
      "Final Cut Pro" = 1631624924;
      "Logic Pro" = 1615087040;
      "Goodnotes" = 1444383602;
      "Developer" = 640199958;
      "TestFlight" = 899247664;
      "Swift Playgrounds" = 1496833156;
      "Compressor" = 6746516157;
      "MainStage" = 6746637089;
      "Motion" = 6746637149;
      "Pixelmator Pro" = 6746662575;
    };
  };

  # macOS system preferences
  system = {
    # Primary user (required for Homebrew and system.defaults)
    primaryUser = username;

    # Set Git commit hash for darwin-version
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

    # Used for backwards compatibility
    stateVersion = 6;

    defaults = {
      # Dock settings
      dock = {
        autohide = true;
        show-recents = false;
        # persistent-apps = [];
      };

      # Finder settings
      finder = {
        AppleShowAllExtensions = true;
        FXEnableExtensionChangeWarning = false;
        _FXShowPosixPathInTitle = true;
      };

      # Global settings
      NSGlobalDomain = {
        # Keyboard repeat rate
        KeyRepeat = 2;
        InitialKeyRepeat = 15;
      };

      # Trackpad settings
      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = true;
      };

      # Screenshot settings
      screencapture = {
        location = "~/Downloads";
      };
    };

    # Keyboard settings
    keyboard = {
      enableKeyMapping = true;
      # remapCapsLockToControl = true;  # Uncomment if needed
    };
  };

  # Enable Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # Networking
  networking.hostName = hostname;

  # User configuration
  users.users.${username} = {
    home = "/Users/${username}";
    shell = pkgs.zsh;
  };

  # Enable zsh (required for home-manager zsh config)
  programs.zsh.enable = true;

  # The platform the configuration will be used on
  nixpkgs.hostPlatform = system;
}
