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
  storage [host]    Show disk usage of the main storage consumers
  worktrees         List stale linked Git worktrees (--days N, --remove)
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

develop_root() {
  local root
  root=$(git config --global ghq.root 2>/dev/null || true)
  root=${root:-$HOME/Develop}
  echo "${root/#\~/$HOME}"
}

# Disk usage of the main storage consumers on this host. With a host name the
# same report runs there over SSH.
cmd_storage() {
  if [ "$#" -gt 0 ]; then
    # shellcheck disable=SC2029 # dot is resolved on the remote host
    ssh "$1" 'PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:$PATH" dot storage'
    return
  fi
  local root stversions_kib limit_gib=10 path
  root=$(develop_root)
  df -h "$HOME"
  echo
  for path in "$root" "$root/.stversions" "$HOME/Workspaces" \
    "$HOME/Library/Developer/Xcode/DerivedData" "$HOME/Library/Developer/Xcode/iOS DeviceSupport" \
    "$HOME/Library/Developer/CoreSimulator" "$HOME/Library/Caches" "$HOME/Library/pnpm" \
    "$HOME/.local/share/pnpm" "$HOME/.cache" "$HOME/.cargo" "$HOME/.rustup" "$HOME/.bun" "$HOME/.npm"; do
    [ -d "$path" ] && du -xsh "$path" 2>/dev/null
  done
  if [ -d "$root/.stversions" ]; then
    stversions_kib=$(du -xsk "$root/.stversions" | cut -f1)
    if [ "$stversions_kib" -gt $((limit_gib * 1024 * 1024)) ]; then
      echo
      echo "warning: $root/.stversions is over ${limit_gib}GiB; Syncthing keeps replaced files there (see docs/guides/developer-cleanup.md)" >&2
    fi
  fi
  if [ -f "$HOME/.local/state/developer-cleanup/daily-summary.json" ]; then
    echo
    echo "developer-cleanup (last daily run):"
    jq -r '"  started \(.started_at | todate)  candidates \(.candidates)  cleaned \(.cleaned)  failures \(.failures)"' \
      "$HOME/.local/state/developer-cleanup/daily-summary.json"
  fi
}

# Linked worktrees that are safe to remove: clean, no ignored files other than
# build output, every commit on a remote, and untouched for N days. Removal
# asks for each one and never deletes branches.
cmd_worktrees() {
  local remove=0 days=14 root repo common path locked branch index age size extra answer
  local -a mains=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
    --remove) remove=1 ;;
    --days)
      days=$2
      shift
      ;;
    *)
      echo "usage: dot worktrees [--days N] [--remove]" >&2
      return 64
      ;;
    esac
    shift
  done
  root=$(develop_root)
  export GIT_OPTIONAL_LOCKS=0
  while IFS= read -r repo; do
    mains+=("${repo%/.git}")
  done < <(find "$root" -mindepth 2 -maxdepth 6 \( -name node_modules -o -name .stversions -o -name target \) -prune -o -type d -name .git -print 2>/dev/null)
  for repo in "${mains[@]}"; do
    common=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || continue
    [ "$common" = "$repo/.git" ] || continue
    while IFS=$'\t' read -r path locked; do
      [ "$path" != "$repo" ] && [ "$locked" = 0 ] && [ -d "$path" ] || continue
      [ -z "$(git -C "$path" status --porcelain --untracked-files=normal 2>/dev/null)" ] || continue
      [ "$(git -C "$path" rev-list --count HEAD --not --remotes 2>/dev/null)" = 0 ] || continue
      extra=$(git -C "$path" ls-files --others --ignored --exclude-standard --directory 2>/dev/null |
        grep -Ev '^(target|node_modules|\.venv|\.next|\.build|DerivedData|\.direnv|result)/?$' || true)
      [ -z "$extra" ] || continue
      # The HEAD reflog changes on commit and checkout; scanners rewrite the index.
      index=$(git -C "$path" rev-parse --path-format=absolute --git-path logs/HEAD)
      [ -e "$index" ] || index=$(git -C "$path" rev-parse --path-format=absolute --git-path index)
      age=$((($(date +%s) - $(stat -c %Y "$index")) / 86400))
      [ "$age" -ge "$days" ] || continue
      branch=$(git -C "$path" branch --show-current)
      size=$(du -xsh "$path" | cut -f1)
      printf '%s\t%s\t%sd\t%s\n' "$size" "$path" "$age" "${branch:-detached}"
      if [ "$remove" = 1 ]; then
        read -r -p "Remove worktree $path (branch kept)? [y/N] " answer </dev/tty
        if [ "$answer" = y ]; then
          git -C "$repo" worktree remove "$path"
        fi
      fi
    done < <(git -C "$repo" worktree list --porcelain |
      awk '/^worktree /{p=substr($0,10); l=0} /^locked/{l=1} /^$/{print p"\t"l; p=""} END{if(p!="")print p"\t"l}')
  done
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
storage) cmd_storage "$@" ;;
worktrees) cmd_worktrees "$@" ;;
fmt) nix run "$flake#fmt" -- "$@" ;;
server) cmd_server "$@" ;;
help | -h | --help) usage ;;
*)
  echo "dot: unknown command: $command" >&2
  usage >&2
  exit 64
  ;;
esac
