# dotfiles

## 最初に読むこと

**このリポジトリを変更する前に、必ず `docs/architecture.md` を読むこと。**
**agent 関連の運用方針は `docs/agent-platforms.md` も読むこと。**

このファイルには以下が記載されている：

- ディレクトリ構造と各ファイルの役割
- 何を追加/変更したい時にどのファイルを編集するか
- シンボリックリンクの管理方法
- OS分岐パターン

## このリポジトリでの agent 運用

- 共有 instruction は `agents/INSTRUCTIONS.md` + `agents/rules/`
- project-specific な運用はこの `CLAUDE.md` と `docs/agent-platforms.md` に置く
- `Claude Code` 専用の hooks / plugin / runtime state と、`Codex` 専用の agents / config は分離して管理する
- 再利用したい workflow は `skills/` に置き、片方の製品専用機能に閉じ込めない

## 実務ルール

- `docs/architecture.md` を読んでから編集する
- Nix 環境ではグローバルインストール禁止。`comma` か `nix run` / `nix shell` を使う
- Web 検索とページ取得は組み込みの Web ツールを使う
- ブラウザ操作は `agent-browser` 優先
- テストや build がある変更は、変更前後で検証する
- `Codex` では `.codex/agents/`、`Claude Code` では `claude/agents/` を使う
- 共通化したい skill は `skills/` を source of truth にする

## 概要

macOS/Linux用のdotfiles。Nix (nix-darwin + home-manager) で管理。

## クイックリファレンス

| やりたいこと          | 編集ファイル                                       |
| --------------------- | -------------------------------------------------- |
| CLIツール追加         | `nix/home-manager/programs/packages.nix`           |
| GUIアプリ追加 (macOS) | `nix/darwin/configuration.nix` の `homebrew.casks` |
| エイリアス追加        | `nix/home-manager/programs/zsh.nix`                |
| 環境変数/PATH         | `nix/home-manager/programs/packages.nix`           |
| Git設定               | `nix/home-manager/programs/git.nix`                |
| Neovim設定            | `nvim/` ディレクトリ                               |
| Ghostty設定           | `ghostty/config`                                   |
| Karabiner設定         | `karabiner/karabiner.json`                         |
| Agent Skills管理      | `nix/home-manager/programs/agent-skills.nix`       |
| スキル追加/編集       | `skills/` ディレクトリ                             |
| グローバルルール      | `claude/rules/` ディレクトリ                       |
| フック                | `claude/hooks/` ディレクトリ                       |
| Codex設定             | `codex/config.toml`                                |
| グローバル指示        | `agents/INSTRUCTIONS.md` + `agents/rules/`         |

## シンボリックリンク設定済み

以下は home-manager により自動でシンボリックリンクが設定される：

- `nvim/` -> `~/.config/nvim`
- `ghostty/config` -> `~/Library/Application Support/com.mitchellh.ghostty/config`
- `karabiner/karabiner.json` -> `~/.config/karabiner/karabiner.json`
- `skills/` -> `~/.claude/skills/` + `~/.codex/skills/` (agent-skills-nix 経由で同期)
- `codex/config.toml` -> `~/.codex/config.toml`

## ビルド

```bash
dr  # nh darwin switch ~/dotfiles -H <hostname> (macOS) / nh home switch ~/dotfiles -c <user>@linux (Linux)
```

## 詳細ドキュメント

- `docs/architecture.md` - 構造と開発ガイド（Claude向け）
- `docs/agent-platforms.md` - Codex / Claude Code の役割分担と移行方針
- `nix/docs/guide.md` - 共通運用ガイド
- `nix/docs/cheatsheet.md` - コマンドチートシート
