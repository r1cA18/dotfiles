{
  lib,
  pkgs,
  ...
}:
let
  ccspaceDir = "$HOME/.local/share/ccspace";

  updateCcspace = pkgs.writeShellApplication {
    name = "update-ccspace";
    runtimeInputs = with pkgs; [
      git
      bun
      bash
    ];
    text = ''
      dir="${ccspaceDir}"
      if [ ! -d "$dir/.git" ]; then
        echo "[ccspace] not installed yet; run 'dr' first" >&2
        exit 1
      fi
      echo "[ccspace] updating..."
      git -C "$dir" pull --ff-only
      "$dir/install.sh"
    '';
  };

  # ccspace has no built-in "pick a launcher and run it" command (only
  # `ccspace launch`, which auto-selects by quota). This restores the old
  # clp/cxp `run` picker: list this provider's launchers from the manifest,
  # fzf-select one, exec it. `cl`/`cx` in zsh.nix expand to this.
  ccspacePick = pkgs.writeShellApplication {
    name = "ccspace-pick";
    runtimeInputs = with pkgs; [
      jq
      fzf
      coreutils
    ];
    text = ''
      provider="''${1:-}"
      [ $# -gt 0 ] && shift
      case "$provider" in
        claude) prefix="cc-" ;;
        codex) prefix="cx-" ;;
        *)
          echo "Usage: ccspace-pick <claude|codex> [args...]" >&2
          exit 2
          ;;
      esac

      manifest="$HOME/.local/share/ccspace/spaces.json"
      if [ ! -f "$manifest" ]; then
        echo "ccspace manifest not found; run 'ccspace add' first" >&2
        exit 1
      fi

      launchers="$(jq -r --arg p "$prefix" '.launchers | keys[] | select(startswith($p))' "$manifest" | sort)"
      if [ -z "$launchers" ]; then
        echo "No $provider launchers registered; run 'ccspace add' first" >&2
        exit 1
      fi

      selected="$(printf '%s\n' "$launchers" | fzf --reverse --height=40% --prompt="$provider launcher> ")"
      [ -n "$selected" ] || exit 1
      exec "$selected" "$@"
    '';
  };

  setupCcspaceScript = ''
    dir="${ccspaceDir}"
    log="$HOME/.local/state/ccspace/install.log"
    mkdir -p "$(dirname "$log")"

    if [ ! -d "$dir/.git" ]; then
      echo "[ccspace] cloning..."
      if ! ${pkgs.git}/bin/git clone git@github.com:Omakase-Robotics-Org/ccspace.git "$dir" >>"$log" 2>&1; then
        echo "[ccspace] clone failed, see $log" >&2
      fi
    fi

    if [ -d "$dir/.git" ] && [ ! -x "$HOME/.local/bin/ccspace" ]; then
      echo "[ccspace] installing..."
      if ! PATH="${pkgs.bun}/bin:$PATH" "$dir/install.sh" >>"$log" 2>&1; then
        echo "[ccspace] install failed, see $log" >&2
      fi
    fi
  ''
  + lib.optionalString pkgs.stdenv.isDarwin ''
    # Native menu bar app. Requires Xcode 26 (opened once, manually, to
    # finish its own first-run setup) at /Applications/Xcode.app; skipped
    # with a warning when that is not ready yet. Once installed here,
    # update-ccspace's install.sh rebuilds it after any widget-touching
    # pull on its own — this block only does the one-time bootstrap.
    if [ -d "$dir/.git" ] && [ ! -d "$HOME/Applications/CCSpace.app" ]; then
      if [ -d "/Applications/Xcode.app" ]; then
        echo "[ccspace] building the native app..."
        if ! PATH="${pkgs.xcodegen}/bin:${pkgs.python3}/bin:${pkgs.bun}/bin:${pkgs.gnumake}/bin:$PATH" \
          make -C "$dir/widget" install >>"$log" 2>&1; then
          echo "[ccspace] native app build failed, see $log" >&2
        fi
      else
        echo "[ccspace] Xcode.app not found; skipping native app build (open Xcode once, then run dr again)" >&2
      fi
    fi
  '';
in
{
  home = {
    packages = [
      updateCcspace
      ccspacePick
    ];

    activation = {
      # ccspace (Omakase-Robotics-Org/ccspace, private repo) runs its
      # TypeScript directly via bun; there is no Nix package for it. First
      # install: clone the source and run its own install.sh, which writes
      # the `ccspace` launcher and shell completion to ~/.local/bin. Updates
      # go through update-ccspace (update-all), matching update-claude-code /
      # update-codex / update-antigravity.
      setupCcspace = lib.hm.dag.entryAfter [ "writeBoundary" ] setupCcspaceScript;
    };
  };
}
