{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
# r1hnd (`r1hn serve`) and an r1 code server that reaches agents only through
# `r1hn acp`: systemd user services on Linux (homelab) and launchd agents on
# macOS. Each starts only once its inputs exist, so applying this before any
# login is harmless:
#
# - r1hnd needs the ledger `~/.config/r1hn/accounts.toml`
# - r1code needs a build made by `r1code-build` and the ledger
#
# Linux checks a Condition when a unit starts; macOS runs a wrapper that exits
# 0 when an input is missing, and KeepAlive restarts only a failed exit. After
# creating either file start them once (`systemctl --user start r1hnd r1code`,
# or `launchctl kickstart gui/$(id -u)/org.dotfiles.r1hnd` and
# `.../org.dotfiles.r1code`); later logins start them by themselves.
# Logs: `journalctl --user -u r1hnd` / `-u r1code`, or `~/Library/Logs/r1hn/`.
#
# r1code replaced the `t3-r1hn` service (the r1hn fork of T3 Code). It keeps
# its state in `~/.r1code` and never reads `~/.t3`; the one-time data import
# and the rollback are in docs/guides/r1hn.md.
#
# `~/.config/r1hn/config.toml` stays the owner's file (r1hnd's console writes
# it too). Activation merges only the keys in `managedSettings` into it and
# keeps the rest, so private keys ([push], groups, [env.<group>]) live there
# and never in this repository; see docs/guides/r1hn.md.
let
  cfg = config.dotfiles.r1hn.serve;
  inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
  r1hn = inputs.r1hn.packages.${pkgs.stdenv.hostPlatform.system}.r1hn;
  node = pkgs.nodejs_26;
  home = config.home.homeDirectory;
  # The build `r1code-build` points this at; the service runs it.
  r1codeRoot = "${config.xdg.dataHome}/r1code";
  r1codeBin = "${r1codeRoot}/current/apps/server/dist/bin.mjs";
  r1codeEnvFile = "${config.xdg.configHome}/r1code/env";
  # The service's data directory. The CLI names it too: in a linked git
  # worktree `r1code pair` would otherwise look for a dev server in the
  # worktree's own `.r1code` (upstream's `bun dev` behaviour).
  r1codeHome = "${home}/.r1code";
  # The revision of r1cA18/r1-code that `r1code-build` builds by default.
  r1codeRepo = "git@github.com:r1cA18/r1-code.git";
  r1codeRev = "8b536705388b426f0c1f6bf0378deb148df7bba4";
  ledger = "${config.xdg.configHome}/r1hn/accounts.toml";
  logDir = "${home}/Library/Logs/r1hn";
  # The r1 code desktop app keeps its settings in `~/.r1code`, the home it
  # shares with the r1code service.
  desktopSettings = [ "${home}/.r1code/userdata/desktop-settings.json" ];
  launchdLabel = name: "org.dotfiles.${name}";
  configToml = "${config.xdg.configHome}/r1hn/config.toml";

  # Public keys of config.toml, merged by activation. The vault reaches every
  # host through Syncthing, so one worker writes it: the primary (homelab)
  # runs the Times and tasks watcher, the assistant and the jobs; every other
  # host is a coding worker that runs sessions only and refuses the vault's
  # routes (`[worker] role`, see harness-core docs/r1hn-workers.md).
  primary = cfg.role == "primary";
  managedSettings = {
    worker.role = cfg.role;
    jobs = {
      enabled = primary;
      dir = "~/vault/40_AI/r1/jobs";
      tz = "Asia/Tokyo";
      tick_seconds = 30;
    };
    records = {
      root = "~/vault";
      times_dir = "11_Times";
      tasks_dir = "32_Tasks";
    };
    assistant.cwd = "~/vault";
  };
  settingsFragment = {
    entries = managedSettings;
  };
  settingsFile = pkgs.writeText "r1hn-settings.json" (builtins.toJSON settingsFragment);
  merge = import ../../lib/merge-managed.nix { inherit pkgs lib; };

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
  # r1 code itself needs git and a shell for its terminals, not the clients.
  r1codePath = lib.concatStringsSep ":" (
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
      "launchctl kickstart -k gui/$(id -u)/${launchdLabel "r1code"}"
    else
      "systemctl --user restart r1code";

  # Build r1 code and make it the one the service runs. Without an argument it
  # builds `r1codeRev` in its own clone; with one it builds that checkout's
  # HEAD, which must be committed so a build names one revision.
  r1codeBuild = pkgs.writeShellApplication {
    name = "r1code-build";
    runtimeInputs = [
      node
      pkgs.pnpm
      pkgs.git
      pkgs.coreutils
    ];
    text = ''
      if [ $# -gt 0 ]; then
        src=$(cd "$1" && pwd)
      else
        src=${r1codeRoot}/src
        if [ ! -d "$src/.git" ]; then
          git clone ${r1codeRepo} "$src"
        fi
        git -C "$src" fetch --quiet origin
        git -C "$src" checkout --quiet --detach ${r1codeRev}
      fi
      cd "$src"
      if [ -n "$(git status --porcelain)" ]; then
        echo "r1code-build: $src has uncommitted changes" >&2
        exit 1
      fi
      pnpm install --frozen-lockfile
      pnpm exec vp run --filter r1code build
      test -f apps/server/dist/bin.mjs
      mkdir -p ${r1codeRoot}
      ln -sfn "$src" ${r1codeRoot}/current
      echo "r1code-build: built $(git rev-parse --short HEAD)"
      echo "restart with: ${restartHint}"
    '';
  };

  # Build r1 code's desktop app and install it as /Applications/r1 code.app
  # (macOS). Like r1code-build it builds `r1codeRev`, in a clone of its own so
  # the running service's build is not rebuilt, or the HEAD of a checkout
  # given as the argument. The app has no update feed and is signed with the
  # keychain's Apple Development identity, or ad hoc; see the revision's
  # scripts/build-desktop-mac.sh.
  r1codeDesktopBuild = pkgs.writeShellApplication {
    name = "r1code-desktop-build";
    runtimeInputs = [
      node
      pkgs.pnpm
      pkgs.git
      pkgs.rustc
      pkgs.cargo
    ];
    text = ''
      if [ $# -gt 0 ]; then
        src=$(cd "$1" && pwd)
      else
        src=${r1codeRoot}/desktop-src
        if [ ! -d "$src/.git" ]; then
          git clone ${r1codeRepo} "$src"
        fi
        git -C "$src" fetch --quiet origin
        git -C "$src" checkout --quiet --detach ${r1codeRev}
      fi
      cd "$src"
      if [ -n "$(git status --porcelain)" ]; then
        echo "r1code-desktop-build: $src has uncommitted changes" >&2
        exit 1
      fi
      if [ ! -f scripts/build-desktop-mac.sh ]; then
        echo "r1code-desktop-build: $(git rev-parse --short HEAD) has no scripts/build-desktop-mac.sh" >&2
        exit 1
      fi
      pnpm install --frozen-lockfile
      bash scripts/build-desktop-mac.sh
    '';
  };

  # The CLI of the same build, for `r1code pair` and `r1code status`. Do not
  # run `r1code up` or `r1code service install`: they install the CLI's own
  # service beside this one. It targets the service's home unless
  # R1CODE_HOME or `--base-dir` names another; `pair` prefers a linked
  # worktree's `.r1code` over R1CODE_HOME, so it gets the flag.
  r1codeCli = pkgs.writeShellApplication {
    name = "r1code";
    text = ''
      if [ ! -f ${r1codeBin} ]; then
        echo "r1code: no build yet; run r1code-build" >&2
        exit 1
      fi
      : "''${R1CODE_HOME:=${r1codeHome}}"
      export R1CODE_HOME
      if [ "''${1:-}" = pair ]; then
        explicit=false
        for arg in "$@"; do
          case $arg in --base-dir | --base-dir=*) explicit=true ;; esac
        done
        if [ "$explicit" = false ]; then
          shift
          set -- pair --base-dir "$R1CODE_HOME" "$@"
        fi
      fi
      exec ${node}/bin/node ${r1codeBin} "$@"
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

  # Starts `r1code serve` with the r1hn gateway. ~/.config/r1code/env holds
  # optional KEY=value lines (R1CODE_R1HN_COMMAND, R1CODE_R1HN_GROUPS,
  # R1CODE_LAN, R1CODE_PORT, R1CODE_SERVER_BROWSER_SANDBOX), read literally as
  # systemd's EnvironmentFile does. Without R1CODE_R1HN_GROUPS r1 code offers
  # every ledger group that has an account, so group names stay out of this
  # repository.
  r1codeStart = pkgs.writeShellApplication {
    name = "r1code-start";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      if [ ! -f ${r1codeBin} ] || [ ! -f ${ledger} ]; then
        echo "r1code: needs ${r1codeBin} and ${ledger}; not starting" >&2
        exit 0
      fi
      if [ -f ${r1codeEnvFile} ]; then
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
            echo "r1code: ignoring line in ${r1codeEnvFile}: $line" >&2
          fi
        done < ${r1codeEnvFile}
      fi
      : "''${R1CODE_R1HN_COMMAND:=${r1hn}/bin/r1hn acp}"
      export R1CODE_R1HN_COMMAND
      export R1CODE_HOME=${r1codeHome}
      if [ -z "''${R1CODE_R1HN_GROUPS:-}" ]; then
        R1CODE_R1HN_GROUPS=$(${r1hn}/bin/r1hn group list --json \
          | jq -r '[.groups[] | select(.accounts | length > 0) | .name] | join(",")')
      fi
      if [ -z "$R1CODE_R1HN_GROUPS" ]; then
        echo "r1code: the ledger has no group with an account; not starting" >&2
        exit 0
      fi
      export R1CODE_R1HN_GROUPS
      echo "r1code: groups $R1CODE_R1HN_GROUPS" >&2
      exec ${node}/bin/node ${r1codeBin} serve
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
    role = lib.mkOption {
      type = lib.types.enum [
        "primary"
        "coding"
      ];
      default = "coding";
      description = ''
        `[worker] role` of r1hnd. Exactly one host is "primary": it writes the
        synced vault (Times and tasks watcher, ids, reply callouts), keeps the
        assistant and runs the jobs. A "coding" host runs sessions only.
      '';
    };
  };

  config = lib.mkMerge [
    {
      dotfiles.r1hn.enable = true;

      home.packages = [
        r1codeBuild
        r1codeCli
      ]
      ++ lib.optionals isDarwin [ r1codeDesktopBuild ]
      # dsh for the sessions r1hnd runs on dsh; macOS gets it from packages.nix.
      ++ lib.optionals isLinux [ pkgs.deepseek-harness ];

      # Before the units restart, so r1hnd starts with the merged file. A new
      # file is made owner-only first (the merge keeps an existing mode).
      home.activation.r1hnSettings =
        lib.hm.dag.entryBetween [ "reloadSystemd" "setupLaunchAgents" ] [ "writeBoundary" ]
          (
            ''
              if [ ! -e ${lib.escapeShellArg configToml} ]; then
                run ${pkgs.coreutils}/bin/install -d -m 700 ${lib.escapeShellArg (dirOf configToml)}
                run ${pkgs.coreutils}/bin/install -m 600 /dev/null ${lib.escapeShellArg configToml}
              fi
            ''
            + merge {
              format = "toml";
              target = configToml;
              name = "r1hn-settings";
              fragment = settingsFragment;
            }
          );
    }

    (lib.mkIf isLinux {
      systemd.user.services = {
        r1hnd = {
          Unit = {
            Description = "r1hn endpoint (r1hnd)";
            ConditionPathExists = [ ledger ];
            # r1hnd reads config.toml at start: restart it when the merged
            # keys change.
            X-Restart-Triggers = [ "${settingsFile}" ];
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

        # `r1code serve` listens on loopback; `R1CODE_LAN=true` or Tailscale
        # Serve makes it reachable.
        r1code = {
          Unit = {
            Description = "r1 code server with the r1hn gateway";
            ConditionPathExists = [
              r1codeBin
              ledger
            ];
            Wants = [ "r1hnd.service" ];
            After = [ "r1hnd.service" ];
            StartLimitIntervalSec = 300;
            StartLimitBurst = 5;
          };
          Service = {
            ExecStart = "${r1codeStart}/bin/r1code-start";
            WorkingDirectory = home;
            Environment = [ "PATH=${r1codePath}" ];
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

      # The desktop app would otherwise start its own server in the home the
      # r1code service owns. With the local environment off it only connects
      # to environments added by pairing (r1code here and on homelab). Kept off on every activation;
      # the files are merged so the apps' other settings stay.
      home.activation.desktopClientOnly = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        for settings in ${lib.escapeShellArgs desktopSettings}; do
          current='{}'
          if [ -s "$settings" ]; then
            current=$(${pkgs.jq}/bin/jq -c . "$settings") || current=""
          fi
          if [ -z "$current" ]; then
            warnEcho "desktop: $settings is not JSON; set localEnvironmentEnabled to false by hand"
          elif [ "$(${pkgs.jq}/bin/jq -r '.localEnvironmentEnabled' <<<"$current")" != false ]; then
            run ${pkgs.coreutils}/bin/install -d -m 700 "$(dirname "$settings")"
            if [ -z "''${DRY_RUN:-}" ]; then
              ${pkgs.jq}/bin/jq '.localEnvironmentEnabled = false' <<<"$current" > "$settings.tmp"
              mv "$settings.tmp" "$settings"
            fi
          fi
        done
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

        r1code = {
          enable = true;
          config = {
            Label = launchdLabel "r1code";
            ProgramArguments = [ "${r1codeStart}/bin/r1code-start" ];
            RunAtLoad = true;
            KeepAlive.SuccessfulExit = false;
            ThrottleInterval = 10;
            ProcessType = "Standard";
            WorkingDirectory = home;
            EnvironmentVariables.PATH = r1codePath;
            StandardOutPath = "${logDir}/r1code.log";
            StandardErrorPath = "${logDir}/r1code.log";
          };
        };
      };
    })
  ];
}
