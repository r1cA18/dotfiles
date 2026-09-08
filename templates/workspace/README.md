# Project workspace

This repository stores the repository list, shared agent instructions, and cross-repository notes.
Each checkout under `repos/` is an independent Git repository ignored by this parent repository.

## Start

Install Git and Bun using your environment's package manager, then run:

```sh
git clone <workspace-repository-url> product-workspace
cd product-workspace
./ws sync
./ws status
```

Nix and ghq are not required for the default `local` checkout mode.
If your team uses Nix, `nix develop` supplies the tools declared in `flake.nix`.
Commit `flake.lock` to pin their versions. Project runtimes still belong to each child repository.

## Manage repositories

```sh
./ws add https://github.com/example/product-web.git web
./ws add git@github.com:example/product-api.git api
./ws sync
./ws remove api
```

Replace the example URLs with your own repositories. `add` registers the URL in `repos.json`
and runs sync. The alias is optional and defaults to the repository name with dots replaced by hyphens.
If cloning fails, the entry is kept so that `./ws sync` can retry after you fix access.
`sync` clones missing repositories and checks existing origins without pulling or switching branches.
`remove` only unregisters the alias; its checkout and indexes remain on disk.
Commit the updated `repos.json` and ask teammates to run `./ws sync`.

HTTPS URLs, SSH URLs, and `host/owner/repo` identifiers are accepted. Use SSH or your Git
credential helper for authentication; do not embed tokens in URLs. Local filesystem URLs and
URLs containing an explicit port are not supported in the shared manifest.

## Work

```sh
./ws codex
./ws claude
git -C repos/web status
```

Each agent CLI must already be installed and authenticated on your machine.
`AGENTS.md` holds the product purpose and shared workflow; `CLAUDE.md` imports it.
Account profiles, credentials, and native sessions stay local.
Read each edited repository's instructions and run its own builds and tests.

Optional tools:

- `./ws rg -n 'pattern'` requires ripgrep
- `./ws index` and `./ws search 'query'` require indexion; the Nix shell provides the pinned version
- `./ws snapshot` records clean child revisions; `./ws verify` checks them without changing checkouts

Keep decisions in `docs/knowledge/` and progress in `docs/tasks/`.
Commit parent instructions and repository changes in their respective Git repositories.

## Existing ghq checkouts

Set `"checkout": "ghq"` in `workspace.json` before the first sync to use ghq checkouts
and links under `repos/`. This mode also requires ghq. Existing workspaces without
`workspace.json` retain the legacy ghq behavior. Changing modes does not migrate or overwrite
existing paths; create a new workspace to try another layout.
