# dotfiles

## 最初に読むこと

**このリポジトリを変更する前に、必ず `docs/architecture.md` を読むこと。**

このファイルには以下が記載されている：

- ディレクトリ構造と各ファイルの役割
- 何を追加/変更したい時にどのファイルを編集するか
- シンボリックリンクの管理方法
- OS分岐パターン

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
| グローバル指示        | `shared/GLOBAL_INSTRUCTIONS.md`                    |

## シンボリックリンク設定済み

以下は home-manager により自動でシンボリックリンクが設定される：

- `nvim/` -> `~/.config/nvim`
- `ghostty/config` -> `~/Library/Application Support/com.mitchellh.ghostty/config`
- `karabiner/karabiner.json` -> `~/.config/karabiner/karabiner.json`
- `skills/` -> `~/.claude/skills/` + `~/.codex/skills/` (agent-skills-nix 経由で同期)
- `codex/config.toml` -> `~/.codex/config.toml`

## ビルド

```bash
dr  # darwin-rebuild switch (macOS) / home-manager switch (Linux)
```

## 詳細ドキュメント

- `docs/architecture.md` - 構造と開発ガイド（Claude向け）
- `nix/docs/guide.md` - 共通運用ガイド
- `nix/docs/cheatsheet.md` - コマンドチートシート
