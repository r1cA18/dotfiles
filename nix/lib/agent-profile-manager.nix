{ lib }:

{
  productName,
  profileStatePath,
  primaryConfigPath,
  primaryMetadataPath,
  profileMetadataName,
  sharedPaths,
}:
''
  product_name=${lib.escapeShellArg productName}
  profile_root="''${XDG_STATE_HOME:-$HOME/.local/state}/${profileStatePath}"
  primary_config_dir="$HOME/${primaryConfigPath}"
  primary_metadata_file="$HOME/${primaryMetadataPath}"
  profile_metadata_name=${lib.escapeShellArg profileMetadataName}
  shared_paths=(
    ${lib.concatMapStringsSep "\n    " lib.escapeShellArg sharedPaths}
  )

  list_profiles() {
    local dir email name

    printf 'PROFILE\tEMAIL\tPATH\n'
    email="$(profile_email "$primary_metadata_file")"
    printf 'default\t%s\t%s\n' "''${email:--}" "$primary_config_dir"

    shopt -s nullglob
    for dir in "$profile_root"/*; do
      [[ -d "$dir" ]] || continue
      name="''${dir##*/}"
      email="$(profile_email "$dir/$profile_metadata_name")"
      printf '%s\t%s\t%s\n' "$name" "''${email:--}" "$dir"
    done
  }

  completion_profiles() {
    local name email path selector

    while IFS=$'\t' read -r name email path; do
      [[ "$name" == "PROFILE" ]] && continue
      selector="$email"
      [[ "$selector" == "-" ]] && selector="$name"
      printf '%s:%s\n' "$selector" "$name"
    done < <(list_profiles)
  }

  pick_profile() {
    local selected name email path

    selected="$(
      list_profiles \
        | tail -n +2 \
        | fzf \
            --delimiter=$'\t' \
            --with-nth=1,2 \
            --reverse \
            --height=40% \
            --prompt="$product_name profile> "
    )" || return 1

    IFS=$'\t' read -r name email path <<< "$selected"
    if [[ "$email" == "-" ]]; then
      printf '%s\n' "$name"
    else
      printf '%s\n' "$email"
    fi
  }

  select_profile() {
    local requested="''${1:-}"

    if [[ -n "$requested" ]]; then
      printf '%s\n' "$requested"
    else
      pick_profile
    fi
  }

  resolve_profile() {
    local requested="$1"
    local dir email name primary_email

    if [[ "$requested" == "default" ]]; then
      printf '\n'
      return 0
    fi

    primary_email="$(profile_email "$primary_metadata_file")"
    if [[ -n "$primary_email" && "$requested" == "$primary_email" ]]; then
      printf '\n'
      return 0
    fi

    shopt -s nullglob
    for dir in "$profile_root"/*; do
      [[ -d "$dir" ]] || continue
      name="''${dir##*/}"
      email="$(profile_email "$dir/$profile_metadata_name")"
      if [[ "$requested" == "$name" || ( -n "$email" && "$requested" == "$email" ) ]]; then
        printf '%s\n' "$dir"
        return 0
      fi
    done

    echo "Unknown $product_name profile: $requested" >&2
    echo "Run '$profile_command list' to show available profiles." >&2
    return 1
  }

  ensure_shared_config() {
    local config_dir="$1"
    local path source target

    [[ -n "$config_dir" ]] || return 0
    install -d -m 700 "$config_dir"

    for path in "''${shared_paths[@]}"; do
      source="$primary_config_dir/$path"
      target="$config_dir/$path"
      [[ -e "$source" || -L "$source" ]] || continue

      if [[ -e "$target" && ! -L "$target" ]]; then
        echo "Refusing to replace profile-local path: $target" >&2
        return 1
      fi
      ln -sfn "$source" "$target"
    done
  }

  validate_profile_email() {
    local email="$1"

    if [[ ! "$email" =~ ^[^/@[:space:]]+@[^/@[:space:]]+\.[^/@[:space:]]+$ ]]; then
      echo "A valid email address is required." >&2
      return 2
    fi
  }
''
