---
name: firecrawl-cli-installation
description: |
  Install the official Firecrawl CLI and handle authentication.
  Package: https://www.npmjs.com/package/firecrawl-cli
  Source: https://github.com/firecrawl/cli
  Docs: https://docs.firecrawl.dev/sdks/cli
---

# Firecrawl CLI Installation

## Provisioning

```bash
firecrawl --version
```

この環境では `firecrawl-cli` は Nix で provision する。
CLI が無い場合は `dr` を実行して同期する。

## Skills

```bash
agent-skill-path firecrawl
```

skills はこのリポジトリの `skills/firecrawl*` を agent-skills-nix 経由で同期する。

## Verify

```bash
firecrawl --status
```

## Authentication

Authenticate using the built-in login flow:

```bash
firecrawl login --browser
```

This opens the browser for OAuth authentication. Credentials are stored securely by the CLI.

### If authentication fails

Ask the user how they'd like to authenticate:

1. **Login with browser (Recommended)** - Run `firecrawl login --browser`
2. **Enter API key manually** - Run `firecrawl login --api-key "<key>"` with a key from firecrawl.dev

### Command not found

If `firecrawl` is not found after installation:

1. `dr` を実行して Home Manager を再適用
2. `which firecrawl` で PATH を確認
3. `nix build ~/dotfiles/nix#firecrawl-cli` で package 単体ビルドを確認
