---
name: init
description: "Initialize project with CLAUDE.md, AGENTS.md, flake.nix (with skill packs), and .envrc"
argument-hint: "[project description or context]"
allowed-tools: "Bash,Read,Write,Edit,AskUserQuestion,Agent,Glob,Grep"
---

Initialize this project for Claude Code with skill packs.
If $ARGUMENTS is provided, use it as context for pack selection and project understanding.
Shared workflow equivalent: `project-init` skill for Codex / cross-agent use.

## Step 1: Understand the project

Two cases:

**Case A: Existing project (files already exist)**
Analyze the codebase:
- Read package.json, Cargo.toml, go.mod, Package.swift, pyproject.toml, etc.
- Check existing .claude/, flake.nix, .envrc
- Identify language(s), framework(s), build system
- Use $ARGUMENTS as additional context if provided

**Case B: New/empty project**
Use $ARGUMENTS to understand what the user wants to build.
If $ARGUMENTS is empty, ask:
- "What kind of project? (e.g., React web app, iOS app, Python CLI, etc.)"

## Step 2: Select skill packs

Available packs (~/dotfiles/nix/lib/skill-packs.nix):

| Pack | Skills | Plugins | Auto-select when |
|------|--------|---------|-----------------|
| ios | swift-dev-toolkit, ios-device-build | swift-lsp | .swift files, Package.swift, Xcode project |
| web | frontend-design, baseline-ui, ui-skills, vercel-react-best-practices, web-design-guidelines | typescript-lsp, frontend-design, playground | package.json with react/next/vue/svelte, .tsx files |
| media | video-editing, remotion-best-practices | - | Remotion config, video processing scripts |
| research | - | academic-research-skills | Academic papers, .bib files, research docs |
| publishing | x-article-publisher, x-research | - | Blog/article content, X publishing |
| vault | knowledge-extract, session-documentation, design-capture, forms-archive | - | Obsidian vault, knowledge base |

**Auto-selection rules:**
- If package.json has react/next.js/vue/svelte -> pre-select `web`
- If .swift or .xcodeproj exists -> pre-select `ios`
- If $ARGUMENTS mentions "research"/"paper"/"thesis" -> pre-select `research`
- If remotion config exists -> pre-select `media`
- Always consider $ARGUMENTS for additional context

Present the selection with AskUserQuestion (multiSelect):
- Pre-selected packs based on analysis
- Let user add/remove

Then ask about extras (only if relevant):
- extraSkills: individual skills not in any pack
- extraClaudePlugins: Claude Code plugins not covered by packs
- extraCodexPlugins: Codex plugins not covered by packs

## Step 3: Generate files

### 3a. flake.nix

If flake.nix doesn't exist, create:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    dotfiles.url = "git+file:///Users/r1ca18/dotfiles";
  };
  outputs =
    { nixpkgs, dotfiles, ... }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = dotfiles.lib.${system}.mkShellWithSkills {
        selectedPacks = [ SELECTED_PACKS ];
        # extraSkills = [ ];
        # extraClaudePlugins = [ ];
        # extraCodexPlugins = [ ];
        # buildInputs = with pkgs; [ ];
      };
    };
}
```

If flake.nix already exists:
- Add `dotfiles` input if missing
- Add/update devShell with mkShellWithSkills if not present
- Preserve existing inputs and configuration

### 3b. .envrc

Create if not exists:
```
use flake
```

### 3c. .gitignore additions

Append if not already present:
```
.direnv
.claude/skills
.claude/settings.local.json
.codex/skills
result
```

### 3d. CLAUDE.md

Analyze the project and generate:
- Project overview (1-2 sentences)
- Key commands (build, test, lint, dev server)
- Architecture notes (directory structure, key patterns)
- Code conventions specific to this project
- End with: "Global conventions: see ~/.claude/rules/"

For existing projects: read actual build configs, test commands, CI config.
For new projects: scaffold based on $ARGUMENTS and selected packs.

### 3e. AGENTS.md

Cross-agent compatible (Codex, Cursor, Copilot also read this):
- Project description
- Build/test/lint commands
- Key conventions
- Under 50 lines

## Step 4: Summary

Print:
1. Files created/modified
2. Selected packs and what they provide
3. Next steps:
   - `direnv allow` (if .envrc was created)
   - `nix develop` to activate
   - `git add flake.nix .envrc CLAUDE.md AGENTS.md`
