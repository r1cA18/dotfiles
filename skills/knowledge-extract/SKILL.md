---
name: knowledge-extract
description: >-
  セッション内の壁打ち・議論・学びからナレッジを抽出してvaultに保存。
  「ナレッジに保存して」「知見をまとめて」「save knowledge」「学んだことを記録して」で使用。
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion
user-invocable: true
---

# Knowledge Extract

セッション内のコンテキスト(壁打ち・議論・調査)からナレッジを抽出し、vault `20_Knowledge/` に保存する。
Claude はセッション全体のコンテキストを既に保持しているため、外部ツールでのトランスクリプト解析は不要。

## Process

### 1. セッション分析

会話コンテキストから以下を抽出:

- 技術的な知見、パターン、ベストプラクティス
- 設計判断とその根拠
- 問題解決のプロセスで得た学び
- ツール・ライブラリの使い方で発見したこと

### 2. トピック分割判断

セッションに複数の独立した知見がある場合は、**必ず分割**して別ファイルにする。
1ファイル = 1トピック。「このノートは何について書いてある？」に一言で答えられる粒度。

### 3. 重複チェック

保存前に既存ナレッジとの重複を確認:

```bash
# タイトルやaliasesで既存ノートを検索
Grep("候補キーワード", path="20_Knowledge/", output_mode="files_with_matches")
```

重複がある場合:

- 完全重複 -> ユーザーに報告してスキップ
- 部分重複 -> 既存ノートへの追記を提案 (AskUserQuestion)
- 関連あり -> `related` フィールドでリンク

### 4. ドラフト作成

以下のスキーマで Knowledge note を作成:

```markdown
---
title: "日本語タイトル"
type: knowledge
notetype: permanent
created: YYYY-MM-DD
tags: [kebab-case-tag1, kebab-case-tag2]
aliases: [日本語バリエーション, English translation, 略語]
source: "session:YYYY-MM-DD"
related:
  - "[[関連ノート]]"
---

## 概要

1-3行で知見の要約。

## 詳細

本文。見出し・箇条書きを活用して構造化。

## 学んだこと

- ポイント1
- ポイント2
```

### 5. ユーザー確認

AskUserQuestion でドラフトの確認を取る:

- タイトル・タグは適切か
- 内容に過不足はないか
- notetype は permanent/fleeting どちらか

### 6. 保存

1. `20_Knowledge/{タイトル}.md` に Write
2. `20_Knowledge/_index.md` に追記 (適切なセクションに配置)

## ファイル命名規則

- 日本語タイトル (スペース不可、スラッシュ不可)
- コンセプトにフォーカス (作業内容ではなく学びの本質)
- 例: `Claude-Codeフック設計パターン.md`, `Discord-Bot長文メッセージ対応.md`

## notetype 判断基準

| notetype     | 条件                                          |
| ------------ | --------------------------------------------- |
| `permanent`  | 深い理解を伴う知見。6ヶ月後も参照価値がある   |
| `fleeting`   | まだ粗い段階。後で permanent に昇格する可能性 |
| `literature` | 外部ソース(記事・本)の要約が主体              |

## aliases ガイドライン

AI agent が検索で見つけられるよう、以下を含める:

- 日本語の表記揺れ (カタカナ/ひらがな/漢字)
- 英語訳
- 略語・頭文字 (例: CC = Claude Code)
- 関連する技術用語
