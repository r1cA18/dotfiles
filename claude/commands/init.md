---
name: init
description: "Initialize project with CLAUDE.md, AGENTS.md, flake.nix, and .envrc"
argument-hint: "[project description or context]"
allowed-tools: "Bash,Read,Write,Edit,AskUserQuestion,Agent,Glob,Grep"
---

Initialize this project for Claude Code.
Shared workflow equivalent: `project-init` skill for Codex / cross-agent use.

## Step 1: Understand the project

- Read package.json, Cargo.toml, go.mod, Package.swift, pyproject.toml, etc.
- Check existing .claude/, flake.nix, .envrc, CLAUDE.md, AGENTS.md
- Identify language(s), framework(s), build system, and key commands
- Use $ARGUMENTS as additional context if provided
- If the project is empty and $ARGUMENTS is empty, ask what kind of project this is

## Step 2: Generate files

### flake.nix

Use plain Nix. Do not add agent skill pack wiring.

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

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

For existing projects, preserve existing inputs and configuration.

### .envrc

Create if missing:

```sh
use flake
```

### .gitignore

Append missing entries only:

```gitignore
.direnv
result
```

### CLAUDE.md / AGENTS.md

- Project overview
- Build/test/lint/dev commands
- Architecture notes
- Project-specific conventions
- Keep `AGENTS.md` cross-agent compatible and under 50 lines
- Do not overwrite meaningful existing instructions

## Step 3: Summary

Print files created/modified and next steps:

- `direnv allow` if `.envrc` was created
- `nix develop` to activate
- relevant build/test/lint commands
