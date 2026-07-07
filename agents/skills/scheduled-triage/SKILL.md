---
name: scheduled-triage
description: 定期実行のタスクトリアージ（朝のtriageと日中のmidday check）を固定フォーマットで生成する。scheduler や手動トリガーで、vault の Daily note・Times・observations と（接続可能なら）Linear/Google Calendar MCP から状況を集め、優先タスクと今日の推奨アクションを1本のnoteと1本のプレーンテキスト要約にまとめる。使うのは次の場合: 「トリアージして」「morning triage」「midday check」「定期チェック」「scheduled triage」「/scheduled-triage」。使わない場合: 単一タスクの詳細な計画立案（通常のプランニングを使う）、実装作業、Linear/Calendar が接続済みでライブなissue操作を伴う本格的なタスク管理。
allowed-tools: Read, Write, Glob, Bash(git:*)
user-invocable: true
---

# Scheduled Triage Skill

scheduler または手動トリガーで動く定期トリアージ。実行コンテキストでは Linear MCP /
Google Calendar MCP が接続できないことが多いため、接続を試しつつ、失敗時は vault の
Daily note・Times・`40_AI/observations.md` から状況を推測して固定フォーマットで出力する。

出力は2本:

1. 詳細note: `~/vault/40_AI/{prefix}-{YYYY-MM-DD}.md`
2. 要約テキスト（Discord/一覧向け・絵文字禁止）: `~/vault/40_AI/{prefix}-summary-{YYYY-MM-DD}.txt`

`prefix` はモードで決まる。morning -> `triage`、midday -> `midday-check`。

## 手順（condition -> action）

1. モード判定
   - トリガーが「morning triage」「トリアージ」系 -> morning モード（`prefix=triage`）
   - トリガーが「midday check」「日中チェック」系 -> midday モード（`prefix=midday-check`）
   - 判別できない -> 実行時刻が午前なら morning、それ以外は midday
2. 情報収集
   - Linear MCP 接続を試す -> 成功なら Todo/In Progress/Overdue の issue を取得 / 失敗なら制約に記録し vault から推測
   - Google Calendar MCP 接続を試す -> 成功なら今日の予定を取得 / 失敗なら制約に記録
   - vault の最新 Daily note・直近の Times・`40_AI/observations.md` を読む
3. タスク分類
   - 期限・source をもとに P0（緊急）〜 P3（低）に分類
   - deadline 超過または N日遅延のものは「長期遅延タスク（要判断）」へ回し Continue or Cancel を明記
4. 詳細note生成 -> 下記フォーマットで `~/vault/40_AI/{prefix}-{YYYY-MM-DD}.md` に書く
5. 要約生成 -> `~/vault/40_AI/{prefix}-summary-{YYYY-MM-DD}.txt` に書く（絵文字禁止・プレーンテキスト）
6. 報告 -> 生成した2ファイルの絶対パスをユーザーに提示

## 詳細note フォーマット

```markdown
---
title: "Morning Triage - {YYYY-MM-DD}"
created: {YYYY-MM-DD}
type: triage
tags: [triage]
---

# Morning Triage - {YYYY-MM-DD}

## メタ
- 実行時刻: {HH:MM} JST（{手動 / scheduler}）
- 制約: Linear MCP {接続可 / 接続不可}、Google Calendar MCP {接続可 / 接続不可}

## 状況サマリー
- {Daily note / Times / observations から確認できた状態を3-5点}

## 優先タスク
### P0-P1（緊急・重要）
1. {タスク名}
   - Source: {Times 日付 / observations / Linear issue ID}
   - Status: {未着手 / 進行中}
   - Action: {今日取る具体アクション}

### P2-P3（開発・アイデア）
1. {タスク名}
   - Source: {...}
   - Action: {...}

## 長期遅延タスク（要判断）
- {タスク名}: {N}日遅延（deadline {YYYY-MM-DD}）-> Continue or Cancel

## 推奨アクション（今日）
1. {最優先アクション}
2. {次のアクション}

## 次回への申し送り
- {MCP 接続などシステム改善の提案}
```

midday モードでは title を `Midday Check - {YYYY-MM-DD}`、tags を `[midday-check]`、
見出しを `# Midday Check - {YYYY-MM-DD}` にする。

## 要約テキスト フォーマット（絵文字禁止）

```text
Morning Triage - {YYYY-MM-DD}

【制約】
{Linear/Calendar の接続状態を1行}

【確認できた状況】
- {状況を3点まで}

【要確認】
1. {Linear Web UI / Calendar で確認すべき項目}

【推奨】
- {今日の推奨アクションを3-4点}

詳細: 40_AI/{prefix}-{YYYY-MM-DD}.md
```

## 完了条件（observable）

- `~/vault/40_AI/{prefix}-{YYYY-MM-DD}.md` が存在し、frontmatter に `title` / `created` / `type` / `tags` の4キーがある
- `~/vault/40_AI/{prefix}-summary-{YYYY-MM-DD}.txt` が存在し、絵文字を1つも含まない
- 詳細note の各優先タスクに Source と Action が両方記載されている
- MCP が接続不可だった場合、その旨が「メタ」の制約行に明記されている

<!--
このフォーマットは vault 内の実行例6件を蒸留したもの:
40_AI/triage-2026-04-05.md, triage-2026-06-16.md, triage-2026-07-03.md,
midday-check-2026-05-05.md, midday-check-2026-06-09.md, midday-check-2026-06-18.md
要約テキストは triage-summary-2026-07-03.txt を基準（絵文字なし版）とする。
triage-summary-2026-06-16.txt は絵文字入りだったため不採用。
-->
