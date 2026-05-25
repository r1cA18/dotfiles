# Skill Packs

Skills and plugins are managed per-project via Nix devShells.
Global skills are always loaded. Pack skills are opt-in per project.

## Global Skills (always loaded)

agent-browser, pdf, xlsx, post-review, skill-builder, skill-auditor, autonomous-dev, difit, difit-review

## Packs

| Pack | Skills | Plugins |
|------|--------|---------|
| ios | swift-dev-toolkit, ios-device-build | swift-lsp |
| web | frontend-design, baseline-ui, ui-skills, vercel-react-best-practices, web-design-guidelines | typescript-lsp, frontend-design, playground |
| media | video-editing, remotion-best-practices | - |
| research | - | academic-research-skills |
| publishing | x-article-publisher, x-research | - |
| vault | knowledge-extract, session-documentation, design-capture, forms-archive | - |

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
          # extraPlugins = [ "pr-review-toolkit@claude-plugins-official" ];
        };
    };
}
```

`nix develop` (or direnv `use flake`) activates pack skills in `.claude/skills/`
and writes plugin overrides to `.claude/settings.local.json`.

## Adding New Skills/Plugins

### Skill (SKILL.md only)

1. Create `~/dotfiles/agents/skills/<name>/SKILL.md`
2. Global: add to `agent-skills.nix` enable list
3. Pack: add to `nix/lib/skill-packs.nix` pack definition
4. Run `dr`

### Plugin (commands + agents + hooks)

1. `claude plugin install <name> --scope user`
2. Add to `claude-code.nix` enabledPlugins
3. Global plugin: done
4. Pack plugin: add to `nix/lib/skill-packs.nix` pack definition + `packPlugins`
5. Run `dr`

## Files

| File | Purpose |
|------|---------|
| `nix/lib/skill-packs.nix` | Pack definitions + helper functions |
| `nix/home-manager/programs/agent-skills.nix` | Global skill selection |
| `nix/home-manager/programs/claude-code.nix` | Global plugin selection |
