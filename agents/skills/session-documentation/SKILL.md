---
name: session-documentation
description: セッションの内容をdocs/にドキュメント化。「ドキュメント化して」「まとめて」「記録して」「docsに残して」で自動実行。テンプレート指定可（ADR/research/guide/session-log）
allowed-tools: Read, Write, Glob, Bash(git:*)
user-invocable: true
---

# Session Documentation Skill

セッションで行った作業・調査・学びを構造化されたMarkdownとして記録する。
生成するファイルには必ず下記のfrontmatterスキーマを付与する。

## Frontmatter スキーマ（全ドキュメント共通）

生成するすべてのMarkdownは、本文の先頭に次のYAML frontmatterを付ける。
キーは4つだけに固定する。増やさない。

| キー | 必須 | 値 |
|------|------|-----|
| `title` | 必須 | 内容を表す簡潔な文字列。日本語可。`:` を含む場合はダブルクオートで囲む |
| `created` | 必須 | 作成日 `YYYY-MM-DD`（`date` や `updated` は使わない） |
| `type` | 必須 | `session-log` / `research` / `adr` / `guide` のいずれか1つ |
| `tags` | 必須 | 小文字ケバブケースの配列。最低1個。日本語タグは使わない |

good（この形式に統一する）:

```yaml
---
title: "卒研方向性整理: syoki と AI時代のインタフェースデザイン"
created: 2026-06-16
type: session-log
tags: [research-direction, syoki, hci, graduation-thesis]
---
```

bad（vault内に実在した非統一形式。修正対象）:

```yaml
---
date: 2026-03-02
type: ai-session
topic: Matsuo Lab LLM course final competition
tags: [llm, fine-tuning, lora]
---
```

badの問題点:
- `date` は `created` に統一する
- `type: ai-session` は許可値ではない。`session-log` にする
- `topic` は使わない。内容は `title` に入れる
- frontmatterを持たないファイルも実在するが、frontmatterは必須

## 保存先ルール（condition -> action）

- カレントがプロジェクトのコードリポジトリ内（vault以外のgit repo）-> `docs/ai/sessions/` に保存
- vault内での作業、または複数プロジェクトを横断する作業 -> `$VAULT/40_AI/sessions/` に保存（vaultは `~/vault`）
- 上記以外で保存先が判断できない -> ユーザーに確認する

`type` が `session-log` 以外（research/adr/guide）でプロジェクトリポジトリ内の場合は、
下記「テンプレート選択」の保存先（`docs/research/` など）を優先する。

## テンプレート選択

以下のテンプレートから適切なものを選択する:

| テンプレート | 保存先 | 用途 | トリガー例 |
|------------|--------|------|-----------|
| **default** (guide) | `docs/guides/` | 手順書・ハウツー | 「ドキュメント化して」「まとめて」 |
| **adr** | `docs/decisions/` | 技術選定・設計判断 | 「ADR形式で」「決定を記録して」 |
| **research** | `docs/research/` | 調査結果・比較分析 | 「調査結果をまとめて」「リサーチを記録」 |
| **session-log** | 上記「保存先ルール」に従う | 作業ログ・日報 | 「今日の作業をログに」「セッションログ」 |

## 選択フロー

1. ユーザーの指示からテンプレートを推測
2. 明確に判断できない場合 → ユーザーにテンプレート選択を確認
3. 何も指定がなければ → **default（guide形式）**を使用

## ドキュメント分割ルール

**1ファイル = 1トピック** を厳守する。

### 原則

- 1つのドキュメントは1つのジャンル・話題に限定
- 複数のトピックがセッションに含まれる場合は**必ず分割**して別ファイルにする
- ファイルが肥大化しないよう、適切な粒度で分ける

### 分割の判断基準

| 状況 | 対応 |
|------|------|
| 調査A + 調査B を行った | → `research/調査A.md` と `research/調査B.md` に分割 |
| 機能実装 + その過程での技術選定 | → `guides/機能実装.md` と `decisions/技術選定.md` に分割 |
| 複数の独立した学びがある | → トピックごとに別ファイル |

### サイズ目安

- 1ファイル: **100〜300行程度**を目安
- それを超える場合はトピック分割を検討
- 「このファイルは何について書いてある？」に一言で答えられる粒度

### 例

セッションで以下を行った場合:
1. SF Symbolsのライセンス調査
2. Icon Composerの使い方調査
3. 実際のアイコン作成作業

→ 3つのファイルに分割:
- `docs/research/sf-symbols-license.md`
- `docs/guides/icon-composer-usage.md`
- `docs/guides/app-icon-creation.md`

---

## 実行手順

1. **コンテキスト収集**
   - セッション内の会話履歴から主要なトピックを抽出
   - `git log --oneline -10` で最近のコミットを確認
   - 調査で参照したURLをリストアップ

2. **テンプレート選択**
   - ユーザー指示に基づいてテンプレートを選択
   - 不明な場合はユーザーに確認

3. **ドキュメント生成**
   - 先頭に共通frontmatterスキーマ（`title` / `created` / `type` / `tags`）を付ける
   - 選択したテンプレート（`templates/*.md`）を参照
   - セッション内容を適切なセクションに配置
   - ファイル名: `{適切な名前}.md` または `{YYYY-MM-DD}-{title}.md`

4. **保存**
   - 適切なディレクトリに保存（なければ作成）
   - ファイル作成後、パスをユーザーに報告

## テンプレートファイル

テンプレートは `templates/` ディレクトリを参照:
- [default.md](templates/default.md) - ガイド形式
- [adr.md](templates/adr.md) - ADR形式
- [research.md](templates/research.md) - 調査記録形式
- [session-log.md](templates/session-log.md) - セッションログ形式

## docs/ディレクトリ構造

プロジェクトのdocs/は以下の構造を推奨:

```
docs/
├── README.md           # 目次・説明
├── decisions/          # ADR
├── guides/             # 手順書
├── research/           # 調査記録
└── sessions/           # セッションログ
```

ディレクトリが存在しない場合は作成する。
