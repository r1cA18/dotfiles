{ config, pkgs, ... }:
let
  # The vault syncs through Syncthing (.git is ignored there, see
  # programs/syncthing.nix); only homelab commits it, once a night.
  # Signing follows the global git config (1Password SSH signing). It is never
  # disabled here: when signing cannot work headless the unit fails loudly.
  vaultCommit = pkgs.writeShellApplication {
    name = "vault-commit";
    runtimeInputs = [
      pkgs.git
      pkgs.openssh
      pkgs.coreutils
    ];
    text = ''
      vault="$HOME/vault"
      logdir="$HOME/.local/state/vault-commit"
      mkdir -p "$logdir"
      log() { printf '%s %s\n' "$(date -Is)" "$*" | tee -a "$logdir/vault-commit.log" >&2; }

      cd "$vault"
      if [ "$(git branch --show-current)" != main ]; then
        log "FAIL: vault is not on main; nothing done"
        exit 1
      fi

      # Bring in remote commits first. Never force: on any conflict stop.
      if ! git pull --rebase --autostash origin main >>"$logdir/vault-commit.log" 2>&1; then
        git rebase --abort >/dev/null 2>&1 || true
        log "FAIL: pull --rebase --autostash did not apply cleanly; stopped, nothing pushed"
        exit 1
      fi

      if [ -z "$(git status --porcelain)" ]; then
        log "no changes"
        exit 0
      fi

      git add -A
      day=$(TZ=Asia/Tokyo date +%F)
      if ! git commit -m "chore(vault): nightly snapshot $day" >>"$logdir/vault-commit.log" 2>&1; then
        log "FAIL: git commit failed (signing unavailable headless? see log); changes left uncommitted"
        exit 1
      fi
      if ! git push origin main >>"$logdir/vault-commit.log" 2>&1; then
        log "FAIL: git push failed; the commit stays local"
        exit 1
      fi
      log "committed and pushed nightly snapshot $day"
    '';
  };
in
{
  systemd.user = {
    services.vault-commit = {
      Unit.Description = "Nightly vault git snapshot";
      Service = {
        Type = "oneshot";
        ExecStart = "${vaultCommit}/bin/vault-commit";
        # 1Password SSH agent for signing and push.
        Environment = [ "SSH_AUTH_SOCK=${config.home.homeDirectory}/.1password/agent.sock" ];
        Nice = 10;
      };
    };

    timers.vault-commit = {
      Unit.Description = "Nightly vault git snapshot at 03:30 Asia/Tokyo";
      Timer = {
        OnCalendar = "*-*-* 03:30:00 Asia/Tokyo";
        Persistent = true;
        Unit = "vault-commit.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
