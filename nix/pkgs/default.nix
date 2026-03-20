pkgs: {
  agent-browser = pkgs.callPackage ./agent-browser { };
  firecrawl-cli = pkgs.callPackage ./firecrawl-cli { };
  stitch-mcp = pkgs.callPackage ./stitch-mcp { };
}
