{
  lib,
  pkgs,
  asLib,
  sources,
}:

let
  inherit (builtins)
    attrNames
    concatMap
    elem
    filter
    removeAttrs
    toJSON
    ;
  inherit (lib) unique;

  # ── Pack definitions ──────────────────────────────────────────────
  # Each pack groups related skills, MCP servers, and tool-specific plugins.
  # skills  = managed by agent-skills-nix (SKILL.md)
  # plugins = backwards-compatible alias for claudePlugins
  # claudePlugins = managed via .claude/settings.local.json (enabledPlugins)
  # codexPlugins = installed into the Codex user plugin cache/config by shellHook

  packs = {
    # Design tooling. MCP servers are heavy (many tool defs) and only needed
    # during visual/diagram work, so they live here instead of global seed.
    design = {
      skills = [ ];
      plugins = [ ];
      codexPlugins = [ "product-design@openai-curated-remote" ];
      mcpServers = {
        drawio = {
          command = "npx";
          args = [
            "-y"
            "@drawio/mcp"
          ];
          type = "stdio";
        };
        pencil = {
          command = "/Users/r1ca18/.cursor/extensions/highagency.pencildev-0.6.30-universal/out/mcp-server-darwin-arm64";
          args = [
            "--app"
            "cursor"
          ];
          env = { };
          type = "stdio";
        };
      };
    };
    ios = {
      skills = [
        "swift-dev-toolkit"
        "ios-device-build"
        "app-store-screenshots"
        "codex-app-screenshots"
        "shipswift-add-component"
        "shipswift-build-feature"
        "shipswift-explore-recipes"
      ];
      claudePlugins = [ "swift-lsp@claude-plugins-official" ];
      mcpServers = {
        shipswift = {
          type = "http";
          url = "https://api.shipswift.app/mcp";
        };
      };
    };
    web = {
      skills = [
        "vercel-react-best-practices"
      ];
      claudePlugins = [
        "typescript-lsp@claude-plugins-official"
      ];
    };
    media = {
      skills = [
        "video-editing"
        "remotion-best-practices"
        "text-to-lottie"
      ];
      plugins = [ ];
    };
    research = {
      skills = [
        "typst-author"
        "touying-author"
      ];
      claudePlugins = [ "academic-research-skills@academic-research-skills" ];
    };
    publishing = {
      skills = [
        "x-article-publisher"
        "x-research"
      ];
      plugins = [ ];
    };
    vault = {
      # knowledge-extract is global (agent-skills.nix enable list).
      skills = [
        "session-documentation"
        "design-capture"
        "forms-archive"
      ];
      claudePlugins = [ ];
    };
  };

  # Claude plugins that are ALWAYS enabled regardless of pack selection.
  # These are never disabled by the shellHook.
  globalClaudePlugins = [
    "codex@openai-codex"
  ];

  globalCodexPlugins = [ ];

  packClaudePlugins = p: unique ((packs.${p}.plugins or [ ]) ++ (packs.${p}.claudePlugins or [ ]));
  packCodexPlugins = p: packs.${p}.codexPlugins or [ ];
  packCodexMarketplaces = p: packs.${p}.codexMarketplaces or { };

  # All plugins that belong to some pack (candidates for per-project disable).
  allPackClaudePlugins = unique (concatMap packClaudePlugins (attrNames packs));
  allPackCodexPlugins = unique (concatMap packCodexPlugins (attrNames packs));

  # ── Helper functions ──────────────────────────────────────────────

  resolveSkills =
    {
      selectedPacks ? [ ],
      extraSkills ? [ ],
    }:
    unique (concatMap (p: packs.${p}.skills) selectedPacks ++ extraSkills);

  # Resolve selected packs into Claude plugin enable/disable map.
  # globalClaudePlugins are excluded from the disable list.
  resolveClaudePlugins =
    {
      selectedPacks ? [ ],
      extraPlugins ? [ ],
    }:
    let
      enabled = unique (concatMap packClaudePlugins selectedPacks ++ extraPlugins);
      disabled = filter (p: !(elem p enabled) && !(elem p globalClaudePlugins)) allPackClaudePlugins;
    in
    {
      inherit enabled disabled;
    };

  resolvePlugins = resolveClaudePlugins;

  resolveCodexPlugins =
    {
      selectedPacks ? [ ],
      extraCodexPlugins ? [ ],
    }:
    let
      enabled = unique (concatMap packCodexPlugins selectedPacks ++ extraCodexPlugins);
      # Codex plugin state is global user config/cache, so project packs should
      # request installs but must not disable plugins selected elsewhere.
      disabled = [ ];
    in
    {
      inherit enabled disabled;
    };

  resolveCodexMarketplaces =
    {
      selectedPacks ? [ ],
      extraCodexMarketplaces ? { },
    }:
    lib.foldl' (acc: p: acc // packCodexMarketplaces p) extraCodexMarketplaces selectedPacks;

  # Merge mcpServers of all selected packs (plus extraMcpServers).
  resolveMcp =
    {
      selectedPacks ? [ ],
      extraMcpServers ? { },
    }:
    lib.foldl' (acc: p: acc // (packs.${p}.mcpServers or { })) extraMcpServers selectedPacks;

  mkPackBundle =
    {
      selectedPacks ? [ ],
      extraSkills ? [ ],
    }:
    let
      skillNames = resolveSkills { inherit selectedPacks extraSkills; };
      catalog = asLib.discoverCatalog sources;
      selection = asLib.selectSkills {
        inherit catalog sources;
        allowlist = skillNames;
      };
    in
    asLib.mkBundle {
      inherit pkgs selection;
      name = "project-skills-bundle";
    };

  mkProjectShellHook =
    {
      selectedPacks ? [ ],
      extraSkills ? [ ],
      extraPlugins ? [ ],
      extraClaudePlugins ? [ ],
      extraCodexPlugins ? [ ],
      extraCodexMarketplaces ? { },
      extraMcpServers ? { },
    }:
    let
      bundle = mkPackBundle { inherit selectedPacks extraSkills; };

      skillsHook = asLib.mkShellHook {
        inherit pkgs bundle;
        targets = {
          claude = {
            dest = ".claude/skills";
            structure = "copy-tree";
            enable = true;
            systems = [ ];
          };
          codex = {
            dest = ".codex/skills";
            structure = "copy-tree";
            enable = true;
            systems = [ ];
          };
        };
      };

      claudePluginsCfg = resolveClaudePlugins {
        inherit selectedPacks;
        extraPlugins = extraPlugins ++ extraClaudePlugins;
      };
      claudeEnableMap = builtins.listToAttrs (
        map (p: {
          name = p;
          value = true;
        }) claudePluginsCfg.enabled
      );
      claudeDisableMap = builtins.listToAttrs (
        map (p: {
          name = p;
          value = false;
        }) claudePluginsCfg.disabled
      );
      claudePluginsJson = toJSON (claudeEnableMap // claudeDisableMap);

      claudePluginsHook =
        lib.optionalString (claudePluginsCfg.enabled != [ ] || claudePluginsCfg.disabled != [ ])
          ''
            mkdir -p .claude
            _sp_local=".claude/settings.local.json"
            _sp_plugins='${claudePluginsJson}'
            _sp_tmp="$_sp_local.$$.tmp"
            if [ -f "$_sp_local" ]; then
              ${pkgs.jq}/bin/jq --argjson p "$_sp_plugins" '.enabledPlugins = (.enabledPlugins // {}) * $p' \
                "$_sp_local" > "$_sp_tmp" && mv "$_sp_tmp" "$_sp_local"
            else
              echo "{\"enabledPlugins\": $_sp_plugins}" | ${pkgs.jq}/bin/jq . > "$_sp_local"
            fi

            # Workaround: ensure settings.json has enabledPlugins key
            # (settings.local.json overrides are ignored without it, bug #27247)
            _sp_settings=".claude/settings.json"
            if [ -f "$_sp_settings" ]; then
              if ! ${pkgs.jq}/bin/jq -e '.enabledPlugins' "$_sp_settings" > /dev/null 2>&1; then
                _sp_stmp="$_sp_settings.$$.tmp"
                ${pkgs.jq}/bin/jq '. + {"enabledPlugins": {}}' "$_sp_settings" > "$_sp_stmp" \
                  && mv "$_sp_stmp" "$_sp_settings"
              fi
            fi
          '';

      codexPluginsCfg = resolveCodexPlugins { inherit selectedPacks extraCodexPlugins; };
      codexMarketplacesResolved = resolveCodexMarketplaces {
        inherit selectedPacks extraCodexMarketplaces;
      };
      codexMarketplacesJson = toJSON codexMarketplacesResolved;
      codexPluginsInstallJson = toJSON codexPluginsCfg.enabled;

      codexHook =
        lib.optionalString (codexPluginsCfg.enabled != [ ] || codexMarketplacesResolved != { })
          ''
            if command -v codex >/dev/null 2>&1; then
              _codex_marketplaces='${codexMarketplacesJson}'
              printf '%s\n' "$_codex_marketplaces" \
                | ${pkgs.jq}/bin/jq -r 'to_entries[] | .value.source // empty' \
                | while IFS= read -r _codex_marketplace_source; do
                  [ -n "$_codex_marketplace_source" ] || continue
                  codex plugin marketplace add "$_codex_marketplace_source" >/dev/null 2>&1 || true
                done

              _codex_plugins_to_install='${codexPluginsInstallJson}'
              printf '%s\n' "$_codex_plugins_to_install" | ${pkgs.jq}/bin/jq -r '.[]' | while IFS= read -r _codex_plugin; do
                [ -n "$_codex_plugin" ] || continue
                codex plugin add "$_codex_plugin" >/dev/null 2>&1 || true
              done
            fi
          '';

      # MCP servers: write selected packs' mcpServers into repo-root .mcp.json
      # (Claude Code project-scope standard file). Same jq recursive-merge as
      # claudePluginsHook so user-added servers survive.
      mcpServersResolved = resolveMcp { inherit selectedPacks extraMcpServers; };
      mcpJson = toJSON mcpServersResolved;
      mcpHook = lib.optionalString (mcpServersResolved != { }) ''
        _mcp=".mcp.json"
        _mcp_servers='${mcpJson}'
        _mcp_tmp="$_mcp.$$.tmp"
        if [ -f "$_mcp" ]; then
          ${pkgs.jq}/bin/jq --argjson m "$_mcp_servers" '.mcpServers = (.mcpServers // {}) * $m' \
            "$_mcp" > "$_mcp_tmp" && mv "$_mcp_tmp" "$_mcp"
        else
          echo "{\"mcpServers\": $_mcp_servers}" | ${pkgs.jq}/bin/jq . > "$_mcp"
        fi
      '';
    in
    skillsHook + claudePluginsHook + codexHook + mcpHook;

  mkShellWithSkills =
    {
      selectedPacks ? [ ],
      extraSkills ? [ ],
      extraPlugins ? [ ],
      extraClaudePlugins ? [ ],
      extraCodexPlugins ? [ ],
      extraCodexMarketplaces ? { },
      extraMcpServers ? { },
      ...
    }@args:
    let
      packHook = mkProjectShellHook {
        inherit
          selectedPacks
          extraSkills
          extraPlugins
          extraClaudePlugins
          extraCodexPlugins
          extraCodexMarketplaces
          extraMcpServers
          ;
      };
      cleanArgs = removeAttrs args [
        "selectedPacks"
        "extraSkills"
        "extraPlugins"
        "extraClaudePlugins"
        "extraCodexPlugins"
        "extraCodexMarketplaces"
        "extraMcpServers"
      ];
    in
    pkgs.mkShell (
      cleanArgs
      // {
        shellHook = packHook + (args.shellHook or "");
      }
    );

in
{
  inherit
    packs
    globalClaudePlugins
    globalCodexPlugins
    allPackClaudePlugins
    allPackCodexPlugins
    resolveSkills
    resolveClaudePlugins
    resolvePlugins
    resolveCodexPlugins
    resolveCodexMarketplaces
    mkPackBundle
    mkProjectShellHook
    mkShellWithSkills
    ;
}
