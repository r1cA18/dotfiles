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
  # Each pack groups related skills and plugins.
  # skills  = managed by agent-skills-nix (SKILL.md)
  # plugins = managed via .claude/settings.local.json (enabledPlugins)

  packs = {
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
      plugins = [ "swift-lsp@claude-plugins-official" ];
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
      plugins = [
        "typescript-lsp@claude-plugins-official"
        "frontend-design@claude-plugins-official"
        "playground@claude-plugins-official"
        "gsap-skills@gsap-skills"
      ];
    };
    media = {
      skills = [
        "video-editing"
        "remotion-best-practices"
      ];
      plugins = [ ];
    };
    research = {
      skills = [
        "typst-author"
        "touying-author"
      ];
      plugins = [ "academic-research-skills@academic-research-skills" ];
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
      plugins = [ ];
    };
  };

  # Plugins that are ALWAYS enabled regardless of pack selection.
  # These are never disabled by the shellHook.
  globalPlugins = [
    "commit-commands@claude-plugins-official"
    "hookify@claude-plugins-official"
    "claude-md-management@claude-plugins-official"
    "claude-code-setup@claude-plugins-official"
    "plugin-dev@claude-plugins-official"
    "mgrep@Mixedbread-Grep"
    "context7@claude-plugins-official"
    "linear@claude-plugins-official"
    "codex@openai-codex"
    "ralph-loop@claude-plugins-official"
    "skill-creator@claude-plugins-official"
    "explanatory-output-style@claude-plugins-official"
    "document-skills@anthropic-agent-skills"
  ];

  # All plugins that belong to some pack (candidates for per-project disable).
  allPackPlugins = unique (concatMap (p: packs.${p}.plugins) (attrNames packs));

  # ── Helper functions ──────────────────────────────────────────────

  resolveSkills =
    {
      selectedPacks ? [ ],
      extraSkills ? [ ],
    }:
    unique (concatMap (p: packs.${p}.skills) selectedPacks ++ extraSkills);

  # Resolve selected packs into plugin enable/disable map.
  # globalPlugins are excluded from the disable list.
  resolvePlugins =
    {
      selectedPacks ? [ ],
      extraPlugins ? [ ],
    }:
    let
      enabled = unique (concatMap (p: packs.${p}.plugins) selectedPacks ++ extraPlugins);
      disabled = filter (p: !(elem p enabled) && !(elem p globalPlugins)) allPackPlugins;
    in
    {
      inherit enabled disabled;
    };

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

      pluginsCfg = resolvePlugins { inherit selectedPacks extraPlugins; };
      enableMap = builtins.listToAttrs (
        map (p: {
          name = p;
          value = true;
        }) pluginsCfg.enabled
      );
      disableMap = builtins.listToAttrs (
        map (p: {
          name = p;
          value = false;
        }) pluginsCfg.disabled
      );
      pluginsJson = toJSON (enableMap // disableMap);

      pluginsHook = lib.optionalString (pluginsCfg.enabled != [ ] || pluginsCfg.disabled != [ ]) ''
        mkdir -p .claude
        _sp_local=".claude/settings.local.json"
        _sp_plugins='${pluginsJson}'
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

      # MCP servers: write selected packs' mcpServers into repo-root .mcp.json
      # (Claude Code project-scope standard file). Same jq recursive-merge as
      # pluginsHook so user-added servers survive.
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
    skillsHook + pluginsHook + mcpHook;

  mkShellWithSkills =
    {
      selectedPacks ? [ ],
      extraSkills ? [ ],
      extraPlugins ? [ ],
      extraMcpServers ? { },
      ...
    }@args:
    let
      packHook = mkProjectShellHook {
        inherit
          selectedPacks
          extraSkills
          extraPlugins
          extraMcpServers
          ;
      };
      cleanArgs = removeAttrs args [
        "selectedPacks"
        "extraSkills"
        "extraPlugins"
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
    globalPlugins
    allPackPlugins
    resolveSkills
    resolvePlugins
    mkPackBundle
    mkProjectShellHook
    mkShellWithSkills
    ;
}
