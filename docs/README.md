# dotfiles ドキュメント

## 概要

macOS/Linux用のdotfiles。Nix (nix-darwin + home-manager) で管理。

## ドキュメント一覧

### アーキテクチャ

- [architecture.md](architecture.md) - 全体構造、ファイル配置、編集ガイド

### ガイド

- [nix-npm-packages.md](guides/nix-npm-packages.md) - npmパッケージをbunで宣言的に管理
- [alias-auto-help.md](guides/alias-auto-help.md) - エイリアス自動ヘルプシステム（h/hv）

### Nix運用

- [nix/docs/guide.md](../nix/docs/guide.md) - 共通運用ガイド
- [nix/docs/cheatsheet.md](../nix/docs/cheatsheet.md) - コマンドチートシート

## クイックリファレンス

### よく使うコマンド

| コマンド | 説明 |
|---------|------|
| `dr` | Nixをリビルド |
| `h` | エイリアス一覧（簡潔） |
| `hv` | エイリアス一覧（コマンド表示） |
| `dot` | dotfilesディレクトリへ移動 |
| `nx` | nix設定ディレクトリへ移動 |

### 編集場所

| やりたいこと | 編集ファイル |
|-------------|-------------|
| CLIツール追加 | `nix/home-manager/programs/packages.nix` |
| npmパッケージ追加 | `packages.nix`の`globalNpmPackages` |
| GUIアプリ追加 (macOS) | `nix/darwin/configuration.nix`の`homebrew.casks` |
| エイリアス追加 | `nix/home-manager/programs/zsh.nix` |
| 環境変数/PATH | `nix/home-manager/programs/packages.nix` |
| Git設定 | `nix/home-manager/programs/git.nix` |
| Neovim設定 | `nvim/`ディレクトリ |
| Ghostty設定 | `ghostty/config` |
| Karabiner設定 | `karabiner/karabiner.json` |
