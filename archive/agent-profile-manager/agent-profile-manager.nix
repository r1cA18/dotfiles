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
  profile_trash_root="''${profile_root%/*}/trash"
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

  verify_profile_identity() {
    local config_dir="$1"
    local require_login="''${2:-false}"
    local expected actual metadata_file

    # The primary profile has no stable local pledge. Additional profile
    # directory names are validated email addresses and therefore are the
    # expected account identity.
    [[ -n "$config_dir" ]] || return 0

    expected="''${config_dir##*/}"
    metadata_file="$config_dir/$profile_metadata_name"
    actual="$(profile_email "$metadata_file")"

    if [[ -z "$actual" ]]; then
      if [[ "$require_login" == "true" ]]; then
        echo "$product_name profile has no signed-in email: $expected" >&2
        return 1
      fi
      echo "Warning: $product_name profile has no signed-in email: $expected" >&2
      return 0
    fi

    if [[ "$actual" != "$expected" ]]; then
      echo "$product_name account mismatch: profile $expected is signed in as $actual" >&2
      echo "Run '$profile_command login $expected' to repair the profile." >&2
      return 1
    fi
  }

  trash_profile_dir() {
    local config_dir="$1"
    local reason="$2"
    local name timestamp destination destination_base suffix=0

    [[ -n "$config_dir" && -d "$config_dir" ]] || return 0
    name="''${config_dir##*/}"
    timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
    destination_base="$profile_trash_root/$name-$timestamp"
    destination="$destination_base"
    while [[ -e "$destination" ]]; do
      suffix=$((suffix + 1))
      destination="$destination_base-$suffix"
    done

    install -d -m 700 "$profile_trash_root"
    mv -T -- "$config_dir" "$destination"
    echo "Moved $product_name profile to $destination ($reason)." >&2
    echo "Restore it by moving it back to $profile_root/$name." >&2
  }

  archive_profile() {
    local requested="$1"
    local config_dir

    config_dir="$(resolve_profile "$requested")"
    if [[ -z "$config_dir" ]]; then
      echo "Refusing to archive the default $product_name profile." >&2
      return 1
    fi
    trash_profile_dir "$config_dir" "archived"
  }

  doctor_profiles() {
    local errors=0 warnings=0
    local dir name metadata_file actual source target mode
    local primary_email=""
    local -A seen_emails=()

    doctor_error() {
      echo "error   $*"
      errors=$((errors + 1))
    }

    doctor_warning() {
      echo "warning $*"
      warnings=$((warnings + 1))
    }

    if [[ -f "$primary_metadata_file" ]]; then
      if ! jq -e . "$primary_metadata_file" >/dev/null 2>&1; then
        doctor_error "default: metadata does not contain valid JSON: $primary_metadata_file"
      else
        primary_email="$(profile_email "$primary_metadata_file")"
        if [[ -n "$primary_email" ]]; then
          seen_emails["$primary_email"]="default"
        else
          doctor_warning "default: signed-in email is unavailable"
        fi
      fi
    else
      doctor_warning "default: metadata is missing: $primary_metadata_file"
    fi

    if [[ -d "$profile_root" ]]; then
      mode="$(stat -c '%a' "$profile_root" 2>/dev/null || true)"
      if [[ -n "$mode" && "$mode" != "700" ]]; then
        doctor_warning "profile root has mode $mode instead of 700: $profile_root"
      fi
    fi

    shopt -s nullglob
    for dir in "$profile_root"/*; do
      [[ -d "$dir" ]] || continue
      name="''${dir##*/}"
      metadata_file="$dir/$profile_metadata_name"

      mode="$(stat -c '%a' "$dir" 2>/dev/null || true)"
      if [[ -n "$mode" && "$mode" != "700" ]]; then
        doctor_warning "$name: profile directory has mode $mode instead of 700"
      fi

      if [[ ! -f "$metadata_file" ]]; then
        doctor_warning "$name: metadata is missing: $metadata_file"
      elif ! jq -e . "$metadata_file" >/dev/null 2>&1; then
        doctor_error "$name: metadata does not contain valid JSON: $metadata_file"
      else
        actual="$(profile_email "$metadata_file")"
        if [[ -z "$actual" ]]; then
          doctor_warning "$name: signed-in email is unavailable"
        elif [[ "$actual" != "$name" ]]; then
          doctor_error "$name: signed in as $actual"
        fi

        if [[ -n "$actual" ]]; then
          if [[ -n "''${seen_emails[$actual]:-}" ]]; then
            doctor_error "$name: account $actual is also used by ''${seen_emails[$actual]}"
          else
            seen_emails["$actual"]="$name"
          fi
        fi
      fi

      for path in "''${shared_paths[@]}"; do
        source="$primary_config_dir/$path"
        target="$dir/$path"
        [[ -e "$source" || -L "$source" ]] || continue

        if [[ ! -e "$target" && ! -L "$target" ]]; then
          doctor_warning "$name: shared path is missing: $target"
        elif [[ ! -L "$target" ]]; then
          doctor_error "$name: shared path is profile-local: $target"
        elif [[ ! "$target" -ef "$source" ]]; then
          doctor_error "$name: shared path points to the wrong target: $target"
        fi
      done
    done

    if (( errors == 0 && warnings == 0 )); then
      echo "doctor: all clear"
    else
      echo "doctor: $errors error(s), $warnings warning(s)"
    fi
    (( errors == 0 ))
  }

  validate_profile_email() {
    local email="$1"

    if [[ ! "$email" =~ ^[^/@[:space:]]+@[^/@[:space:]]+\.[^/@[:space:]]+$ ]]; then
      echo "A valid email address is required." >&2
      return 2
    fi
  }
''
