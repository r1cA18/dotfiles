{ config, pkgs, ... }:
{
  imports = [ ../home.nix ];

  # Keep Codex available to SSH-driven ChatGPT clients even when no graphical
  # session is logged in. homelab/ansible/playbook.yml enables linger for this
  # user, so default.target and this service also run after logout and at boot.
  systemd.user = {
    services = {
      codex-app-server = {
        Unit = {
          Description = "Codex app server";
          ConditionPathExists = [ "/etc/apparmor.d/codex-app-server" ];
        };
        Service = {
          ExecStart = "${pkgs.codex}/bin/codex app-server --listen unix://";
          WorkingDirectory = config.home.homeDirectory;
          Restart = "always";
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
      };

      olympus-times-triage = {
        Unit = {
          Description = "Debounced Olympus triage for new Times entries";
          After = [
            "network-online.target"
            "codex-app-server.service"
          ];
          Wants = [ "network-online.target" ];
        };
        Service = {
          Type = "oneshot";
          Environment = [ "CODEX_HOME=%h/.codex" ];
          ExecStart = "${pkgs.bash}/bin/bash /home/r1ca18/vault/40_AI/automation/olympus-times-triage.sh";
          TimeoutStartSec = "4h";
          Nice = 10;
          IOSchedulingClass = "idle";
        };
      };

      olympus-deadline-scheduler = {
        Unit = {
          Description = "Allocate unscheduled Olympus inbox/todo deadline tasks";
          After = [
            "network-online.target"
            "codex-app-server.service"
          ];
          Wants = [ "network-online.target" ];
        };
        Service = {
          Type = "oneshot";
          Environment = [ "CODEX_HOME=%h/.codex" ];
          ExecStart = "${pkgs.bash}/bin/bash /home/r1ca18/vault/40_AI/automation/olympus-deadline-scheduler.sh";
          TimeoutStartSec = "10min";
          Nice = 10;
          IOSchedulingClass = "idle";
        };
      };
    };

    timers = {
      olympus-times-triage = {
        Unit = {
          Description = "Check for new Times entries every 15 minutes";
          ConditionPathExists = "%h/.local/state/olympus-times-triage/enabled";
        };
        Timer = {
          OnBootSec = "15min";
          OnUnitActiveSec = "15min";
          AccuracySec = "1min";
          Persistent = false;
          Unit = "olympus-times-triage.service";
        };
        Install.WantedBy = [ "timers.target" ];
      };

      olympus-deadline-scheduler = {
        Unit = {
          Description = "Check hourly for unscheduled Olympus deadline tasks";
          ConditionPathExists = "%h/.local/state/olympus-deadline-scheduler/enabled";
        };
        Timer = {
          OnBootSec = "20min";
          OnUnitActiveSec = "1h";
          AccuracySec = "5min";
          Persistent = false;
          Unit = "olympus-deadline-scheduler.service";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };

  # MacBook (RMB). The new homelab gets its own Syncthing identity on first
  # start. Since this host already knows RMB, only RMB needs to accept the new
  # device once; the folder IDs remain stable across the migration.
  services.syncthing = {
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      options = {
        localAnnounceEnabled = true;
        relaysEnabled = true;
        urAccepted = -1;
      };
      devices.RMB = {
        id = "VI7PYJO-2DJSWXG-7XNU6XB-KKMELIW-UF2GYL5-DF5HYGN-HSUJ5KU-NZWBEAA";
        addresses = [ "dynamic" ];
      };
      folders = {
        vault = {
          id = "ecvg9-qifz9";
          label = "vault";
          path = "${config.home.homeDirectory}/vault";
          type = "sendreceive";
          devices = [ "RMB" ];
          ignorePerms = true;
          fsWatcherEnabled = true;
          rescanIntervalS = 3600;
          maxConflicts = 20;
          versioning = {
            type = "staggered";
            params = {
              cleanInterval = "3600";
              maxAge = "2592000";
            };
          };
        };
        Develop = {
          id = "tj9sr-r4ieg";
          label = "Develop";
          path = "${config.home.homeDirectory}/Develop";
          type = "sendreceive";
          devices = [ "RMB" ];
          ignorePerms = true;
          fsWatcherEnabled = true;
          rescanIntervalS = 3600;
          maxConflicts = 20;
          versioning = {
            type = "staggered";
            params = {
              cleanInterval = "3600";
              maxAge = "2592000";
            };
          };
        };
      };
    };
  };
}
