{ config, pkgs, ... }:
# r1-discord, the Discord side of r1 Times, as a systemd user service next to
# r1hnd (it calls r1hnd on loopback with an adapter:discord token).
#
# - `r1-discord-build CHECKOUT` copies the committed tree of a checkout of the
#   r1-discord repository to ~/.local/share/r1-discord/<rev>, installs its
#   dependencies there and makes it the one the service runs
# - ~/.config/r1-discord/env (0600) holds the settings; `.env.example` of the
#   repository lists the keys. It is the owner's file and never in this repo
#
# The unit starts only once both exist, so applying this first is harmless.
# After writing them start it once (`systemctl --user start r1-discord`);
# later logins start it by themselves. Logs: `journalctl --user -u r1-discord`.
let
  root = "${config.xdg.dataHome}/r1-discord";
  current = "${root}/current";
  envFile = "${config.xdg.configHome}/r1-discord/env";

  build = pkgs.writeShellApplication {
    name = "r1-discord-build";
    runtimeInputs = [
      pkgs.bun
      pkgs.git
      pkgs.gnutar
      pkgs.coreutils
      pkgs.findutils
    ];
    text = ''
      src=$(cd "''${1:?usage: r1-discord-build CHECKOUT}" && pwd)
      if [ -n "$(git -C "$src" status --porcelain)" ]; then
        echo "r1-discord-build: $src has uncommitted changes" >&2
        exit 1
      fi
      rev=$(git -C "$src" rev-parse --short=12 HEAD)
      mkdir -p ${root}
      if [ ! -f ${root}/"$rev"/src/main.ts ]; then
        tmp=$(mktemp -d ${root}/.build.XXXXXX)
        git -C "$src" archive HEAD | tar -x -C "$tmp"
        (cd "$tmp" && bun install --frozen-lockfile --production)
        rm -rf ${root}/"$rev"
        mv "$tmp" ${root}/"$rev"
      fi
      ln -sfn "$rev" ${current}
      # Older builds go; building an older commit again rolls back.
      find ${root} -mindepth 1 -maxdepth 1 -type d ! -name "$rev" -exec rm -rf {} +
      echo "r1-discord-build: built $rev"
      echo "restart with: systemctl --user restart r1-discord"
    '';
  };
in
{
  home.packages = [ build ];

  systemd.user.services.r1-discord = {
    Unit = {
      Description = "r1 Times Discord adapter (r1-discord)";
      ConditionPathExists = [
        "${current}/src/main.ts"
        envFile
      ];
      Wants = [ "r1hnd.service" ];
      After = [ "r1hnd.service" ];
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
    };
    Service = {
      ExecStart = "${pkgs.bun}/bin/bun run ${current}/src/main.ts";
      WorkingDirectory = current;
      EnvironmentFile = envFile;
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
