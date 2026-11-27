{
  config,
  lib,
  pkgs,
  ...
}:
# Pull the encrypted r1-chat server backups onto this Mac.
# The server writes age-encrypted backups (deploy/bin/backup in the r1-chat repo); the
# private key lives only here, in ~/.config/r1-chat/backup-key. Host and paths are not
# in this public repo: they come from ~/.config/r1-chat/backup-pull.env, for example
#   R1CHAT_BACKUP_HOST=<ssh host alias>
#   R1CHAT_BACKUP_DEPLOY=<path of the deploy directory on that host>
#   R1CHAT_BACKUP_DEST=$HOME/Backups/r1-chat   (optional)
#   R1CHAT_BACKUP_KEEP_LOCAL=30                (optional)
# Run `r1-chat-backup-pull` by hand, or let the LaunchAgent run it daily.
let
  serviceName = "r1-chat-backup-pull";
  launchdLabel = "com.r1ca18.${serviceName}";
  stateDir = "${config.home.homeDirectory}/.local/state/${serviceName}";

  pull = pkgs.writeShellApplication {
    name = serviceName;
    runtimeInputs = [
      pkgs.age
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnutar
      pkgs.rsync
    ];
    text = ''
      env_file="$HOME/.config/r1-chat/backup-pull.env"
      key="$HOME/.config/r1-chat/backup-key"
      if [ ! -f "$env_file" ]; then
        echo "r1-chat-backup-pull: $env_file is missing; nothing to do" >&2
        exit 0
      fi
      # shellcheck disable=SC1090
      . "$env_file"
      host=''${R1CHAT_BACKUP_HOST:?set R1CHAT_BACKUP_HOST in $env_file}
      deploy=''${R1CHAT_BACKUP_DEPLOY:?set R1CHAT_BACKUP_DEPLOY in $env_file}
      dest=''${R1CHAT_BACKUP_DEST:-$HOME/Backups/r1-chat}
      keep=''${R1CHAT_BACKUP_KEEP_LOCAL:-30}
      if [ ! -f "$key" ]; then
        echo "r1-chat-backup-pull: no private key at $key" >&2
        exit 1
      fi

      umask 077
      install -d -m 700 "$dest"

      # A new backup on the server, then every encrypted backup it keeps. ssh is the
      # system one (macOS ssh config options and the SSH agent).
      # shellcheck disable=SC2029 # the path is meant to expand on this side
      ssh -o BatchMode=yes "$host" "cd '$deploy' && bin/backup" >/dev/null
      rsync -a --chmod=F600 "$host:$deploy/backups/" "$dest/" --include='*.tar.age' --exclude='*'

      # The newest one must decrypt and list as a tar archive.
      newest=$(find "$dest" -maxdepth 1 -name '*.tar.age' | sort | tail -n 1)
      if [ -z "$newest" ]; then
        echo "r1-chat-backup-pull: no backup in $dest" >&2
        exit 1
      fi
      entries=$(age -d -i "$key" "$newest" | tar -tf - | wc -l)
      echo "r1-chat-backup-pull: $newest decrypts ($entries entries)"

      mapfile -t old < <(find "$dest" -maxdepth 1 -name '*.tar.age' | sort | head -n "-$keep")
      for file in "''${old[@]}"; do
        rm -f "$file"
      done
    '';
  };
in
lib.mkIf pkgs.stdenv.isDarwin {
  home.packages = [ pull ];

  home.activation.prepareR1ChatBackupPullState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.coreutils}/bin/install -d -m 700 "${stateDir}"
  '';

  launchd.agents.${serviceName} = {
    enable = true;
    config = {
      Label = launchdLabel;
      ProgramArguments = [ (lib.getExe pull) ];
      ProcessType = "Background";
      RunAtLoad = false;
      StartCalendarInterval = [
        {
          Hour = 4;
          Minute = 30;
        }
      ];
      StandardErrorPath = "${stateDir}/service.log";
      StandardOutPath = "${stateDir}/service.log";
    };
  };
}
