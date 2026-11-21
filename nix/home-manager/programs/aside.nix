{
  config,
  lib,
  pkgs,
  ...
}:
let
  # The Aside CLI updates itself with `aside update`, so activation only
  # installs it when missing. The browser app comes from the Homebrew cask.
  # Its MCP server and skill come from the capability catalog.
  asideBin = "${config.home.homeDirectory}/.local/bin/aside";
in
{
  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    home.activation.installAsideCli = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -x ${lib.escapeShellArg asideBin} ]; then
        log="$HOME/.local/state/aside/install.log"
        ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$log")"
        installer=$(${pkgs.coreutils}/bin/mktemp)
        if ! ${pkgs.curl}/bin/curl -fsSL https://releases.aside.com/install.sh -o "$installer" \
          || ! PATH="${
            lib.makeBinPath [
              pkgs.curl
              pkgs.coreutils
            ]
          }:/usr/bin:/bin" NO_COLOR=1 $DRY_RUN_CMD ${pkgs.bash}/bin/bash "$installer" </dev/null >>"$log" 2>&1; then
          echo "[aside] CLI install failed, see $log" >&2
        fi
        ${pkgs.coreutils}/bin/rm -f "$installer"
      fi
    '';
  };
}
