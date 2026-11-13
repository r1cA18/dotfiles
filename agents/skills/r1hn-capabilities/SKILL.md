---
name: r1hn-capabilities
description: >-
  List, suggest and enable the owner's agent capabilities (skills, MCP servers, plugins, tools) through r1hn. Use when a task needs a skill or MCP server that is not loaded, when a session-start note suggests catalog entries for this project, or when the owner asks what is available. Always ask the owner before enabling anything. Also lists the command-line tools that are always on PATH.
---

# r1hn capabilities

One catalog, declared in the dotfiles (`agents/capabilities/catalog.nix`),
holds every skill, MCP server, plugin and tool. r1hn puts the baseline into
every client and account; other entries are enabled per project.

## Commands

```bash
r1hn capability list                 # every entry; --tier, --tag, --kind, --json
r1hn capability show ID              # one entry in full
r1hn capability suggest .            # catalog entries that match this project
r1hn capability enable ID --project .   # needs the owner's yes; see below
r1hn capability disable ID --project .
r1hn capability doctor               # entries out of line, items outside the catalog
```

`enable`, `disable` and `reset` go through the running r1hnd. Without
`--project` they change the tier everywhere; leave that to the owner.

## Ask first

- Never run `r1hn capability enable` on your own. Name the entry, say why it fits the task, and wait for the owner's yes
- After a yes, enable it for this project only: `r1hn capability enable ID --project .`
- A new skill is read at the next session start; an MCP server enabled for the project is passed when r1hn starts the next client. Say so
- Do not edit `.r1hn/capabilities.toml`, the client config files or the skills directories by hand
- Do not change an entry the owner set; r1hn refuses it from inside a session anyway

## Tools on PATH

These need no skill or server. Use them directly:

- `yt-dlp`, `ffmpeg`, `whisper-cli` (whisper.cpp): media download, conversion, local speech to text
- `markitdown`, `pandoc`: documents to Markdown and between formats
- `duckdb`, `sqlite3`: SQL over CSV, Parquet, JSON and SQLite files
- `ast-grep`, `rg`, `jq`: structural search and rewrite, text search, JSON
- `mmdc` (mermaid-cli), `d2`: render diagrams
- `gh`: GitHub
