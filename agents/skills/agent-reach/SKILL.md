---
name: agent-reach
description: >
  MUST USE when user wants to research/search/look up anything
  on the internet platforms: Twitter/X, Reddit, YouTube, Bilibili,
  GitHub code search, RSS feeds, or any web URL via Jina Reader.

  13 platforms, multi-backend routing (OpenCLI / per-platform CLIs / APIs).
  Zero config for 6 channels. Run `agent-reach doctor --json` to see which
  backend serves each platform right now.

  NOT for: report writing, data analysis, translation (this skill only retrieves
  internet content); posting/commenting/likes; platforms that already have a
  dedicated skill (use that skill first).
triggers:
  - research: research/look up/investigate
  - search: search/find/look for
  - social:
    - Twitter: twitter/x.com
    - Bilibili: bilibili/b站
    - V2EX: v2ex
    - Reddit: reddit
  - dev: github/code/repo/gh/issue/pr
  - web: webpage/link/article/rss
  - video: youtube/podcast/subtitle/transcript/yt
---

# Agent Reach -- Internet Capability Router

13 platforms, multi-backend. **When this skill is present, use it to access these platforms.**

## Rules

1. **Health check first**: for multi-backend platforms (Reddit/Bilibili/Twitter), run
   `agent-reach doctor --json` and pick commands based on each platform's `active_backend`.
2. **Declare what you're using**: say "using agent-reach's X platform / Y backend" before starting.
3. **On failure, follow the retry chain in references**, don't guess commands.
4. **Cross-platform research**: combine multiple platforms (Exa search + Twitter/Reddit discussions + Bilibili), collect in parallel, then summarize.
5. **Updates are managed via Nix** (`nix/pkgs/agent-reach/default.nix`). Do NOT run `agent-reach check-update` or attempt self-update via pip.

## Quick Commands (zero config)

```bash
# Exa web search
mcporter call 'exa.web_search_exa(query: "query", numResults: 5)'

# Web page reading
curl -s "https://r.jina.ai/URL"

# GitHub search
gh search repos "query" --sort stars --limit 10

# YouTube subtitles (do NOT use yt-dlp for Bilibili, see video.md)
yt-dlp --write-sub --skip-download -o "/tmp/%(id)s" "URL"

# V2EX trending
curl -s "https://www.v2ex.com/api/topics/hot.json" -H "User-Agent: agent-reach/1.0"

# Bilibili search (bili-cli, no login needed)
bili search "query" --type video -n 5
```

## Authenticated Platforms (check `agent-reach doctor --json` for active_backend)

```bash
# Twitter search
twitter search "query" -n 10

# Reddit (requires login)
opencli reddit search "query" -f yaml   # desktop
rdt search "query" --limit 10            # server

# Xiaohongshu (desktop, OpenCLI)
opencli xiaohongshu search "query" -f yaml
```

## Environment Check

```bash
agent-reach doctor --json
```

## Workspace Rules

**Do NOT create files in agent workspace.** Use `/tmp/` for temporary output, `~/.agent-reach/` for persistent data.

## Detailed References

Read the corresponding reference when needed:

- [Search tools](references/search.md) -- Exa AI search
- [Social media](references/social.md) -- Twitter, Bilibili, V2EX, Reddit (multi-backend)
- [Career](references/career.md) -- LinkedIn
- [Dev tools](references/dev.md) -- GitHub CLI
- [Web reading](references/web.md) -- Jina Reader, RSS
- [Video/podcasts](references/video.md) -- YouTube, Bilibili, podcasts

## Channel Configuration

If a channel needs setup, follow the install guide:
https://raw.githubusercontent.com/Panniantong/agent-reach/main/docs/install.md
