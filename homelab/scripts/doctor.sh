#!/usr/bin/env bash
set -u

failed=0

check() {
  local description="$1"
  shift

  if "$@" >/dev/null 2>&1; then
    printf 'ok   %s\n' "$description"
  else
    printf 'fail %s\n' "$description"
    failed=1
  fi
}

printf 'host: %s\n' "$(hostname)"
# shellcheck source=/dev/null
. /etc/os-release
printf 'os:   %s\n' "$PRETTY_NAME"
printf 'arch: %s\n' "$(uname -m)"
printf 'ip:   %s\n' "$(hostname -I 2>/dev/null || true)"

check 'Login shell' test \
  "$(getent passwd "$(id -un)" | cut -d: -f7)" = "$HOME/.nix-profile/bin/zsh"
check 'Nix daemon' systemctl is-active nix-daemon
check 'Docker daemon' systemctl is-active docker
check 'Tailscale daemon' systemctl is-active tailscaled
check 'SSH server' systemctl is-active ssh
check 'GNOME remote login service' systemctl is-active gnome-remote-desktop
check 'Bluetooth daemon' systemctl is-active bluetooth
check 'UFW firewall' systemctl is-enabled ufw
check 'IPv4 forwarding' test "$(sysctl -n net.ipv4.ip_forward 2>/dev/null)" = 1
check 'IPv6 forwarding' test "$(sysctl -n net.ipv6.conf.all.forwarding 2>/dev/null)" = 1
check 'Inotify watch capacity' test \
  "$(sysctl -n fs.inotify.max_user_watches 2>/dev/null)" -ge 524288
check 'Inotify instance capacity' test \
  "$(sysctl -n fs.inotify.max_user_instances 2>/dev/null)" -ge 1024
check 'Google Chrome desktop app' command -v google-chrome
check 'ChatGPT desktop app' command -v chatgpt
check '1Password desktop app' command -v 1password
check 'Syncthing user service' systemctl --user is-active syncthing
check 'Homelab Compose service' systemctl is-enabled homelab-compose.service
check 'Homelab Compose active' systemctl is-active homelab-compose.service
# shellcheck disable=SC2016
check 'Home Assistant container' bash -c \
  'test "$(docker inspect --format "{{.State.Running}}" homeassistant 2>/dev/null)" = true'
# shellcheck disable=SC2016
check 'ESPHome container' bash -c \
  'test "$(docker inspect --format "{{.State.Running}}" esphome 2>/dev/null)" = true'
check 'Home Assistant runtime data' test -d \
  "$HOME/Develop/github.com/r1cA18/home-assistant/config/.storage"
check 'Home Assistant health' curl -fsS --max-time 10 http://127.0.0.1:8123/
check 'Home Assistant sync permission timer enabled' \
  systemctl is-enabled home-assistant-sync-permissions.timer
check 'Home Assistant sync permission timer active' \
  systemctl is-active home-assistant-sync-permissions.timer
# shellcheck disable=SC2016
check 'Home Assistant runtime data readable by Syncthing' bash -c '
  unreadable=$(
    find "$HOME/Develop/github.com/r1cA18/home-assistant/config/.storage" \
      -type f ! -readable -print -quit
  )
  test -z "$unreadable"
'

for service in \
  vault-agi-gateway.service \
  vault-agi-master.service \
  vault-agi-discord.service \
  olympus-gateway.service; do
  check "$service enabled" systemctl is-enabled "$service"
  check "$service active" systemctl is-active "$service"
done

check 'Vault AGI gateway health' curl -fsS --max-time 10 http://127.0.0.1:3000/
check 'Olympus gateway health' curl -fsS --max-time 10 http://127.0.0.1:3100/health
# shellcheck disable=SC2016
check 'Olympus loopback-only bind' bash -c '
  /usr/bin/ss -ltn | /usr/bin/awk '\''
    $4 ~ /127[.]0[.]0[.]1:3100$/ { found = 1 }
    $4 ~ /0[.]0[.]0[.]0:3100$/ || $4 ~ /\[::\]:3100$/ { bad = 1 }
    END { exit !(found && !bad) }
  '\''
'
check 'Tailscale Serve target' bash -c '
  /usr/bin/tailscale serve status 2>/dev/null |
    /usr/bin/grep -Fq "http://127.0.0.1:3100"
'
# shellcheck disable=SC2016
check 'Tailscale Funnel disabled' bash -c '
  status=$(/usr/bin/tailscale funnel status 2>/dev/null) || exit 1
  /usr/bin/grep -Fqi "(tailnet only)" <<<"$status" ||
    /usr/bin/grep -Fqi "No serve config" <<<"$status"
'

check 'Codex app server enabled' systemctl --user is-enabled codex-app-server.service
check 'Codex app server active' systemctl --user is-active codex-app-server.service
check 'Olympus MCP registered' "$HOME/.nix-profile/bin/codex" mcp get olympus
for timer in olympus-times-triage.timer olympus-deadline-scheduler.timer; do
  check "$timer enabled" systemctl --user is-enabled "$timer"
  check "$timer active" systemctl --user is-active "$timer"
done
check 'Times triage check' \
  "$BASH" "$HOME/vault/40_AI/automation/olympus-times-triage.sh" --check
check 'Deadline scheduler check' \
  "$BASH" "$HOME/vault/40_AI/automation/olympus-deadline-scheduler.sh" --check

check 'vault-agi .env mode' test \
  "$(stat -c %a "$HOME/Develop/github.com/r1cA18/vault-agi/.env")" = 600
check 'Olympus .env mode' test \
  "$(stat -c %a "$HOME/Develop/github.com/r1cA18/olympus/.env")" = 600
check 'Olympus database' test -f \
  "$HOME/Develop/github.com/r1cA18/olympus/data/olympus.db"

# shellcheck disable=SC2016
check 'Only declared containers running' bash -c '
  unexpected=$(
    docker ps --format "{{.Names}}" |
      grep -Ev "^(homeassistant|esphome)$" || true
  )
  test -z "$unexpected"
'

printf '\nTailscale:\n'
tailscale status 2>/dev/null || true

printf '\nHome Assistant:\n'
docker compose \
  -f "$HOME/Develop/github.com/r1cA18/home-assistant/docker-compose.yml" \
  ps 2>/dev/null || true

printf '\nPersistent serial devices:\n'
ls -l /dev/serial/by-id 2>/dev/null || printf '(none)\n'

printf '\nBluetooth adapters:\n'
bluetoothctl list 2>/dev/null || printf '(none)\n'

printf '\nSyncthing device ID:\n'
syncthing device-id 2>/dev/null || printf '(not initialized)\n'

exit "$failed"
