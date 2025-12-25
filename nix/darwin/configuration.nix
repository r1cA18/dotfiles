# nix-darwin configuration
# This is your system-level macOS configuration
{
  inputs,
  lib,
  config,
  pkgs,
  username,
  hostname,
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
    # CLI tools from Homebrew (prefer nixpkgs when possible)
    brews = [
      # "example-brew"
    ];
    # GUI applications
    casks = [
      "orbstack"
      "ghostty"
      "raycast"
      "karabiner-elements"
      "alt-tab"
      "google-chrome"
      "google-drive"
      "discord"
      "obsidian"
      "notion"
      "visual-studio-code"
      "cursor"
      "ollama-app"
      "tailscale-app"
      "arc"
      "linearmouse"
      "shortcat"
      "claude"
      "rustdesk"
    ];
    # Mac App Store apps (requires `mas` CLI)
    masApps = {
      # "App Name" = app-id;
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
        AppleShowAllExtensions = true;
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
  nixpkgs.hostPlatform = "aarch64-darwin";
}

