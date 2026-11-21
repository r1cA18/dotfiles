{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
  stateDir = "${config.home.homeDirectory}/.local/state/developer-cleanup";
  cleanup = pkgs.writeShellApplication {
    name = "developer-cleanup";
    runtimeInputs = [
      pkgs.python3
      pkgs.git
      pkgs.cargo
      pkgs.rustc
      pkgs.uv
      pkgs.pnpm
      pkgs.cargo-cache
      pkgs.nh
      pkgs.nix
      pkgs.docker-client
    ]
    # macOS uses its own /usr/sbin/lsof.
    ++ lib.optional isLinux pkgs.lsof;
    text = ''
      export NO_COLOR=1
      exec python3 -I ${./developer-cleanup.py} "$@"
    '';
  };
in
{
  config = lib.mkMerge [
    {
      home = {
        file.".local/bin/developer-cleanup".source = "${cleanup}/bin/developer-cleanup";
        activation.prepareDeveloperCleanup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -d -m 700 ${lib.escapeShellArg stateDir}
        '';
      };
    }

    # The homelab runs the same daily sweep; it has no low-space monitor.
    (lib.mkIf isLinux {
      systemd.user = {
        services.developer-cleanup = {
          Unit.Description = "Remove idle developer build output and unused package caches";
          Service = {
            Type = "oneshot";
            ExecStart = "${cleanup}/bin/developer-cleanup --apply";
            Nice = 10;
            IOSchedulingClass = "idle";
          };
        };
        timers.developer-cleanup = {
          Unit.Description = "Daily developer cleanup";
          Timer = {
            OnCalendar = "*-*-* 01:00:00";
            Persistent = true;
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };
    })

    (lib.mkIf isDarwin {
      home = {
        activation.releaseDeveloperCleanupBootstrap = lib.hm.dag.entryAfter [ "setupLaunchAgents" ] ''
          if [ -L ${lib.escapeShellArg "${stateDir}/deployment"} ]; then
            $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm ${lib.escapeShellArg "${stateDir}/deployment"}
          fi
        '';
      };
      launchd.agents.developer-cleanup = {
        enable = true;
        config = {
          Label = "org.dotfiles.developer-cleanup";
          ProgramArguments = [
            "${cleanup}/bin/developer-cleanup"
            "--apply"
          ];
          StartCalendarInterval = {
            Hour = 1;
            Minute = 0;
          };
          RunAtLoad = false;
          ProcessType = "Standard";
          LowPriorityIO = false;
          Nice = 10;
          StandardOutPath = "/dev/null";
          StandardErrorPath = "${stateDir}/launchd-error.log";
          EnvironmentVariables = {
            HOME = config.home.homeDirectory;
          };
        };
      };
      launchd.agents.developer-cleanup-monitor = {
        enable = true;
        config = {
          Label = "org.dotfiles.developer-cleanup-monitor";
          ProgramArguments = [
            "${cleanup}/bin/developer-cleanup"
            "--monitor"
            "--apply"
          ];
          StartInterval = 3600;
          RunAtLoad = true;
          ProcessType = "Standard";
          LowPriorityIO = false;
          Nice = 10;
          StandardOutPath = "/dev/null";
          StandardErrorPath = "${stateDir}/launchd-error.log";
          EnvironmentVariables = {
            HOME = config.home.homeDirectory;
          };
        };
      };
    })
  ];
}
