{
  lib,
  pkgs,
  ...
}:
let
  ccspaceDir = "$HOME/.local/share/ccspace";
  ccspaceClone =
    if pkgs.stdenv.isLinux then
      ''${pkgs.git}/bin/git -c credential.helper= -c "credential.helper=!${pkgs.gh}/bin/gh auth git-credential" clone https://github.com/Omakase-Robotics-Org/ccspace.git "$dir"''
    else
      ''${pkgs.git}/bin/git clone git@github.com:Omakase-Robotics-Org/ccspace.git "$dir"'';

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

  ccspaceSyncOrca = pkgs.writeShellApplication {
    name = "ccspace-sync-orca";
    runtimeInputs = with pkgs; [ jq ];
    text = ''
      set -euo pipefail
      if ! command -v orca >/dev/null 2>&1; then
        echo "ccspace-sync-orca: orca is not available" >&2
        exit 1
      fi
      if ! command -v ccspace >/dev/null 2>&1; then
        echo "ccspace-sync-orca: ccspace is not available" >&2
        exit 1
      fi

      accounts="$(orca account list --json)"
      rows="$(printf '%s' "$accounts" | jq -rf ${../../../agents/scripts/orca-account-launchers.jq})"
      manifest="$HOME/.local/share/ccspace/spaces.json"
      orca_dir="$HOME/Library/Application Support/Orca"
      while IFS=$'\t' read -r provider id email launcher; do
        [ -n "$provider" ] || continue
        case "$provider" in
          claude)
            space="$orca_dir/claude-accounts/$id/auth"
            space_path="$space"
            ;;
          codex)
            managed_home="$orca_dir/codex-accounts/$id/home"
            [ -d "$managed_home" ] || continue
            space=".codex--orca-$id"
            space_path="$HOME/$space"
            if [ ! -e "$space_path" ] && [ ! -L "$space_path" ]; then
              ln -s "$managed_home" "$space_path"
            elif [ -L "$space_path" ] && [ "$(readlink "$space_path")" != "$managed_home" ]; then
              current_target="$(readlink "$space_path")"
              case "$current_target" in
                "$orca_dir"/codex-accounts/*/home) ln -sfn "$managed_home" "$space_path" ;;
                *)
                  echo "ccspace-sync-orca: $space_path does not point to $managed_home" >&2
                  continue
                  ;;
              esac
            elif [ ! -L "$space_path" ]; then
              echo "ccspace-sync-orca: $space_path is not a symlink" >&2
              continue
            fi
            ;;
          *) continue ;;
        esac
        [ -d "$space_path" ] || continue
        current=""
        if [ -f "$manifest" ]; then
          current="$(jq -r --arg launcher "$launcher" '.launchers[$launcher].space // empty' "$manifest")"
        fi
        if [ -z "$current" ]; then
          ccspace add "$launcher" --provider "$provider" --space "$space" --description "Orca managed account: $email"
        elif [ "$current" != "$space" ]; then
          ccspace edit "$launcher" --space "$space" --description "Orca managed account: $email"
        fi
      done <<< "$rows"

      if command -v orca-export-claude-creds >/dev/null 2>&1; then
        orca-export-claude-creds >/dev/null
      fi
    '';
  };

  # ccspace has no built-in "pick an account/launcher and run it" command (only
  # `ccspace launch`, which auto-selects by quota). This restores the old
  # clp/cxp `run` picker: synchronize Orca accounts, show email and account ID,
  # fzf-select one, and exec its launcher. `cl`/`cx` in zsh.nix expand to this.
  ccspacePick = pkgs.writeShellApplication {
    name = "ccspace-pick";
    runtimeInputs = with pkgs; [
      jq
      fzf
      coreutils
    ];
    text = ''
      PATH="$HOME/.local/bin:$PATH"
      export PATH
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

      if command -v ccspace-sync-orca >/dev/null 2>&1; then
        ccspace-sync-orca >&2 || echo "ccspace-pick: using existing launchers because Orca sync failed" >&2
      fi

      candidates=""
      if command -v orca >/dev/null 2>&1; then
        candidates="$(orca account list --json 2>/dev/null \
          | jq -rf ${../../../agents/scripts/orca-account-launchers.jq} \
          | while IFS=$'\t' read -r account_provider id email launcher; do
              [ "$account_provider" = "$provider" ] || continue
              manifest="$HOME/.local/share/ccspace/spaces.json"
              [ -f "$manifest" ] || continue
              jq -e --arg launcher "$launcher" ' .launchers[$launcher] != null' "$manifest" >/dev/null || continue
              printf '%s [%s]\t%s\n' "$email" "$id" "$launcher"
            done)" || candidates=""
      fi

      if [ -z "$candidates" ] && command -v ccspace >/dev/null 2>&1; then
        candidates="$(ccspace workspace list 2>/dev/null | jq -r --arg p "$provider" '
          .[]
          | select(.provider == $p and ((.launchers | length > 0) or .isDefault))
          | if .isDefault and (.launchers | length == 0) then
              "\(.email // "(default)")\t\($p)"
            else
              (.launchers | sort_by(.name) | first) as $launcher
              | "\(.email // $launcher.name)\t\($launcher.name)"
            end
        ' 2>/dev/null || true)"
      fi

      if [ -z "$candidates" ]; then
        manifest="$HOME/.local/share/ccspace/spaces.json"
        if [ ! -f "$manifest" ]; then
          echo "ccspace manifest not found; run 'ccspace add' first" >&2
          exit 1
        fi
        candidates="$(jq -r --arg p "$prefix" '.launchers | keys[] | select(startswith($p)) | "\(.)\t\(.)"' "$manifest" | sort)"
      fi

      if [ -z "$candidates" ]; then
        echo "No $provider accounts or launchers registered; run 'ccspace add' first" >&2
        exit 1
      fi

      selected="$(printf '%s\n' "$candidates" | fzf --delimiter=$'\t' --with-nth=1 --reverse --height=40% --prompt="$provider account> ")"
      [ -n "$selected" ] || exit 1
      target="$(printf '%s' "$selected" | cut -f2)"
      [ -n "$target" ] || exit 1
      exec "$target" "$@"
    '';
  };

  setupCcspaceScript = ''
    dir="${ccspaceDir}"
    log="$HOME/.local/state/ccspace/install.log"
    mkdir -p "$(dirname "$log")"
    export PATH="${
      lib.makeBinPath (
        with pkgs;
        [
          git
          openssh
          coreutils
        ]
      )
    }:$PATH:/usr/bin:/bin"

    if [ ! -d "$dir/.git" ]; then
      echo "[ccspace] cloning..."
      if ! ${ccspaceClone} >>"$log" 2>&1; then
        echo "[ccspace] clone failed, see $log" >&2
      fi
    fi

    ${lib.optionalString pkgs.stdenv.isLinux ''
      if [ -d "$dir/.git" ]; then
        ${pkgs.git}/bin/git -C "$dir" config --local credential.helper "!${pkgs.gh}/bin/gh auth git-credential"
      fi
    ''}

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
    ]
    ++ lib.optional pkgs.stdenv.isDarwin ccspaceSyncOrca;

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
