{
  config,
  lib,
  pkgs,
  ...
}:
# The Olympus triage and deadline units on homelab. r1hn jobs replace them
# (`times-triage` and `deadline-allocation` in ~/vault/40_AI/r1/jobs). Once
# those jobs have run for a week, set
# `dotfiles.olympus.legacyUnits.enable = false` in homelab.nix and apply: Home
# Manager stops and removes the four units. Then delete this file and the
# scripts in ~/vault/40_AI/automation/.
let
  cfg = config.dotfiles.olympus.legacyUnits;
  script =
    name: "${pkgs.bash}/bin/bash ${config.home.homeDirectory}/vault/40_AI/automation/${name}.sh";
in
{
  options.dotfiles.olympus.legacyUnits.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Keep the Olympus times triage and deadline scheduler units (replaced by r1hn jobs).";
  };

  config = lib.mkIf cfg.enable {
    systemd.user = {
      services = {
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
            ExecStart = script "olympus-times-triage";
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
            ExecStart = script "olympus-deadline-scheduler";
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
  };
}
