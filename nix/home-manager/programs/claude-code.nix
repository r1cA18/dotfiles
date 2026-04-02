{
  config,
  lib,
  username,
  pkgs,
  ...
}:
let
  homeDir = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
  dotfilesDir = "${homeDir}/dotfiles";
  python3 = lib.getExe pkgs.python3;

  mkClaudeSymlink = relativePath: {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/${relativePath}";
    force = true;
  };

  managedClaudePaths = {
    ".claude/settings.json" = "claude/settings.json";
    ".claude/CLAUDE.md" = "shared/GLOBAL_INSTRUCTIONS.md";
    ".claude/mcp-servers.json" = "claude/mcp-servers.json";
    ".claude/commands" = "claude/commands";
    ".claude/agents" = "claude/agents";
    ".claude/hooks" = "claude/hooks";
    ".claude/rules" = "claude/rules";
  };
in
{
  home.file = lib.mapAttrs (_: mkClaudeSymlink) managedClaudePaths;

  home.activation.syncClaudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "Syncing Claude MCP servers..."
    ${python3} \
      "${dotfilesDir}/claude/scripts/sync-mcp-servers.py" \
      "$HOME/.claude.json" \
      "${dotfilesDir}/claude/mcp-servers.json" || true
  '';
}
