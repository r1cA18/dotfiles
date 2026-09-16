# dotfiles ドキュメント

## 概要

macOS/Linux用のdotfiles。共通user設定はHome Managerで管理する。
macOS systemはnix-darwinで管理し、Ubuntu systemはAnsibleで管理する。

## ドキュメント一覧

### アーキテクチャ

- [architecture.md](architecture.md) - 全体構造、ファイル配置、編集ガイド
- [agent-platforms.md](agent-platforms.md) - Agent資産のsource of truthと製品間の管理境界

### ガイド

- [management-rules.md](guides/management-rules.md) - **管理ルール（必読）**
- [nix-npm-packages.md](guides/nix-npm-packages.md) - Node系CLIをNixで固定管理
- [agent-workspace-tools.md](guides/agent-workspace-tools.md) - AI agent作業環境のツール方針
- [ccspace.md](guides/ccspace.md) - Claude Code・Codexのaccount切り替え（ccspace）
- [agent-hooks.md](guides/agent-hooks.md) - hook登録とtask状態の保存
- [agent-session-handoff.md](guides/agent-session-handoff.md) - account・製品をまたぐ作業の引き継ぎ
- [multi-repo-workspaces.md](guides/multi-repo-workspaces.md) - 複数repoの作成・追加・一括cloneと共有
- [japanese-writing.md](guides/japanese-writing.md) - 会話・文書・UIの日本語表記
- [claude-code-gpt.md](guides/claude-code-gpt.md) - GPT backend版Claude CodeとProxy管理
- [alias-auto-help.md](guides/alias-auto-help.md) - 選択式ヘルプとrepo・workspace移動（h/hp/hv/devg/wsg）
- [testing.md](guides/testing.md) - ローカル回帰テストとNix統合テスト・CI
- [guide-macos.md](../nix/docs/guide-macos.md) - macOS初回構築と運用
- [guide-ubuntu.md](../nix/docs/guide-ubuntu.md) - Ubuntu初回構築と運用
- [server/README.md](../server/README.md) - homelab移行とservice運用

### Nix運用

- [nix/docs/guide.md](../nix/docs/guide.md) - 共通運用ガイド
- [nix/docs/cheatsheet.md](../nix/docs/cheatsheet.md) - コマンドチートシート

### 棚卸し

- [開発環境の見直し](research/development-environment-review-2026-09.md) - 全体判断と改善順序
- [Agent資産台帳](research/agent-assets-audit-2026-09.md) - skills・plugins・profile差分
- [Mac/Linux差分](research/platform-parity-2026-09.md) - 宣言と稼働状態の管理境界
- [基礎skillの選定](research/shared-foundation-skills-2026-09.md) - 公式優先の採否とlicense
- [実装進捗](research/environment-rollout-2026-09-07.md) - workspace・profile・hookの検証と残作業

## クイックリファレンス

### よく使うコマンド

| コマンド       | 説明                           |
| -------------- | ------------------------------ |
| `dr`           | Nixをリビルド                  |
| `h`            | 対話環境でヘルプ選択           |
| `hp workspace` | workspaceヘルプを選択          |
| `hv`           | エイリアス一覧（コマンド表示） |
| `wsg`          | workspaceを選んで移動          |
| `dot`          | dotfilesディレクトリへ移動     |
| `nx`           | flake ルートへ移動             |

`dr`はmacOSではnix-darwin全体を適用し、UbuntuではHome Managerだけを適用する。
Ubuntu system設定も含める場合は`nix run ~/dotfiles#server-apply`を使う。

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
