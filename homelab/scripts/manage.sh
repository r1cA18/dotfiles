#!/usr/bin/env bash
set -euo pipefail

resolve_dotfiles_root() {
  local candidate

  for candidate in "${HOMELAB_DOTFILES_ROOT:-}" "$PWD" "$HOME/dotfiles"; do
    if [[ -n $candidate && -f "$candidate/flake.nix" && -f "$candidate/homelab/ansible/playbook.yml" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  printf 'dotfiles repository not found; run from ~/dotfiles or set HOMELAB_DOTFILES_ROOT\n' >&2
  exit 1
}

require_homelab_host() {
  local homelab_os_id homelab_os_version ID VERSION_ID

  # shellcheck source=/dev/null
  . /etc/os-release
  homelab_os_id="$ID"
  homelab_os_version="$VERSION_ID"

  [[ "$(id -un)" == "r1ca18" ]] || {
    printf 'expected user r1ca18; detected %s\n' "$(id -un)" >&2
    exit 1
  }
  [[ "$(uname -m)" == "x86_64" ]] || {
    printf 'expected x86_64; detected %s\n' "$(uname -m)" >&2
    exit 1
  }
  [[ $homelab_os_id == "ubuntu" && $homelab_os_version == "26.04" ]] || {
    printf 'expected Ubuntu 26.04; detected %s %s\n' "$homelab_os_id" "$homelab_os_version" >&2
    exit 1
  }
}

run_playbook() {
  ANSIBLE_CONFIG="$dotfiles_root/homelab/ansible/ansible.cfg" \
    ansible-playbook -K \
    -i "$dotfiles_root/homelab/ansible/inventory.yml" \
    "$dotfiles_root/homelab/ansible/playbook.yml"
}

start_homelab_services() {
  local home_assistant_root required_input
  local -a required_inputs=(
    docker-compose.yml
    config/.storage
    config/secrets.yaml
    esphome/secrets.yaml
  )

  home_assistant_root="$HOME/Develop/github.com/r1cA18/home-assistant"

  systemctl cat homelab-compose.service >/dev/null || {
    printf 'homelab-compose.service is not installed; run homelab-apply first\n' >&2
    exit 1
  }

  for required_input in "${required_inputs[@]}"; do
    [[ -e "$home_assistant_root/$required_input" ]] || {
      printf 'missing %s; wait for Syncthing before starting services\n' \
        "$home_assistant_root/$required_input" >&2
      exit 1
    }
  done

  docker compose -f "$home_assistant_root/docker-compose.yml" config --quiet
  sudo systemctl enable --now homelab-compose.service
}

command_name="${1:-}"
dotfiles_root="$(resolve_dotfiles_root)"

case "$command_name" in
apply)
  require_homelab_host
  run_playbook
  home-manager switch --flake "$dotfiles_root#r1ca18@homelab"
  ;;
start)
  require_homelab_host
  start_homelab_services
  ;;
stop)
  require_homelab_host
  sudo systemctl disable --now homelab-compose.service
  ;;
doctor)
  require_homelab_host
  exec bash "$dotfiles_root/homelab/scripts/doctor.sh"
  ;;
*)
  printf 'usage: homelab {apply|start|stop|doctor}\n' >&2
  exit 2
  ;;
esac
