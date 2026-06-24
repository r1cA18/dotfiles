# Development Environment

## Nix

- Manage persistent tools through `~/dotfiles/`
- Do not install global packages with npm pip Homebrew Cargo Go or RubyGems
- Prefer `, <cmd>` for temporary CLI use
- Use `nix run` or `nix shell` when comma is not sufficient
- Use Bun for JavaScript and TypeScript unless the project requires another runtime

## Repository Instructions

- Read project-local `AGENTS.md` and `CLAUDE.md` files before editing
- Read required architecture documents before changing a repository
- Treat project-local instructions as higher priority than these global rules
