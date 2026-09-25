{
  lib,
  pkgs,
  config,
  ...
}:
let
  orcaCli = "/Applications/Orca.app/Contents/Resources/bin/orca";
  orcaDir = "${config.home.homeDirectory}/Library/Application Support/Orca";
  # The default Codex home is the real primary account store. Orca's managed
  # Codex home is a symlink into this directory, so System default, cx-orca,
  # and bare `codex` all share the same credentials and session history.
  orcaCodexHome = "${config.home.homeDirectory}/.codex";

  # Claude managed credentials live in the "Orca Claude Code Managed
  # Credentials" keychain item keyed by account uuid; the managed auth dir
  # itself holds no token file. Exporting them into .credentials.json lets
  # ccspace launchers (cc-*) and bare `claude` use the same dirs without Orca.
  # Re-run after adding a managed account in Orca.
  orcaExportClaudeCreds = pkgs.writeShellApplication {
    name = "orca-export-claude-creds";
    text = ''
      accounts_dir="${orcaDir}/claude-accounts"
      for auth in "$accounts_dir"/*/auth; do
        [ -d "$auth" ] || continue
        uuid="$(basename "$(dirname "$auth")")"
        tmp="$auth/.credentials.json.tmp"
        if /usr/bin/security find-generic-password -s 'Orca Claude Code Managed Credentials' -a "$uuid" -w >"$tmp" 2>/dev/null; then
          chmod 600 "$tmp"
          mv "$tmp" "$auth/.credentials.json"
          echo "exported $uuid"
        else
          rm -f "$tmp"
        fi
      done
    '';
  };

  # One-shot helper: pick the managed Claude account matching the primary
  # email, make its auth dir a symlink to ~/.claude, and mark ~/.claude as
  # managed. ~/.claude stays the real canonical account dir, matching ~/.codex.
  orcaSetPrimaryClaude = pkgs.writeShellApplication {
    name = "orca-set-primary-claude";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      set -euo pipefail
      primary_email=''${1:-''${ORCA_PRIMARY_CLAUDE_EMAIL:-}}
      if [ -z "$primary_email" ]; then
        echo "Usage: orca-set-primary-claude <email>" >&2
        echo "Or set ORCA_PRIMARY_CLAUDE_EMAIL." >&2
        exit 64
      fi
      orca_dir="${orcaDir}/claude-accounts"
      target=""
      uuid=""
      for auth in "$orca_dir"/*/auth; do
        [ -d "$auth" ] || continue
        email=$(jq -r '.emailAddress // empty' "$auth/oauth-account.json" 2>/dev/null || true)
        if [ "$email" = "$primary_email" ]; then
          target="$auth"
          uuid="$(basename "$(dirname "$auth")")"
          break
        fi
      done
      if [ -z "$target" ]; then
        echo "No managed Claude account found for $primary_email" >&2
        echo "Run: orca account add --agent claude" >&2
        exit 1
      fi
      if [ ! -d "$HOME/.claude" ]; then
        echo "$HOME/.claude does not exist" >&2
        exit 1
      fi
      if [ -L "$HOME/.claude" ]; then
        echo "$HOME/.claude is already a symlink to $(readlink "$HOME/.claude")" >&2
        exit 1
      fi
      if [ -L "$target" ]; then
        echo "$target is already a symlink to $(readlink "$target")"
        exit 0
      fi
      echo "Primary Claude auth: $target"
      backup="''${target}-backup-$(date +%Y%m%d-%H%M%S)"
      mv "$target" "$backup"
      ln -s "$HOME/.claude" "$target"
      printf '%s' "$uuid" > "$HOME/.claude/.orca-managed-claude-auth"
      echo "Backed up $target to $backup and linked it to ~/.claude"
      orca-export-claude-creds
      echo "Primary Claude account unified to $primary_email"
    '';
  };
in
lib.mkIf pkgs.stdenv.isDarwin {
  # Orca GUI is installed via the homebrew cask in nix/darwin/configuration.nix.
  # Orca skills come from the orca-skills flake input via agent-skills.nix.
  home = {
    file = {
      # /usr/local/bin/orca is a dangling symlink (empty target). ~/.local/bin
      # precedes /usr/local/bin in PATH, so this shadows it without sudo.
      ".local/bin/orca".source = config.lib.file.mkOutOfStoreSymlink orcaCli;

      # Unified layout: ~/.codex is the real primary account home. Orca's
      # managed Codex home and cx-orca both resolve through this path.
      ".codex-orca".source = config.lib.file.mkOutOfStoreSymlink orcaCodexHome;
    };

    packages = [
      orcaExportClaudeCreds
      orcaSetPrimaryClaude
    ];

    activation.orcaSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      orca_settings=${./orca-settings.json}
      profiles_dir="$HOME/Library/Application Support/Orca/profiles"
      if [ -d "$profiles_dir" ]; then
        for data in "$profiles_dir"/*/orca-data.json; do
          [ -f "$data" ] || continue
          cp "$data" "$data.orca-nix-backup"
          if ${pkgs.jq}/bin/jq --slurpfile managed "$orca_settings" \
              '.settings = (((.settings // {})) * $managed[0])' "$data" > "$data.orca-nix-tmp"; then
            mv "$data.orca-nix-tmp" "$data"
          else
            rm -f "$data.orca-nix-tmp"
            echo "orca-settings: skipped $data (jq failed)" >&2
          fi
        done
      fi
    '';
  };
}
