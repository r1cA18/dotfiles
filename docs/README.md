# dotfiles ドキュメント

## 概要

macOS/Linux用のdotfiles。Nix (nix-darwin + home-manager) で管理。

## ドキュメント一覧

### アーキテクチャ

- [architecture.md](architecture.md) - 全体構造、ファイル配置、編集ガイド

### ガイド

- [management-rules.md](guides/management-rules.md) - **管理ルール（必読）**
- [nix-npm-packages.md](guides/nix-npm-packages.md) - Node系CLIをNixで固定管理
- [alias-auto-help.md](guides/alias-auto-help.md) - エイリアス自動ヘルプシステム（h/hv）

### Nix運用

- [nix/docs/guide.md](../nix/docs/guide.md) - 共通運用ガイド
- [nix/docs/cheatsheet.md](../nix/docs/cheatsheet.md) - コマンドチートシート

## クイックリファレンス

### よく使うコマンド

| コマンド | 説明                           |
| -------- | ------------------------------ |
| `dr`     | Nixをリビルド                  |
| `h`      | エイリアス一覧（簡潔）         |
| `hv`     | エイリアス一覧（コマンド表示） |
| `dot`    | dotfilesディレクトリへ移動     |
| `nx`     | flake ルートへ移動             |

### 編集場所

| やりたいこと          | 編集ファイル                                            |
| --------------------- | ------------------------------------------------------- |
| CLIツール追加         | `nix/home-manager/programs/packages.nix`                |
| Node系CLI追加         | `nix/pkgs/` と `nix/home-manager/programs/packages.nix` |
| GUIアプリ追加 (macOS) | `nix/darwin/configuration.nix`の`homebrew.casks`        |
| エイリアス追加        | `nix/home-manager/programs/zsh.nix`                     |
| `nh` 設定             | `nix/home-manager/programs/nh.nix`                      |
| 環境変数/PATH         | `nix/home-manager/programs/packages.nix`                |
| Git設定               | `nix/home-manager/programs/git.nix`                     |
| Neovim設定            | `nvim/`ディレクトリ                                     |
| Ghostty設定           | `nix/home-manager/programs/ghostty.nix`                 |
| Karabiner設定         | `karabiner/karabiner.json`                              |
