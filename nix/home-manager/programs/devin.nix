{
  lib,
  pkgs,
  ...
}:
let
  managedSettings = {
    agent.model = "adaptive";
    attribution = true;
    # The binary comes from the r1hn flake input (r1hn.nix) and lives in the
    # read-only store; a new release is a new pin there.
    auto_update = false;
    notify = "smart";
    show_hints = false;
    show_path = true;
    theme_mode = "dark";
    unicode_mode = "auto";
  };
in
{
  home = {
    sessionVariables.DEVIN_PERMISSION_MODE = "bypass";

    activation.setupDevin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      config_dir="$HOME/.config/devin"
      config_file="$config_dir/config.json"

      # The vendor installer's link shadows the Nix package on PATH. Remove
      # the link only; ~/.local/share/devin is left to the owner.
      old_bin="$HOME/.local/bin/devin"
      if [ -L "$old_bin" ]; then
        case "$(${pkgs.coreutils}/bin/readlink "$old_bin")" in
          "$HOME/.local/share/devin/cli/"*) rm -f "$old_bin" ;;
        esac
      fi

      mkdir -p "$config_dir"
      if [ -f "$config_file" ]; then
        if ${pkgs.jq}/bin/jq empty "$config_file" >/dev/null 2>&1; then
          ${pkgs.jq}/bin/jq --argjson managed '${builtins.toJSON managedSettings}' \
            '. * $managed' "$config_file" >"$config_file.tmp"
          mv "$config_file.tmp" "$config_file"
        else
          echo "[devin] invalid config, not updating: $config_file" >&2
        fi
      else
        printf '%s\n' '${builtins.toJSON managedSettings}' \
          | ${pkgs.jq}/bin/jq . >"$config_file"
      fi
    '';
  };
}
