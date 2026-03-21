{
  config,
  lib,
  username,
  pkgs,
  ...
}:
let
  dotfilesDir =
    if pkgs.stdenv.isDarwin then "/Users/${username}/dotfiles" else "/home/${username}/dotfiles";
in
{
  home.file = {
    ".claude/settings.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/claude/settings.json";
      force = true;
    };
    ".claude/CLAUDE.md" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/shared/GLOBAL_INSTRUCTIONS.md";
      force = true;
    };
    ".claude/mcp-servers.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/claude/mcp-servers.json";
      force = true;
    };
    ".claude/commands" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/claude/commands";
      force = true;
    };
    ".claude/agents" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/claude/agents";
      force = true;
    };
    ".claude/hooks" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/claude/hooks";
      force = true;
    };
    ".claude/rules" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/claude/rules";
      force = true;
    };
  };

  home.activation.syncClaudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "Syncing Claude MCP servers..."
    ${pkgs.python3}/bin/python3 \
      "${dotfilesDir}/claude/scripts/sync-mcp-servers.py" \
      "$HOME/.claude.json" \
      "${dotfilesDir}/claude/mcp-servers.json" || true
  '';
}
