# The capability catalog (agents/capabilities/catalog.nix) on this host.
#
# Where the r1hn Home Manager module is imported (macOS, see
# nix/flake/configurations.nix) and r1hn is enabled, r1hn projects the
# catalog into every client and account directory. Elsewhere this module
# does the part Home Manager can do alone: the baseline tools on PATH and the
# baseline MCP servers and plugins merged into the default directories.
# Skills then come from agent-skills.nix.
{
  config,
  inputs,
  lib,
  options,
  pkgs,
  ...
}:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  host = if isDarwin then "mac" else "linux";
  entries = import ../../../agents/capabilities/catalog.nix {
    inherit pkgs lib inputs;
    homeDir = config.home.homeDirectory;
    discovered = config.programs.agent-skills.catalog;
  };
  projected = (options ? r1hn) && config.dotfiles.r1hn.enable;

  hostsOf = e: e.hosts or [ "all" ];
  local = e: builtins.elem "all" (hostsOf e) || builtins.elem host (hostsOf e);
  clientsOf =
    e:
    e.clients or [
      "claude"
      "codex"
      "antigravity"
      "dsh"
    ];
  baseline =
    kind: client:
    lib.filterAttrs (
      _: e: e.kind == kind && (e.tier or "catalog") == "baseline" && builtins.elem client (clientsOf e)
    ) entries;
  serverHere = e: if local e then e.mcp.local else e.mcp.remote or null;
  servers =
    client:
    lib.filterAttrs (_: s: s != null && (s.env or { }) == { }) (
      lib.mapAttrs (_: serverHere) (baseline "mcp" client)
    );

  claudeServer =
    s:
    if s ? url then
      {
        type = "http";
        inherit (s) url;
      }
    else
      {
        type = "stdio";
        inherit (s) command;
        args = s.args or [ ];
      };
  codexServer =
    s:
    if s ? url then
      { inherit (s) url; }
    else
      {
        inherit (s) command;
        args = s.args or [ ];
      };
  agyServer =
    s:
    if s ? url then
      { serverUrl = s.url; }
    else
      {
        inherit (s) command;
        args = s.args or [ ];
      };

  pluginsFor =
    client:
    lib.filterAttrs (_: p: p != null) (
      lib.mapAttrs (_: e: e.plugin.${client} or null) (baseline "plugin" client)
    );
  markets =
    wrap: client:
    lib.mapAttrs' (_: p: lib.nameValuePair p.marketplace (wrap p.source)) (
      lib.filterAttrs (_: p: (p.marketplace or null) != null && (p.source or null) != null) (
        pluginsFor client
      )
    );

  merge = import ../../lib/merge-managed.nix { inherit pkgs lib; };
in
{
  options.dotfiles.capabilities = {
    entries = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      description = "The catalog as evaluated on this host.";
    };
    projectedByR1hn = lib.mkOption {
      type = lib.types.bool;
      readOnly = true;
      description = "Whether r1hn projects the catalog here (otherwise agent-skills.nix and this module do).";
    };
  };

  config = lib.mkMerge [
    {
      dotfiles.capabilities = {
        inherit entries;
        projectedByR1hn = projected;
      };
    }

    (lib.optionalAttrs (options ? r1hn) {
      r1hn.capabilities = {
        enable = config.dotfiles.r1hn.enable;
        package = inputs.r1hn.packages.${pkgs.stdenv.hostPlatform.system}.r1hn;
        skillsBundle = config.programs.agent-skills.bundlePath;
        inherit entries;
        bundles.work = {
          description = "Work time, contracts, invoices and income (Workfolio)";
          tags = [ "work" ];
          members = [
            "workfolio"
            "workfolio-mcp"
          ];
        };
      };
    })

    (lib.mkIf (!projected) {
      home.packages = lib.concatMap (e: lib.optionals (local e) (e.packages or [ ])) (
        lib.attrValues (
          lib.filterAttrs (_: e: e.kind == "tool" && (e.tier or "catalog") == "baseline") entries
        )
      );

      home.activation.capabilityFallback =
        lib.hm.dag.entryAfter [ "writeBoundary" "claudeSettings" "codexConfig" ]
          (
            merge {
              format = "json";
              target = "$HOME/.claude.json";
              name = "claude-mcp";
              fragment.entries.mcpServers = lib.mapAttrs (_: claudeServer) (servers "claude");
            }
            + merge {
              format = "json";
              target = "$HOME/.claude/settings.json";
              name = "claude-plugins";
              fragment.entries = {
                enabledPlugins = lib.mapAttrs' (_: p: lib.nameValuePair p.name true) (pluginsFor "claude");
                extraKnownMarketplaces = markets (source: { inherit source; }) "claude";
              };
            }
            + merge {
              format = "toml";
              target = "$HOME/.codex/config.toml";
              name = "codex-capabilities";
              fragment.entries = {
                mcp_servers = lib.mapAttrs (_: codexServer) (servers "codex");
                plugins = lib.mapAttrs' (_: p: lib.nameValuePair p.name { enabled = true; }) (pluginsFor "codex");
                marketplaces = markets lib.id "codex";
              };
            }
            + merge {
              format = "json";
              target = "$HOME/.gemini/config/mcp_config.json";
              name = "agy-mcp";
              fragment.entries.mcpServers = lib.mapAttrs (_: agyServer) (servers "antigravity");
            }
          );
    })
  ];
}
