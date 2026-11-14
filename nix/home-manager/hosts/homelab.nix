{ config, pkgs, ... }:
let
  # Advertise homelab's Tailscale IPv4 to paired phones. UFW only admits
  # tailscale0. The address is read at start so it is not kept in this repo.
  orcaServe = pkgs.writeShellApplication {
    name = "orca-serve";
    runtimeInputs = [
      pkgs.tailscale
      pkgs.coreutils
    ];
    text = ''
      addr=$(tailscale ip -4 | head -n 1)
      if [ -z "$addr" ]; then
        echo "orca-serve: no Tailscale IPv4 address" >&2
        exit 1
      fi
      exec ${pkgs.orca-ide}/bin/orca-ide serve --port 6768 --pairing-address "$addr" --mobile-pairing
    '';
  };

  # Restart orca-serve and render its mobile pairing offer as a terminal QR.
  # An unclaimed offer is reused across restarts; a claimed one is replaced.
  orcaPair = pkgs.writeShellApplication {
    name = "orca-pair";
    runtimeInputs = [ pkgs.qrencode ];
    text = ''
      since=$(date '+%Y-%m-%d %H:%M:%S')
      systemctl --user restart orca-serve.service
      url=""
      for _ in $(seq 60); do
        url=$(journalctl --user -t orca-ide --since "$since" -o cat --no-pager \
          | grep -ao 'orca://pair?code=[A-Za-z0-9_=-]*' | tail -n 1 || true)
        [ -n "$url" ] && break
        sleep 1
      done
      if [ -z "$url" ]; then
        echo "orca-serve printed no pairing URL; see: journalctl --user -t orca-ide" >&2
        exit 1
      fi
      qrencode -t ANSIUTF8 "$url"
      echo "$url"
    '';
  };
in
{
  imports = [
    ../home.nix
    ../programs/r1hnd-service.nix
    ./olympus-legacy.nix
  ];

  # The secretary's home and the only writer of the vault: r1hnd keeps the
  # Times and tasks, the assistant, and runs the jobs in ~/vault/40_AI/r1/jobs
  # (times-triage, deadline-allocation, weekly-review, the nightly feed).
  # Every other host is a coding worker.
  dotfiles.r1hn.serve.role = "primary";

  # Headless Orca runtime for mobile pairing.
  # The binary is not named `orca` because that resolves to GNOME's screen reader.
  home.packages = [
    pkgs.orca-ide
    orcaPair
  ];

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

      # Paired devices live in ~/.config/orca and survive restarts. Orca moves its
      # main process and terminal daemon into app-orca-*.scope units, so logs are
      # under `journalctl --user -t orca-ide` and restarts keep live terminals.
      # Run `orca-pair` to show a QR for pairing another phone.
      orca-serve = {
        Unit = {
          Description = "Orca headless runtime server";
          StartLimitIntervalSec = 300;
          StartLimitBurst = 5;
        };
        Service = {
          ExecStart = "${orcaServe}/bin/orca-serve";
          WorkingDirectory = config.home.homeDirectory;
          Environment = [ "LIBGL_ALWAYS_SOFTWARE=1" ];
          # The user manager may carry an xrdp/GNOME display; Orca must start its
          # own Xvfb instead of depending on a desktop session.
          UnsetEnvironment = [
            "DISPLAY"
            "WAYLAND_DISPLAY"
            "GNOME_SETUP_DISPLAY"
          ];
          KillMode = "mixed";
          Restart = "on-failure";
          # Exit 3: another Orca instance already owns the profile.
          RestartPreventExitStatus = 3;
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
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
