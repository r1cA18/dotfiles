---
name: x-research
description: X(Twitter)検索を使った周辺リサーチ。xAI (Grok) の x_search で一次情報・用語・反論・数字を集め、Context Packを生成する。トリガー: "x-research", "Xリサーチ", "X検索リサーチ"
---

# X Research (周辺リサーチ via Grok x_search)

## Overview

任意のトピックについて、xAI (Grok) の x_search を使ってX上の情報を検索し、
一次情報/定義/反論/関連事例を集めた **Context Pack** (構造化Markdown) を生成する。

スクリプト本体: `~/.claude/skills/x-research/scripts/grok_context_research.ts`

## Prerequisites

- `XAI_API_KEY` が環境変数または `~/.claude/skills/x-research/.env` に設定されていること
- `tsx` が使えること（`npx tsx` でOK）

## Intake (ask first if missing)

- 何を調べるか（日本語OK。例: 「Claude Code の MCP server 活用事例」）
- 読者層: engineer / investor / both（default: engineer）
- 言語圏: ja / global（default: ja）

不足なら最初に聞く:

- 「何をリサーチする？」

## Workflow

1. ユーザーからトピックを受け取る
2. 以下のコマンドでGrok x_searchに委任:

```bash
cd ~/.claude/skills/x-research && npx tsx scripts/grok_context_research.ts \
  --topic "<TOPIC>" \
  --locale <ja|global> \
  --audience <engineer|investor|both> \
  --out-dir <OUTPUT_DIR>
```

3. 出力された Context Pack をユーザーに提示

## CLI Options

| Option       | Default                 | Description                        |
| ------------ | ----------------------- | ---------------------------------- |
| `--topic`    | (required)              | 調査トピック                       |
| `--locale`   | `ja`                    | `ja` or `global`                   |
| `--audience` | `engineer`              | `engineer` / `investor` / `both`   |
| `--goal`     | (built-in)              | リサーチ目的（カスタム）           |
| `--days`     | `30`                    | 検索の遡り日数                     |
| `--out-dir`  | `data/context-research` | 出力先ディレクトリ                 |
| `--dry-run`  | -                       | リクエストペイロードを表示して終了 |
| `--raw-json` | -                       | レスポンスJSONもstderrに出力       |

## Output

3つのファイルが生成される:

- `YYYYMMDD_HHMMSSZ_context.md` - Context Pack本体
- `YYYYMMDD_HHMMSSZ_<locale>_context.json` - リクエスト/レスポンス/パラメータ
- `YYYYMMDD_HHMMSSZ_<locale>_context.txt` - 抽出テキスト

## Context Pack Structure

生成されるContext Packの構造:

- Meta (Timestamp, Topic, Audience)
- Topic (1 sentence)
- Why Now (3 bullets)
- Key Questions (5-8)
- Terminology / Definitions (Source付き)
- Primary Sources (公式ドキュメント/仕様/規約等のURL)
- Secondary Sources (X投稿等のURL)
- Contrasts / Counterpoints (Evidence付き)
- Data Points (dated, As of / Source付き)
- What We Can Safely Say / What We Should Not Say
- Suggested Angles (3)
- Outline Seeds (3-6 headings)
- Sources (URL list)

## Source Priority

1. 公式ドキュメント / 公式ブログ / 仕様 / 規約 / 料金
2. GitHub / 実装 / SDK
3. 信頼できる二次情報
4. X投稿 (Secondary扱い)
