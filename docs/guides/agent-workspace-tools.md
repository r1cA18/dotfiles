---
title: "AI agent作業環境のツール方針"
created: 2026-08-19
type: guide
tags: [agent-workspace, aerospace, herdr, raycast, hammerspoon]
---

# AI agent作業環境のツール方針

## 概要

AI coding agentを複数動かすためのterminal・window管理・launcherの責務を定義する。
keybindは実際の利用で必要性を確認してから追加する。

## 現在の構成

| ツール             | 担当                                  | 管理方法                          |
| ------------------ | ------------------------------------- | --------------------------------- |
| Ghostty            | terminal windowの表示・描画           | Homebrew cask + Home Manager設定  |
| Herdr              | agentのworkspace・tab・pane・状態表示 | Nix flake input                   |
| AeroSpace          | macOS全体のwindow配置・workspace移動  | Homebrew cask                     |
| Raycast            | command palette・検索・ツール起動     | Homebrew cask                     |
| Karabiner-Elements | keyboard remap                        | Home Managerからdotfilesをsymlink |
| Hammerspoon        | gestureと条件付きautomation           | 未導入                            |

## 導入済みの決定

### Antigravity CLI

Google公式installerで`~/.local/bin/agy`へ導入する。自己更新するnative binaryのためNix storeには置かない。`~/.local/bin`はHome ManagerでPATHに含め、Home Managerのactivation (`setupAntigravity`) により `dr` 時に自動インストール、`update-all` (`update-antigravity`) で最新へ更新する。

### Herdr

公式flakeのstable releaseをinputとして固定し、macOS/Linuxの共通packageに追加する。`herdr`はagent用のpane・tab・workspace管理だけを担当する。

CodexとClaude Codeのintegration installerは、設定ファイルを書き換える可能性がある。Codex設定はNixから再生成するため、必要なintegration設定は内容を確認してから宣言的に管理する。

### AeroSpace

公式推奨のHomebrew cask `nikitabobko/tap/aerospace`で導入する。初期設定は追加しない。標準のwindow管理・workspace操作を使い、日常作業で必要になった操作だけを後から設定へ昇格させる。

## 保留した設定

### Keybind

動画で紹介されたdirect keybindはすぐに追加しない。Ghostty、Herdr、AeroSpaceがそれぞれkeybindを持つため、先に素の操作を使って責務と頻度を確認する。

特に`Cmd+Q`と`Cmd+W`はmacOSの終了・windowを閉じる操作と衝突しやすいため、Herdrのtab移動には使わない。

`continue`の入力自動化も保留する。導入する場合はGhosttyを前面にしたときだけ有効にし、文字入力だけに留めてEnterは手動で押す。

### Hammerspoon

HammerspoonはAeroSpaceやKarabinerの代替にしない。次のような他ツールで完結しないautomationが必要になったときだけ導入する。

- trackpad gestureからAeroSpace workspaceを切り替える
- display接続・切断時にwindow配置を切り替える
- appの起動状態に応じた条件付きautomationを実行する

設定を導入する場合は`hammerspoon/`をdotfilesで管理し、`~/.hammerspoon`へHome Managerからsymlinkする。

### Raycast

公開extensionは次を候補とする。

- AeroSpace Tiling Window Manager: AeroSpaceのshortcut表示・設定ファイルを開く・workspace内のapp切替
- Hammerspoon: Hammerspoonで登録したscriptの一覧・実行

Herdr用の実用的な公開Raycast extensionは未確認で、見つかった`shippy/raycast-herdr`は実装前のscaffoldだった。必要になったら`herdr status`を利用するRaycast Script Commandから始める。

## 運用ルール

- Ghostty: terminal表示
- Herdr: terminal内のagent管理
- AeroSpace: macOSのwindow管理
- Raycast: 検索・起動・軽いcommand実行
- Karabiner: 単純なkeyboard remap
- Hammerspoon: gestureと条件付きautomation

## 参考リンク

- [AeroSpace installation guide](https://nikitabobko.github.io/AeroSpace/guide#installation)
- [Herdr installation guide](https://herdr.dev/docs/install/)
- [AeroSpace Tiling Window Manager for Raycast](https://www.raycast.com/limonkufu/aerospace)
- [Hammerspoon for Raycast](https://www.raycast.com/bjrmatos/hammerspoon)
- [Hammerspoon documentation](https://www.hammerspoon.org/docs/)
