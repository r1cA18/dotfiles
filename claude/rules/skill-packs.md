# Skill Packs

Skills and tool-specific plugins are managed per-project via Nix devShells.
Global skills are always loaded. Pack skills are opt-in per project.

## Global Skills (always loaded)

agent-browser, pdf, xlsx, post-review, skill-builder, skill-auditor, autonomous-dev, frontend-design, baseline-ui, ui-skills, web-design-guidelines, difit, difit-review, knowledge-extract

## Packs

| Pack | Skills | Claude plugins | Codex plugins |
|------|--------|----------------|---------------|
| ios | swift-dev-toolkit, ios-device-build | swift-lsp | - |
| web | vercel-react-best-practices | typescript-lsp | - |
| media | video-editing, remotion-best-practices | - | - |
| research | typst-author, touying-author | academic-research-skills | - |
| publishing | x-article-publisher, x-research | - | - |
| vault | session-documentation, design-capture, forms-archive | - | - |

## Usage in Project flake.nix

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    dotfiles.url = "git+file:///Users/r1ca18/dotfiles";
  };
  outputs = { nixpkgs, dotfiles, ... }:
    let system = "aarch64-darwin";
    in {
      devShells.${system}.default =
        dotfiles.lib.${system}.mkShellWithSkills {
          selectedPacks = [ "web" ];
          # extraSkills = [ "video-editing" ];
          # extraClaudePlugins = [ "pr-review-toolkit@claude-plugins-official" ];
          # extraCodexPlugins = [ "some-plugin@some-marketplace" ];
        };
    };
}
```

`nix develop` (or direnv `use flake`) activates pack skills in `.claude/skills/`
and `.codex/skills/`. Claude plugin overrides go to `.claude/settings.local.json`.
Codex plugin declarations are install requests: when `codex` is available, the
project shellHook adds declared marketplaces and runs `codex plugin add`, which
updates the Codex user config/cache.

## Adding New Skills/Plugins

### Skill (SKILL.md only)

1. Create `~/dotfiles/agents/skills/<name>/SKILL.md`
2. Global: add to `agent-skills.nix` enable list
3. Pack: add to `nix/lib/skill-packs.nix` pack definition
4. Run `dr`

### Claude Plugin (commands + agents + hooks)

1. `claude plugin install <name> --scope user`
2. Add to `claude-code.nix` enabledPlugins only if it is global
3. Pack plugin: add to `nix/lib/skill-packs.nix` as `claudePlugins`
4. Run `dr`

### Codex Plugin

1. Prefer a flake input or a stable local marketplace source
2. Global plugin: add marketplace + enabled plugin to `nix/home-manager/programs/codex.nix`
3. Pack plugin: add to `nix/lib/skill-packs.nix` as `codexPlugins` and add `codexMarketplaces` if needed
4. Run `dr`

## Files

| File | Purpose |
|------|---------|
| `nix/lib/skill-packs.nix` | Pack definitions + helper functions |
| `nix/home-manager/programs/agent-skills.nix` | Global skill selection |
| `nix/home-manager/programs/claude-code.nix` | Global plugin selection |
| `nix/home-manager/programs/codex.nix` | Global Codex plugin and marketplace selection |
