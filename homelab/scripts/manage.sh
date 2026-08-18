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

read_env_value() {
  local env_file="$1"
  local wanted_key="$2"

  awk -v wanted_key="$wanted_key" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    {
      line = $0
      sub(/^[[:space:]]*export[[:space:]]+/, "", line)
      separator = index(line, "=")
      if (separator == 0) next
      key = substr(line, 1, separator - 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      if (key != wanted_key) next
      value = substr(line, separator + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      first = substr(value, 1, 1)
      last = substr(value, length(value), 1)
      if ((first == "\"" && last == "\"") || (first == "\047" && last == "\047")) {
        value = substr(value, 2, length(value) - 2)
      }
      print value
      exit
    }
  ' "$env_file"
}

require_env_keys() {
  local env_file="$1"
  shift
  local key value
  local missing=0

  [[ -f $env_file ]] || {
    printf 'missing environment file: %s\n' "$env_file" >&2
    return 1
  }

  for key in "$@"; do
    value="$(read_env_value "$env_file" "$key")"
    if [[ -z $value ]]; then
      printf 'missing or empty key: %s\n' "$key" >&2
      missing=1
    fi
  done

  ((missing == 0))
}

require_unit() {
  local unit="$1"

  systemctl cat "$unit" >/dev/null || {
    printf '%s is not installed; run homelab-apply first\n' "$unit" >&2
    return 1
  }
}

wait_for_http() {
  local description="$1"
  local url="$2"
  local attempts="$3"
  local delay="$4"
  local attempt

  for ((attempt = 1; attempt <= attempts; attempt++)); do
    if curl -fsS --max-time 10 "$url" >/dev/null; then
      printf '%s is healthy\n' "$description"
      return 0
    fi
    sleep "$delay"
  done

  printf '%s did not become healthy: %s\n' "$description" "$url" >&2
  return 1
}

wait_for_unit() {
  local unit="$1"
  local attempts="${2:-30}"
  local attempt

  for ((attempt = 1; attempt <= attempts; attempt++)); do
    if systemctl is-active --quiet "$unit"; then
      return 0
    fi
    sleep 1
  done

  printf '%s did not become active\n' "$unit" >&2
  return 1
}

run_playbook() {
  local ansible_playbook

  ansible_playbook="$(command -v ansible-playbook)"
  sudo /usr/bin/env \
    "ANSIBLE_CONFIG=$dotfiles_root/homelab/ansible/ansible.cfg" \
    "$ansible_playbook" \
    -i "$dotfiles_root/homelab/ansible/inventory.yml" \
    "$dotfiles_root/homelab/ansible/playbook.yml"
}

configure_login_shell() {
  local current_shell homelab_user zsh_path

  homelab_user="$(id -un)"
  zsh_path="$HOME/.nix-profile/bin/zsh"

  [[ -x $zsh_path ]] || {
    printf 'Home Manager did not install zsh at %s\n' "$zsh_path" >&2
    exit 1
  }

  if ! grep -qxF "$zsh_path" /etc/shells; then
    printf '%s\n' "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  fi

  current_shell="$(getent passwd "$homelab_user" | cut -d: -f7)"
  if [[ $current_shell != "$zsh_path" ]]; then
    sudo usermod --shell "$zsh_path" "$homelab_user"
  fi
}

validate_application_inputs() {
  local expected_value required_input
  local -a required_inputs=(
    docker-compose.yml
    config/.storage
    config/secrets.yaml
    config/home-assistant_v2.db
    esphome/secrets.yaml
  )

  for required_input in "${required_inputs[@]}"; do
    [[ -e "$home_assistant_root/$required_input" ]] || {
      printf 'missing %s; wait for Syncthing before starting services\n' \
        "$home_assistant_root/$required_input" >&2
      return 1
    }
  done

  docker compose -f "$home_assistant_root/docker-compose.yml" config --quiet

  require_env_keys \
    "$vault_agi_root/.env" \
    DISCORD_BOT_TOKEN \
    ALLOWED_USER_IDS \
    TIMES_CHANNEL_IDS \
    VAULT_PATH
  expected_value="$(read_env_value "$vault_agi_root/.env" VAULT_PATH)"
  [[ $(realpath -m "$expected_value") == "$HOME/vault" ]] || {
    printf 'VAULT_PATH must point to %s\n' "$HOME/vault" >&2
    return 1
  }

  require_env_keys \
    "$olympus_root/.env" \
    OLYMPUS_VAULT \
    OLYMPUS_DB \
    OLYMPUS_INTERNAL_TOKEN \
    OLYMPUS_GATEWAY_HOST \
    TAILSCALE_ONLY
  expected_value="$(read_env_value "$olympus_root/.env" OLYMPUS_VAULT)"
  [[ $(realpath -m "$expected_value") == "$HOME/vault" ]] || {
    printf 'OLYMPUS_VAULT must point to %s\n' "$HOME/vault" >&2
    return 1
  }
  [[ $(read_env_value "$olympus_root/.env" OLYMPUS_DB) == "$olympus_root/data/olympus.db" ]] || {
    printf 'OLYMPUS_DB must point inside the Olympus repository data directory\n' >&2
    return 1
  }
  [[ $(read_env_value "$olympus_root/.env" OLYMPUS_GATEWAY_HOST) == "127.0.0.1" ]] || {
    printf 'OLYMPUS_GATEWAY_HOST must be 127.0.0.1\n' >&2
    return 1
  }
  [[ $(read_env_value "$olympus_root/.env" TAILSCALE_ONLY) == "true" ]] || {
    printf 'TAILSCALE_ONLY must be true for Olympus\n' >&2
    return 1
  }
  [[ -f "$olympus_root/data/olympus.db" ]] || {
    printf 'missing Olympus database: %s\n' "$olympus_root/data/olympus.db" >&2
    return 1
  }
}

prepare_workloads() {
  local component esbuild_binary

  validate_application_inputs
  chmod 600 "$vault_agi_root/.env" "$olympus_root/.env"

  for component in gateway master discord; do
    printf 'Installing vault-agi %s dependencies\n' "$component"
    (
      cd "$vault_agi_root/$component"
      "$bun_path" install
    )
  done

  printf 'Validating and building the current Olympus working tree\n'
  (
    cd "$olympus_root"
    "$bun_path" install --frozen-lockfile

    while IFS= read -r -d '' esbuild_binary; do
      chmod u+x "$esbuild_binary"
    done < <(
      find node_modules/.bun \
        -type f \
        -path '*/@esbuild+linux-x64@*/node_modules/@esbuild/linux-x64/bin/esbuild' \
        -print0
    )

    "$bun_path" run typecheck
    "$bun_path" test
    "$bun_path" run build
  )
}

start_homelab_services() {
  local unit

  validate_application_inputs

  for unit in \
    homelab-compose.service \
    vault-agi-gateway.service \
    vault-agi-master.service \
    vault-agi-discord.service \
    olympus-gateway.service; do
    require_unit "$unit"
  done

  sudo systemctl enable --now homelab-compose.service
  wait_for_http "Home Assistant" "http://127.0.0.1:8123/" 60 5

  sudo systemctl enable --now vault-agi-gateway.service
  wait_for_http "Vault AGI gateway" "http://127.0.0.1:3000/" 30 2

  sudo systemctl enable --now vault-agi-master.service
  wait_for_unit vault-agi-master.service

  sudo systemctl enable --now vault-agi-discord.service
  wait_for_unit vault-agi-discord.service

  sudo systemctl enable --now olympus-gateway.service
  wait_for_http "Olympus gateway" "http://127.0.0.1:3100/health" 30 2
}

configure_olympus_serve() {
  local funnel_status serve_status
  local target="http://127.0.0.1:3100"

  funnel_status="$(tailscale funnel status 2>&1)" || {
    printf 'Unable to verify that Tailscale Funnel is disabled\n' >&2
    return 1
  }
  if ! grep -Fqi "(tailnet only)" <<<"$funnel_status" &&
    ! grep -Fqi "No serve config" <<<"$funnel_status"; then
    printf 'Tailscale Funnel is not confirmed disabled; refusing to configure Serve\n' >&2
    return 1
  fi

  serve_status="$(tailscale serve status 2>&1 || true)"
  if grep -Fq "$target" <<<"$serve_status"; then
    if [[ $(grep -Fc " proxy " <<<"$serve_status") -ne 1 ]]; then
      printf 'Existing Tailscale Serve configuration has additional proxies; refusing to overwrite it\n' >&2
      return 1
    fi
    printf 'Tailscale Serve already targets %s\n' "$target"
    return 0
  fi
  if ! grep -Fq "No serve config" <<<"$serve_status"; then
    printf 'Existing Tailscale Serve configuration needs manual review; refusing to overwrite it\n' >&2
    return 1
  fi

  tailscale serve --bg "$target"

  serve_status="$(tailscale serve status 2>&1)" || return 1
  grep -Fq "$target" <<<"$serve_status" || {
    printf 'Tailscale Serve did not retain target %s\n' "$target" >&2
    return 1
  }
  funnel_status="$(tailscale funnel status 2>&1)" || return 1
  grep -Fqi "(tailnet only)" <<<"$funnel_status" || {
    printf 'Tailscale Funnel state is not tailnet-only after configuring Serve\n' >&2
    return 1
  }
}

initialize_user_timers() {
  local deadline_marker="$HOME/.local/state/olympus-deadline-scheduler/enabled"
  local deadline_script="$HOME/vault/40_AI/automation/olympus-deadline-scheduler.sh"
  local times_marker="$HOME/.local/state/olympus-times-triage/enabled"
  local times_script="$HOME/vault/40_AI/automation/olympus-times-triage.sh"

  systemctl --user is-active --quiet codex-app-server.service || {
    printf 'codex-app-server.service is not active\n' >&2
    return 1
  }
  systemctl is-active --quiet vault-agi-gateway.service
  systemctl is-active --quiet vault-agi-master.service
  systemctl is-active --quiet vault-agi-discord.service
  systemctl is-active --quiet olympus-gateway.service

  if [[ ! -f $times_marker ]]; then
    "$BASH" "$times_script" --baseline
    install -D -m 600 /dev/null "$times_marker"
  fi

  if [[ ! -f $deadline_marker ]]; then
    "$BASH" "$deadline_script" --check
    install -D -m 600 /dev/null "$deadline_marker"
  fi

  systemctl --user daemon-reload
  systemctl --user enable --now \
    olympus-times-triage.timer \
    olympus-deadline-scheduler.timer
}

restore_homelab_workloads() {
  prepare_workloads
  start_homelab_services
  configure_olympus_serve
  initialize_user_timers
}

setup_remote_login() {
  systemctl cat gnome-remote-desktop.service >/dev/null || {
    printf 'GNOME Remote Desktop is not installed; run homelab-apply first\n' >&2
    exit 1
  }

  printf 'Set dedicated GNOME Remote Login credentials. Store the password in 1Password.\n'
  sudo grdctl --system rdp set-credentials
  sudo grdctl --system rdp enable
  sudo systemctl enable --now gdm.service gnome-remote-desktop.service
  sudo systemctl restart gnome-remote-desktop.service
  sudo grdctl --system status
}

command_name="${1:-}"
dotfiles_root="$(resolve_dotfiles_root)"
home_assistant_root="$HOME/Develop/github.com/r1cA18/home-assistant"
vault_agi_root="$HOME/Develop/github.com/r1cA18/vault-agi"
olympus_root="$HOME/Develop/github.com/r1cA18/olympus"
bun_path="$HOME/.nix-profile/bin/bun"

case "$command_name" in
apply)
  require_homelab_host
  run_playbook
  home-manager switch --flake "$dotfiles_root#r1ca18@homelab"
  systemctl --user restart codex-app-server.service
  configure_login_shell
  printf 'homelab applied; log out and back in to activate shell and group changes\n'
  ;;
start)
  require_homelab_host
  start_homelab_services
  configure_olympus_serve
  initialize_user_timers
  ;;
restore)
  require_homelab_host
  restore_homelab_workloads
  ;;
stop)
  require_homelab_host
  systemctl --user disable --now \
    olympus-times-triage.timer \
    olympus-deadline-scheduler.timer
  sudo systemctl disable --now \
    olympus-gateway.service \
    vault-agi-discord.service \
    vault-agi-master.service \
    vault-agi-gateway.service \
    homelab-compose.service
  ;;
rdp-setup)
  require_homelab_host
  setup_remote_login
  ;;
doctor)
  require_homelab_host
  exec bash "$dotfiles_root/homelab/scripts/doctor.sh"
  ;;
*)
  printf 'usage: homelab {apply|restore|start|stop|rdp-setup|doctor}\n' >&2
  exit 2
  ;;
esac
