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
check 'Google Chrome desktop app' command -v google-chrome
check 'ChatGPT desktop app' command -v chatgpt
check '1Password desktop app' command -v 1password
check 'Syncthing user service' systemctl --user is-active syncthing
check 'Homelab Compose service' systemctl is-enabled homelab-compose.service
# shellcheck disable=SC2016
check 'Home Assistant container' bash -c \
  'test "$(docker inspect --format "{{.State.Running}}" homeassistant 2>/dev/null)" = true'
# shellcheck disable=SC2016
check 'ESPHome container' bash -c \
  'test "$(docker inspect --format "{{.State.Running}}" esphome 2>/dev/null)" = true'
check 'Home Assistant runtime data' test -d \
  "$HOME/Develop/github.com/r1cA18/home-assistant/config/.storage"

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
