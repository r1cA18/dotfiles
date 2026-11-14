{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
# r1hnd (`r1hn serve`) and a T3 Code server that reaches agents only through
# `r1hn acp`: systemd user services on Linux (homelab) and launchd agents on
# macOS. Each starts only once its inputs exist, so applying this before any
# login is harmless:
#
# - r1hnd needs the ledger `~/.config/r1hn/accounts.toml`
# - t3-r1hn needs a build made by `t3-r1hn-build` and the ledger
#
# Linux checks a Condition when a unit starts; macOS runs a wrapper that exits
# 0 when an input is missing, and KeepAlive restarts only a failed exit. After
# creating either file start them once (`systemctl --user start r1hnd t3-r1hn`,
# or `launchctl kickstart gui/$(id -u)/org.dotfiles.r1hnd` and
# `.../org.dotfiles.t3-r1hn`); later logins start them by themselves.
# Logs: `journalctl --user -u r1hnd` / `-u t3-r1hn`, or `~/Library/Logs/r1hn/`.
let
  cfg = config.dotfiles.r1hn.serve;
  inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
  r1hn = inputs.r1hn.packages.${pkgs.stdenv.hostPlatform.system}.r1hn;
  node = pkgs.nodejs_26;
  home = config.home.homeDirectory;
  # The build `t3-r1hn-build` points this at; the service runs it.
  t3Root = "${config.xdg.dataHome}/t3-r1hn";
  t3Bin = "${t3Root}/current/apps/server/dist/bin.mjs";
  t3EnvFile = "${config.xdg.configHome}/t3-r1hn/env";
  ledger = "${config.xdg.configHome}/r1hn/accounts.toml";
  logDir = "${home}/Library/Logs/r1hn";
  # T3 Code desktop (cask t3-code) keeps its settings in the T3 home it shares
  # with t3-r1hn.
  t3DesktopSettings = "${home}/.t3/userdata/desktop-settings.json";
  launchdLabel = name: "org.dotfiles.${name}";

  # Official clients (claude, codex, agy) live in ~/.local/bin and Nix
  # profiles. r1hn hands this PATH to the clients it starts.
  clientPath = lib.concatStringsSep ":" (
    [ "${home}/.local/bin" ]
    ++ lib.optionals isDarwin [
      "/etc/profiles/per-user/${config.home.username}/bin"
      "/run/current-system/sw/bin"
    ]
    ++ [
      "${home}/.nix-profile/bin"
      "/nix/var/nix/profiles/default/bin"
    ]
    ++ lib.optionals isDarwin [ "/opt/homebrew/bin" ]
    ++ [
      "/usr/local/bin"
      "/usr/bin"
      "/bin"
    ]
  );
  # T3 Code itself needs git and a shell for its terminals, not the clients.
  t3Path = lib.concatStringsSep ":" (
    [ "${pkgs.git}/bin" ]
    ++ lib.optionals isDarwin [
      "/etc/profiles/per-user/${config.home.username}/bin"
      "/run/current-system/sw/bin"
    ]
    ++ [
      "${home}/.nix-profile/bin"
      "/nix/var/nix/profiles/default/bin"
      "/usr/bin"
      "/bin"
    ]
  );

  restartHint =
    if isDarwin then
      "launchctl kickstart -k gui/$(id -u)/${launchdLabel "t3-r1hn"}"
    else
      "systemctl --user restart t3-r1hn";

  # Build a checkout of the r1hn fork of T3 Code and make it the one the
  # service runs. The checkout must be committed so a build names one revision.
  t3Build = pkgs.writeShellApplication {
    name = "t3-r1hn-build";
    runtimeInputs = [
      node
      pkgs.pnpm
      pkgs.git
      pkgs.coreutils
    ];
    text = ''
      src=$(cd "''${1:?usage: t3-r1hn-build CHECKOUT}" && pwd)
      cd "$src"
      if [ -n "$(git status --porcelain)" ]; then
        echo "t3-r1hn-build: $src has uncommitted changes" >&2
        exit 1
      fi
      # Public identifiers of the production T3 Connect deployment. A build
      # without them has T3 Connect disabled.
      if [ ! -e .env ]; then
        cp .env.example .env
      fi
      pnpm install --frozen-lockfile
      pnpm exec vp run --filter t3 build
      test -f apps/server/dist/bin.mjs
      mkdir -p ${t3Root}
      ln -sfn "$src" ${t3Root}/current
      echo "t3-r1hn-build: built $(git rev-parse --short HEAD)"
      echo "restart with: ${restartHint}"
    '';
  };

  # The CLI of the same build, for `t3 connect link`, `t3 pair` and `t3 status`.
  # Do not run `t3 up` or `t3 service install`: they install upstream's own
  # service beside this one.
  t3Cli = pkgs.writeShellApplication {
    name = "t3";
    text = ''
      if [ ! -f ${t3Bin} ]; then
        echo "t3: no build yet; run t3-r1hn-build CHECKOUT" >&2
        exit 1
      fi
      exec ${node}/bin/node ${t3Bin} "$@"
    '';
  };

  # launchd has no start condition, so r1hnd on macOS starts through this.
  r1hndStart = pkgs.writeShellApplication {
    name = "r1hnd-start";
    text = ''
      if [ ! -f ${ledger} ]; then
        echo "r1hnd: no ledger at ${ledger}; not starting" >&2
        exit 0
      fi
      exec ${r1hn}/bin/r1hn serve --listen ${cfg.listen}
    '';
  };

  # Starts `t3 serve` with the r1hn gateway. ~/.config/t3-r1hn/env holds
  # optional KEY=value lines (T3CODE_R1HN_GROUPS, T3CODE_R1HN_COMMAND,
  # T3CODE_LAN, T3CODE_PORT), read literally as systemd's EnvironmentFile does.
  # Without T3CODE_R1HN_GROUPS T3 offers every ledger group that has an
  # account, so group names stay out of this repository.
  t3Start = pkgs.writeShellApplication {
    name = "t3-r1hn-start";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      if [ ! -f ${t3Bin} ] || [ ! -f ${ledger} ]; then
        echo "t3-r1hn: needs ${t3Bin} and ${ledger}; not starting" >&2
        exit 0
      fi
      if [ -f ${t3EnvFile} ]; then
        while IFS= read -r line || [ -n "$line" ]; do
          case $line in "" | "#"* | ";"*) continue ;; esac
          key=''${line%%=*}
          value=''${line#*=}
          case $value in
            \"*\")
              value=''${value#\"}
              value=''${value%\"}
              ;;
            \'*\')
              value=''${value#\'}
              value=''${value%\'}
              ;;
          esac
          if [[ $key =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
            export "$key=$value"
          else
            echo "t3-r1hn: ignoring line in ${t3EnvFile}: $line" >&2
          fi
        done < ${t3EnvFile}
      fi
      : "''${T3CODE_R1HN_COMMAND:=${r1hn}/bin/r1hn acp}"
      export T3CODE_R1HN_COMMAND
      if [ -z "''${T3CODE_R1HN_GROUPS:-}" ]; then
        T3CODE_R1HN_GROUPS=$(${r1hn}/bin/r1hn group list --json \
          | jq -r '[.groups[] | select(.accounts | length > 0) | .name] | join(",")')
      fi
      if [ -z "$T3CODE_R1HN_GROUPS" ]; then
        echo "t3-r1hn: the ledger has no group with an account; not starting" >&2
        exit 0
      fi
      export T3CODE_R1HN_GROUPS
      echo "t3-r1hn: groups $T3CODE_R1HN_GROUPS" >&2
      exec ${node}/bin/node ${t3Bin} serve
    '';
  };
in
{
  options.dotfiles.r1hn.serve = {
    listen = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:7790";
      description = "Loopback address of r1hnd. Publish it to the tailnet with `tailscale serve` by hand.";
    };
  };

  config = lib.mkMerge [
    {
      dotfiles.r1hn.enable = true;

      home.packages = [
        t3Build
        t3Cli
      ];
    }

    (lib.mkIf isLinux {
      systemd.user.services = {
        r1hnd = {
          Unit = {
            Description = "r1hn endpoint (r1hnd)";
            ConditionPathExists = [ ledger ];
            StartLimitIntervalSec = 300;
            StartLimitBurst = 5;
          };
          Service = {
            ExecStart = "${r1hn}/bin/r1hn serve --listen ${cfg.listen}";
            WorkingDirectory = home;
            Environment = [ "PATH=${clientPath}" ];
            # SIGTERM interrupts running turns and gives clients 5 seconds.
            TimeoutStopSec = 20;
            Restart = "on-failure";
            RestartSec = 5;
          };
          Install.WantedBy = [ "default.target" ];
        };

        # `t3 serve` is what upstream's background service runs. It listens on
        # loopback; T3 Connect or `T3CODE_LAN=true` makes it reachable.
        t3-r1hn = {
          Unit = {
            Description = "T3 Code server with the r1hn gateway";
            ConditionPathExists = [
              t3Bin
              ledger
            ];
            Wants = [ "r1hnd.service" ];
            After = [ "r1hnd.service" ];
            StartLimitIntervalSec = 300;
            StartLimitBurst = 5;
          };
          Service = {
            ExecStart = "${t3Start}/bin/t3-r1hn-start";
            WorkingDirectory = home;
            Environment = [ "PATH=${t3Path}" ];
            KillMode = "mixed";
            Restart = "on-failure";
            RestartSec = 5;
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
    })

    (lib.mkIf isDarwin {
      # launchd does not create the directory of StandardOutPath.
      home.activation.prepareR1hnLogs = lib.hm.dag.entryBefore [ "setupLaunchAgents" ] ''
        run ${pkgs.coreutils}/bin/install -d -m 700 ${lib.escapeShellArg logDir}
      '';

      # The desktop app would otherwise start its own upstream server, whose
      # providers use the logins of claude and codex directly. With the local
      # environment off it only connects to environments added by pairing
      # (t3-r1hn here and on homelab). Kept off on every activation; the file
      # is merged so the app's other settings stay.
      home.activation.t3DesktopClientOnly = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        settings=${lib.escapeShellArg t3DesktopSettings}
        current='{}'
        if [ -s "$settings" ]; then
          current=$(${pkgs.jq}/bin/jq -c . "$settings") || current=""
        fi
        if [ -z "$current" ]; then
          warnEcho "t3: $settings is not JSON; set localEnvironmentEnabled to false by hand"
        elif [ "$(${pkgs.jq}/bin/jq -r '.localEnvironmentEnabled' <<<"$current")" != false ]; then
          run ${pkgs.coreutils}/bin/install -d -m 700 "$(dirname "$settings")"
          if [ -z "''${DRY_RUN:-}" ]; then
            ${pkgs.jq}/bin/jq '.localEnvironmentEnabled = false' <<<"$current" > "$settings.tmp"
            mv "$settings.tmp" "$settings"
          fi
        fi
      '';

      launchd.agents = {
        # KeepAlive on a failed exit only: the wrapper's exit 0 (no ledger)
        # does not loop, and the console restart (exit 75) starts it again.
        # R1HN_SUPERVISED tells r1hnd it has a supervisor (launchd is not
        # detected the way systemd is).
        r1hnd = {
          enable = true;
          config = {
            Label = launchdLabel "r1hnd";
            ProgramArguments = [ "${r1hndStart}/bin/r1hnd-start" ];
            RunAtLoad = true;
            KeepAlive.SuccessfulExit = false;
            ThrottleInterval = 10;
            # SIGTERM interrupts running turns and gives clients 5 seconds.
            ExitTimeOut = 20;
            ProcessType = "Standard";
            WorkingDirectory = home;
            EnvironmentVariables = {
              PATH = clientPath;
              R1HN_SUPERVISED = "1";
            };
            StandardOutPath = "${logDir}/r1hnd.log";
            StandardErrorPath = "${logDir}/r1hnd.log";
          };
        };

        t3-r1hn = {
          enable = true;
          config = {
            Label = launchdLabel "t3-r1hn";
            ProgramArguments = [ "${t3Start}/bin/t3-r1hn-start" ];
            RunAtLoad = true;
            KeepAlive.SuccessfulExit = false;
            ThrottleInterval = 10;
            ProcessType = "Standard";
            WorkingDirectory = home;
            EnvironmentVariables.PATH = t3Path;
            StandardOutPath = "${logDir}/t3-r1hn.log";
            StandardErrorPath = "${logDir}/t3-r1hn.log";
          };
        };
      };
    })
  ];
}
