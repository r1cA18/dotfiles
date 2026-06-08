---
name: project-init
description: Initialize or retrofit a project for this dotfiles agent workflow. Use when the user asks to run init, project init, create a flake, set up direnv, generate CLAUDE.md/AGENTS.md, or choose dotfiles skill packs for a repository.
---

# Project Init

Initialize the current repository with the dotfiles project workflow: Nix flake, direnv, agent docs, and skill packs.

## Workflow

1. Inspect the project before writing:
   - Read existing `flake.nix`, `.envrc`, `.gitignore`, `CLAUDE.md`, `AGENTS.md`.
   - Check manifests such as `package.json`, `bun.lock`, `Cargo.toml`, `go.mod`, `Package.swift`, `pyproject.toml`, `deno.json`, Remotion config, `.bib`, and Xcode files.
   - Identify languages, framework, package manager, build/test/lint/dev commands, and whether this is an empty project.

2. Select skill packs:
   - `web`: React, Next.js, Vue, Svelte, Astro, TypeScript UI, `.tsx`, `package.json` frontend deps.
   - `ios`: Swift, `Package.swift`, `.xcodeproj`, `.xcworkspace`, iOS/macOS app work.
   - `media`: Remotion, video/audio processing, FFmpeg workflows.
   - `research`: papers, `.bib`, thesis/report workflows.
   - `publishing`: blog/article/X publishing workflows.
   - `vault`: Obsidian vaults or personal knowledge bases.
   - If confidence is low or multiple packs are plausible, state the proposed packs and ask one concise question before editing.

3. Create or update `flake.nix`:
   - Preserve existing inputs, outputs, packages, shells, overlays, and comments when practical.
   - Add `dotfiles.url = "git+file:///Users/r1ca18/dotfiles";` if missing.
   - Prefer `dotfiles.lib.${system}.mkShellWithSkills` for the default dev shell.
   - Keep tool packages minimal and project-specific. Use Bun for JS/TS unless the repo already clearly uses another manager.

   Minimal shape for a new project:

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
           selectedPacks = [ ];
           buildInputs = with pkgs; [ ];
         };
       };
   }
   ```

4. Create or update `.envrc`:
   - Use `use flake`.
   - Preserve existing direnv exports unless they conflict with the Nix shell.

5. Create or update `.gitignore`:
   - Add missing entries only:
     - `.direnv`
     - `.claude/skills`
     - `.claude/settings.local.json`
     - `.codex/skills`
     - `result`

6. Create or update `CLAUDE.md` and `AGENTS.md`:
   - For existing projects, ground commands and conventions in real files.
   - `CLAUDE.md`: include project overview, key commands, architecture notes, project-specific conventions, and a pointer to global conventions.
   - `AGENTS.md`: cross-agent version under 50 lines with description, commands, and key conventions.
   - Do not overwrite meaningful existing instructions; merge surgically.

7. Verify:
   - Run `nix fmt` if available in the repo.
   - Run `nix flake show --all-systems` or a narrower `nix flake check` when appropriate.
   - If `.envrc` was created or changed, tell the user to run `direnv allow`.

## Output

Summarize files changed, selected packs, inferred commands, verification run, and any remaining manual step.
