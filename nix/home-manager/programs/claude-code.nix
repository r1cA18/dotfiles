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
    ".claude/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/claude/settings.json";
    ".claude/CLAUDE.md".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/shared/GLOBAL_INSTRUCTIONS.md";
    ".claude/mcp-servers.json".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/claude/mcp-servers.json";
    ".claude/commands".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/claude/commands";
    ".claude/agents".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/claude/agents";
    ".claude/hooks".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/claude/hooks";
    ".claude/rules".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/claude/rules";
  };

  home.activation.syncClaudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "Syncing Claude MCP servers..."
    ${pkgs.python3}/bin/python3 \
      "${dotfilesDir}/claude/scripts/sync-mcp-servers.py" \
      "$HOME/.claude.json" \
      "${dotfilesDir}/claude/mcp-servers.json" || true
  '';
}
