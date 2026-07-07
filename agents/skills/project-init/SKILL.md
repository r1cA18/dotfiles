---
name: project-init
description: Initialize or retrofit a project for this dotfiles agent workflow. Use when the user asks to run init, project init, create a flake, set up direnv, or generate CLAUDE.md/AGENTS.md for a repository.
---

# Project Init

Initialize the current repository with the dotfiles project workflow: Nix flake, direnv, and agent docs.

## Workflow

1. Inspect the project before writing:
   - Read existing `flake.nix`, `.envrc`, `.gitignore`, `CLAUDE.md`, `AGENTS.md`.
   - Check manifests such as `package.json`, `bun.lock`, `Cargo.toml`, `go.mod`, `Package.swift`, `pyproject.toml`, `deno.json`, Remotion config, `.bib`, and Xcode files.
   - Identify languages, framework, package manager, build/test/lint/dev commands, and whether this is an empty project.

2. Decide solo vs shared repo (see "Repo mode" below), then create or update `flake.nix`:
   - Solo/personal repo: commit `flake.nix`.
   - Shared repo: do NOT create a committed `flake.nix`; follow "Repo mode".
   - Preserve existing inputs, outputs, packages, shells, overlays, and comments when practical.
   - Use plain Nix devShells. Add a `dotfiles` input only when the project explicitly needs a dotfiles helper.
   - Keep tool packages minimal and project-specific. Use Bun for JS/TS unless the repo already clearly uses another manager.

   Minimal shape for a new project:

   ```nix
   {
     inputs = {
       nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
     };

     outputs =
       { nixpkgs, ... }:
       let
         system = "aarch64-darwin";
         pkgs = nixpkgs.legacyPackages.${system};
       in
       {
         devShells.${system}.default = pkgs.mkShellNoCC {
           buildInputs = with pkgs; [ ];
         };
       };
   }
   ```

3. Create or update `.envrc`:
   - Use `use flake`.
   - Preserve existing direnv exports unless they conflict with the Nix shell.

4. Create or update `.gitignore`:
   - Add missing entries only:
     - `.direnv`
     - `result`

5. Create or update `CLAUDE.md` and `AGENTS.md`:
   - For existing projects, ground commands and conventions in real files.
   - `CLAUDE.md`: include project overview, key commands, architecture notes, project-specific conventions, and a pointer to global conventions.
   - `AGENTS.md`: cross-agent version under 50 lines with description, commands, and key conventions.
   - Do not overwrite meaningful existing instructions; merge surgically.

6. Verify:
   - Run `nix fmt` if available in the repo.
   - Run `nix flake show --all-systems` or a narrower `nix flake check` when appropriate.
   - If `.envrc` was created or changed, tell the user to run `direnv allow`.

## Repo mode

Decide before writing any Nix files. Ask the user if it is unclear.

- Solo/personal repo (you own it, no non-Nix collaborators) -> commit `flake.nix` + `.envrc` as in the workflow above.
- Shared/collaborative repo (teammates may not use Nix) -> shared-repo mode: do NOT commit `flake.nix`. Keep the personal dev env in git-ignored files only, so teammates never see Nix artifacts.

### Shared-repo mode

Pick one. Never `git add flake.nix` in a shared repo.

- Option A — local uncommitted flake (default; use when the project needs a real toolchain):
  1. Write `flake.nix` + `.envrc` (`use flake`) as usual.
  2. Add both to `.git/info/exclude` (repo-local, not committed). Do NOT add them to the shared `.gitignore`, which is committed.
  3. `direnv allow`.

- Option B — point `.envrc` at the dotfiles flake (use when you only need the dotfiles baseline, not a project toolchain):
  1. Create only `.envrc` (no `flake.nix`) containing `use flake ~/dotfiles#<shell>`.
  2. Add `.envrc` to `.git/info/exclude`.
  3. `direnv allow`.
  - Reality check: the dotfiles flake currently exposes only `devShells.<system>.default` (treefmt + pre-commit hooks) and the `lib.<system>.mkShellWithSkills` helper. There is no per-language shell, so `~/dotfiles#default` gives the dotfiles formatting/hooks shell, not Node/Python/Swift tooling. If the project needs a language toolchain, use Option A.

In both options, `.gitignore` stays untouched by the personal env; exclusion lives in `.git/info/exclude`.

## Output

Summarize files changed, inferred commands, verification run, and any remaining manual step.
Also state the chosen repo mode (solo vs shared) and, for shared mode, which files were added to `.git/info/exclude`.
