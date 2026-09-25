{
  lib,
  pkgs,
  ...
}:
let
  managedSettings = {
    agent.model = "adaptive";
    attribution = true;
    auto_update = true;
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
      export PATH="${pkgs.curl}/bin:${pkgs.jq}/bin:${pkgs.coreutils}/bin:$PATH"
      bin="$HOME/.local/bin/devin"
      config_dir="$HOME/.config/devin"
      config_file="$config_dir/config.json"
      log="$HOME/.local/state/devin/install.log"

      if [ ! -x "$bin" ]; then
        mkdir -p "$(dirname "$log")"
        if ! ${pkgs.curl}/bin/curl -fsSL https://cli.devin.ai/install.sh \
          | ${pkgs.bash}/bin/bash >>"$log" 2>&1; then
          echo "[devin] install failed, see $log" >&2
        fi
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
