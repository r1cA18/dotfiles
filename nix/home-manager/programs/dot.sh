# shellcheck shell=bash disable=SC2154 # dot_kind and dot_target come from dot.nix
# dot: single entry point for dotfiles operations.
# dot.nix prepends dot_kind (darwin or home) and dot_target (the nix-darwin
# host name or the Home Manager configuration name) before this text.

flake="${DOTFILES_DIR:-$HOME/dotfiles}"

usage() {
  cat <<'EOF'
Usage: dot <command> [args]

  apply             Build and activate this host's configuration
  build             Build this host's configuration without activating it
  rollback          Switch back to the previous generation (macOS only)
  generations       List generations
  update [stage]... Update flake inputs, native tools and Homebrew
  search <query>    Search nixpkgs
  clean             Delete old generations and unused store paths
  fmt               Format the dotfiles repository
  server <action>   Run a homelab server workflow (Linux only)
  help              Show this list

Run "dot update help" to list the update stages.
EOF
}

brew_bin() {
  if command -v brew >/dev/null 2>&1; then
    brew "$@"
  else
    /opt/homebrew/bin/brew "$@"
  fi
}

update_stages() {
  echo flake github-apps claude-code codex antigravity
  if [ "$dot_kind" = darwin ]; then
    echo brew
  fi
}

# r1hn is pinned to a commit of a private repository. Leaving it out keeps the
# stage working on hosts that cannot fetch it; bump its rev in flake.nix instead.
update_flake() {
  local -a inputs
  mapfile -t inputs < <(jq -r '.nodes.root.inputs | keys[] | select(. != "r1hn")' "$flake/flake.lock")
  nix flake update --flake "$flake" "${inputs[@]}"
}

run_update_stage() {
  case "$1" in
  flake) update_flake ;;
  brew) brew_bin update && brew_bin upgrade ;;
  *) "dot-update-$1" ;;
  esac
}

cmd_update() {
  local all stage known status=0
  local -a stages=() results=()
  all=$(update_stages | tr '\n' ' ')

  if [ "${1-}" = help ]; then
    echo "Usage: dot update [stage]..."
    echo "Stages (all run in this order when none is given): $all"
    return 0
  fi

  if [ "$#" -eq 0 ]; then
    read -r -a stages <<<"$all"
  else
    for stage in "$@"; do
      known=0
      for candidate in $all; do
        if [ "$stage" = "$candidate" ]; then
          known=1
        fi
      done
      if [ "$known" = 0 ]; then
        echo "dot update: unknown stage: $stage (available: $all)" >&2
        return 64
      fi
      stages+=("$stage")
    done
  fi

  # A failed stage is recorded and the remaining stages still run.
  for stage in "${stages[@]}"; do
    printf '\n==> dot update: %s\n' "$stage"
    if run_update_stage "$stage"; then
      results+=("ok      $stage")
    else
      results+=("FAILED  $stage")
      status=1
    fi
  done

  printf '\n==> dot update: summary\n'
  printf '  %s\n' "${results[@]}"
  if [ "$status" = 0 ]; then
    echo "Review 'git diff' in $flake, then run: dot apply"
  fi
  return "$status"
}

cmd_server() {
  local action="${1-}"
  case "$action" in
  apply | restore | start | stop | rdp-setup | doctor) ;;
  *)
    echo "usage: dot server <apply|restore|start|stop|rdp-setup|doctor>" >&2
    return 64
    ;;
  esac
  shift
  nix run "$flake#server-$action" -- "$@"
}

command="${1-help}"
if [ "$#" -gt 0 ]; then
  shift
fi

case "$command" in
apply)
  if [ "$dot_kind" = darwin ]; then
    nh darwin switch "$flake" -H "$dot_target" "$@"
  else
    nh home switch "$flake" -c "$dot_target" "$@"
  fi
  ;;
build)
  if [ "$dot_kind" = darwin ]; then
    nh darwin build "$flake" -H "$dot_target" "$@"
  else
    nh home build "$flake" -c "$dot_target" "$@"
  fi
  ;;
rollback)
  if [ "$dot_kind" = darwin ]; then
    sudo "$(command -v darwin-rebuild)" switch --rollback
  else
    echo "dot rollback: supported on macOS only; use 'dot generations' and activate one manually" >&2
    exit 1
  fi
  ;;
generations)
  if [ "$dot_kind" = darwin ]; then
    darwin-rebuild --list-generations
  else
    home-manager generations
  fi
  ;;
update) cmd_update "$@" ;;
search) nix search nixpkgs "$@" ;;
clean) nh clean all --keep-since 14d --keep 5 "$@" ;;
fmt) nix run "$flake#fmt" -- "$@" ;;
server) cmd_server "$@" ;;
help | -h | --help) usage ;;
*)
  echo "dot: unknown command: $command" >&2
  usage >&2
  exit 64
  ;;
esac
