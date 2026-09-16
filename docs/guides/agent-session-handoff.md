---
title: "Agent sessionの再開と引き継ぎ"
created: 2026-09-06
type: guide
tags: [agents, sessions, handoff, profiles]
---

# Agent sessionの再開と引き継ぎ

同じ製品・accountで履歴を再開する操作と、別account・製品へ作業文脈を渡す操作を分ける。
この環境ではcredentialとruntimeをprofileごとに分離したまま扱う。

## 方法の選択

| 目的                                  | 方法                                      | 引き継ぐもの                                 |
| ------------------------------------- | ----------------------------------------- | -------------------------------------------- |
| 同じCodex accountで再開               | `cx-<name> resume <session-id>`           | そのlauncherのhomeに保存されたnative session |
| 同じClaude accountで再開              | `cc-<name> --resume <session-id>`         | そのlauncherのnative session                 |
| 現在のagentで別accountの作業を続行    | `session-handoff`で元ログと作業差分を確認 | 読める文脈と検証状態                         |
| Claude Code/CursorからCodexへ取り込み | 対応するlocal CLIの`/import`              | 選択した設定・project・最近のchat            |
| Mac/Linux間の履歴移送                 | `cct`等で対象sessionをexport/import       | 保存履歴の変換・移送                         |

`codex resume --all`はcwdの絞り込みを外すoptionでありaccount全体の検索ではない。
`codex -p`はconfig layerでありaccount切り替えではない。
CLIのresumeとcwdの扱いは[OpenAIのcommand reference](https://learn.chatgpt.com/docs/developer-commands?surface=cli)を参照。
Claudeの再開は[公式workflow](https://code.claude.com/docs/en/common-workflows#resume-previous-conversations)を参照。

## この環境での使い方

共有skillの正本は[session-handoff](../../agents/skills/session-handoff/SKILL.md)。
Nixの共通enableリストへ追加したため各hostで`dr`を適用した後の新規sessionから使える。
適用前でもagentにこのファイルのパスを渡して読ませられる。

```text
session-handoffを使って前のCodex sessionを探し
workspace棚卸しの未完了作業を引き継いで続けてほしい
```

```text
この作業を別のClaude Code accountへ引き継げるように
現在の判断・差分・検証結果・次の作業を既存の引き継ぎ文書へ残してほしい
```

ログの場所と抽出方法はskillの[local session lookup](../../agents/skills/session-handoff/references/local-sessions.md)にまとめた。
launcherごとのhomeは`ccspace list`で確認できる。
account管理の詳細は[ccspaceガイド](ccspace.md)を参照。

## 公式Import

2026-09-06に取得した[OpenAIのImportガイド](https://learn.chatgpt.com/docs/import)では、
local CLIの`/import`からClaude CodeまたはCursorを選択できる。
CLIは過去30日の最大50chatが対象で実行中task・remote session・local app-server接続中は使えない。
DesktopにはSettingsのImportがあり対応する項目と履歴を選択する。

この環境での実際のImport操作は未検証。
追加accountの独自homeを自動発見できるかも未確認であり、全profile対応とは扱わない。
settings・skills・hooksまで取り込むとNixの正本と重複するため取り込み対象を選別する。
現在進行中の作業を引き継ぐだけなら元ログを読む方法で足りる。

## 公開されている実装

以下はREADMEと公開仕様を確認した比較。実accountへの移行テストや常設導入は行っていない。

| 実装                                                   | 公開されている機能                                                   | この環境での判断                                                            |
| ------------------------------------------------------ | -------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| [ctxmv](https://github.com/Ryu0118/ctxmv)              | Claude Code/Codex/Cursor CLI/Kimi Code間のnative形式変換と一覧・表示 | READMEのsource build要件がSwift 6/macOS 15以上のためMac/Linux共通導入は保留 |
| [cct](https://github.com/ahmojo/codex-claude-transfer) | session bundle・dry-run・cwd変換・両製品間の変換                     | Mac/Linux移送の優先評価候補                                                 |
| [agenthop](https://github.com/CyrusSE/agenthop)        | 複数providerの一覧・検索・変換・移送用bundle                         | 多provider化した場合の候補                                                  |
| [handoff](https://github.com/AniruddhaHumane/handoff)  | summaryとsnapshotで作業状態を引き継ぐskill                           | 方針を参考にする。既存の記録運用と重なるため丸ごとの導入は保留              |

`cct`はREADMEでCodex 0.144.6とClaude Code 2.1.212を最終検証版として記載している。
今回の元sessionはCodex Desktop 0.153.3であり互換性を追加検証する必要がある。
cross-agent変換は会話とproject文脈が中心でtool結果やruntime stateの完全コピーではない。
詳細は[cctの互換性表](https://github.com/ahmojo/codex-claude-transfer#compatibility)を参照。

`agenthop`もproviderのprompt cacheは移せずtool・reasoning・image等をbest-effortとしている。
lossless archiveの保存と移行先モデルが同時に参照できるcontext量は別の保証になる。
詳細は[agenthopの制限](https://github.com/CyrusSE/agenthop#limitations)を参照。

## 変換ツールを常設する前の確認

1. commitまたはreleaseを固定したNix packageで一時評価
2. 架空のsource/target homeで同一製品の往復を検証
3. 別製品への変換で会話順序とtool結果の欠落を確認
4. Mac/Linuxのcwd差と追加account homeの指定を確認
5. 同一IDの衝突時に既存履歴が保存されることを確認
6. 元accountと移行先accountのcredentialが独立したままであることを確認

認証情報・plugin cache・live SQLite DBを丸ごと同期しない。
履歴には作業中のコードや秘密情報が含まれうるため公開dotfilesにはsummaryだけを置く。
native移行を採用してもworkspaceのrepo一覧と引き継ぎ文書は別途残す。

## 今回確認できた範囲

中断した親sessionをprimary homeで特定し会話本文と関連子sessionの平文実行記録を回収した。
添付記事のパスも元のuser messageから特定できた。
一部inter-agent messageは暗号化されていて読めなかった。
その部分は子sessionの実行記録と現状のファイルから補い、元session全体を復元したとは扱わない。
新しいaccountで動いている現在のsessionへ作業を引き継いだがnative session自体は移動していない。
