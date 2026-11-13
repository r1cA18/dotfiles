{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
# r1hnd (`r1hn serve`) and a T3 Code server that reaches agents only through
# `r1hn acp`, as systemd user services. Imported by hosts that serve other
# devices (homelab). Both units are installed and enabled, but each starts only
# once its inputs exist, so applying this before any login is harmless:
#
# - r1hnd needs the ledger `~/.config/r1hn/accounts.toml`
# - t3-r1hn needs a build made by `t3-r1hn-build` and the ledger
#
# A Condition is checked when a unit starts, so after creating either file run
# `systemctl --user start r1hnd t3-r1hn` once; later boots start them by
# themselves. Logs: `journalctl --user -u r1hnd` and `-u t3-r1hn`.
let
  cfg = config.dotfiles.r1hn.serve;
  r1hn = inputs.r1hn.packages.${pkgs.stdenv.hostPlatform.system}.r1hn;
  node = pkgs.nodejs_26;
  home = config.home.homeDirectory;
  # The build `t3-r1hn-build` points this at; the service runs it.
  t3Root = "${config.xdg.dataHome}/t3-r1hn";
  t3Bin = "${t3Root}/current/apps/server/dist/bin.mjs";
  ledger = "${config.xdg.configHome}/r1hn/accounts.toml";

  # Official clients (claude, codex, agy) live in ~/.local/bin and Nix
  # profiles. r1hn hands this PATH to the clients it starts.
  clientPath = lib.concatStringsSep ":" [
    "${home}/.local/bin"
    "${home}/.nix-profile/bin"
    "/nix/var/nix/profiles/default/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
  ];
  # T3 Code itself needs git and a shell for its terminals, not the clients.
  t3Path = lib.concatStringsSep ":" [
    "${pkgs.git}/bin"
    "${home}/.nix-profile/bin"
    "/nix/var/nix/profiles/default/bin"
    "/usr/bin"
    "/bin"
  ];

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
      echo "restart with: systemctl --user restart t3-r1hn"
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
in
{
  options.dotfiles.r1hn.serve = {
    listen = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:7790";
      description = "Loopback address of r1hnd. Publish it to the tailnet with `tailscale serve` by hand.";
    };
    t3Groups = lib.mkOption {
      type = lib.types.str;
      default = "personal";
      description = ''
        Comma-separated r1hn groups T3 Code offers. Group names stay out of this
        repository: set T3CODE_R1HN_GROUPS in ~/.config/t3-r1hn/env instead.
      '';
    };
  };

  config = {
    dotfiles.r1hn.enable = true;

    home.packages = [
      t3Build
      t3Cli
    ];

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
          ExecStart = "${node}/bin/node ${t3Bin} serve";
          WorkingDirectory = home;
          Environment = [
            "PATH=${t3Path}"
            "T3CODE_R1HN_COMMAND=${r1hn}/bin/r1hn acp"
            "T3CODE_R1HN_GROUPS=${cfg.t3Groups}"
          ];
          # Optional: T3CODE_R1HN_GROUPS, T3CODE_LAN, T3CODE_PORT.
          EnvironmentFile = [ "-${config.xdg.configHome}/t3-r1hn/env" ];
          KillMode = "mixed";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
  };
}
