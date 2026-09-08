# dotfiles

## 最初に読むこと

Nix構成・ファイル配置・symlink・OS分岐を変更するときは`docs/architecture.md`の関連節を参照する。
agent資産の配布・製品間の境界・運用を変更するときは`docs/agent-platforms.md`も参照する。

このファイルには以下が記載されている：

- ディレクトリ構造と各ファイルの役割
- 何を追加/変更したい時にどのファイルを編集するか
- シンボリックリンクの管理方法
- OS分岐パターン

## このリポジトリでの agent 運用

- 共有 instruction は `agents/INSTRUCTIONS.md` + `agents/rules/`
- project-specific な運用はこの `AGENTS.md` と `docs/agent-platforms.md` に置く
- `Claude Code` 専用の hooks / plugin / runtime state と、`Codex` 専用の agents / config は分離して管理する
- 再利用したい workflow は `agents/skills/` に置き、片方の製品専用機能に閉じ込めない

## 実務ルール

Codexは当面サブエージェントを使わない。探索・実装・reviewを主agentで行い、他CLIやbridgeを経由した委譲もしない。詳細は`codex/rules/orchestration.md`を参照する。所有者が明示的に方針を変更するまで継続する。

- Nix 環境ではグローバルインストール禁止。`comma` か `nix run` / `nix shell` を使う
- Web 検索とページ取得は組み込みの Web ツールを使う
- ブラウザ操作は `agent-browser` 優先
- 検証範囲は変更の影響に合わせる。不具合は可能なら変更前に再現し、修正後に関連する検証を実行する
- `Codex` では `.codex/agents/`、`Claude Code` では `claude/agents/` を使う
- 共通化したい skill は `agents/skills/` を source of truth にする

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
| Ghostty設定           | `nix/home-manager/programs/ghostty.nix`            |
| Karabiner設定         | `karabiner/karabiner.json`                         |
| Agent Skills管理      | `nix/home-manager/programs/agent-skills.nix`       |
| スキル追加/編集       | `agents/skills/` ディレクトリ                      |
| Claude ルール         | `claude/rules/` ディレクトリ                       |
| Claude フック         | `claude/hooks/` ディレクトリ                       |
| Codex設定             | `nix/home-manager/programs/codex.nix`              |
| グローバル指示        | `agents/INSTRUCTIONS.md` + `agents/rules/`         |

## シンボリックリンク設定済み

以下は home-manager により自動でシンボリックリンクが設定される：

- `nvim/` -> `~/.config/nvim`
- `karabiner/karabiner.json` -> `~/.config/karabiner/karabiner.json`
- `agents/skills/` -> `~/.claude/skills/` + `~/.codex/skills/` (agent-skills-nix 経由で同期)
- Ghostty の設定は `nix/home-manager/programs/ghostty.nix` から生成される
- `~/.codex/config.toml` は `nix/home-manager/programs/codex.nix` から生成される

## ビルド

```bash
dr  # macOS全体 / LinuxのHome Managerだけを適用
nix run ~/dotfiles#homelab-apply  # Linuxのsystem設定とHome Managerを一括適用
```

## 詳細ドキュメント

- `docs/architecture.md` - 構造と開発ガイド（Codex向け）
- `docs/agent-platforms.md` - Codex / Claude Code の役割分担と移行方針
- `nix/docs/guide.md` - 共通運用ガイド
- `nix/docs/cheatsheet.md` - コマンドチートシート
