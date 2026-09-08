---
name: indexion-workspace
description: Explore related repositories and shared project knowledge with a multi-repository workspace and local indexion search. Use for cross-repository orientation, code search, and knowledge maintenance.
---

# Cross-Repository Exploration

When a workspace contains `repos.json` and `ws`, start with `./ws status` and
read its `AGENTS.md`, `docs/knowledge`, and relevant `docs/tasks` entry.
Read each edited repository's instructions separately; additional write roots
do not imply that the instructions were loaded.

Choose the smallest useful search:

- Known identifier or text: `./ws rg -n 'pattern'`
- Code and registered wiki knowledge by relevance: `./ws index`, then `./ws search 'authentication token refresh'`
- Initial structural overview: `./ws orient 'change authentication token refresh'`
- Repeated function-purpose search: `./ws index`, then `./ws query 'refresh authentication token'`

The workspace wrapper forces local TF-IDF for search and digest. Do not switch
to external embedding providers without authorization to send the source.
Results are navigation hints, not proof of ownership, dependency resolution,
or semantic equivalence. Verify in source and run the affected repositories'
tests. Indexion is not a substitute for ripgrep or a language server.

Use stable repository-relative paths in shared notes, not machine-specific
absolute paths. Keep authoritative decisions in `docs/knowledge`; optional
indexion wiki pages may derive from these notes with source provenance.
Cache directories and vector indexes stay local. Rebuild after moving the
workspace or changing repository membership.

`search` aggregates independent repository digest queries and the registered
workspace wiki; it is not a single globally ranked index of every text file.
Read ordinary `docs/knowledge` notes directly or use ripgrep. Register selected
notes with `indexion wiki pages add` when wiki search is useful.

For direct CLI use, check the installed command's `--help`. The dotfiles
package pins indexion and its KGF language definitions together. Upstream
indexion-skills can describe commands newer than the installed release.
Do not install its mutable global plugin as a second overlapping copy.
