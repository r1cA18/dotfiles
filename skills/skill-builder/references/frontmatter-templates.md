# Frontmatter Templates

スキル作成時のコピペ用テンプレート。パターンに応じて選択。

## Minimal (Type 4: Simple)

```yaml
---
name: { skill-name }
description: |
  {1行で何をするか}
  Triggers: "{phrase1}", "{phrase2}", "{phrase3}"
  日本語: 「{フレーズ1}」「{フレーズ2}」「{フレーズ3}」
---
```

## Standard (Type 2: Single + References)

```yaml
---
name: { skill-name }
description: |
  {何をするか 1-2文}
  {主要な機能の列挙}
  Triggers: "{phrase1}", "{phrase2}", "{phrase3}"
  日本語: 「{フレーズ1}」「{フレーズ2}」「{フレーズ3}」
---
```

## Full (Type 1: Router / Type 3: Library)

```yaml
---
name: { skill-name }
description: |
  {何をするか 1-2文}
  {サブスキル/機能の列挙}
  Triggers: "{phrase1}", "{phrase2}", ..., "{phraseN}"
  日本語: 「{フレーズ1}」「{フレーズ2}」...「{フレーズN}」
---
```

## With Tool Restriction

```yaml
---
name: { skill-name }
description: |
  {description}
allowed-tools: "Read Glob Grep WebFetch WebSearch"
---
```

## With Metadata

```yaml
---
name: { skill-name }
description: |
  {description}
metadata:
  author: r1ca18
  version: 1.0.0
  mcp-server: { server-name }
---
```

## YAML Frontmatter Rules

### Required Fields

| Field       | Rule                            |
| ----------- | ------------------------------- |
| name        | kebab-case, フォルダ名と一致    |
| description | 50-1024文字, WHAT + WHEN を含む |

### Optional Fields

| Field         | Purpose              | Example             |
| ------------- | -------------------- | ------------------- |
| license       | OSS の場合           | MIT, Apache-2.0     |
| allowed-tools | ツール制限           | "Read Glob Grep"    |
| compatibility | 環境要件 (1-500文字) | "Requires Bun 1.0+" |
| metadata      | カスタム key-value   | author, version 等  |

### Forbidden

- XML angle brackets (< >) -- セキュリティ制限
- "claude" or "anthropic" in name -- 予約語
- unclosed quotes in YAML
- missing `---` delimiters

## allowed-tools の設計指針

| スキルの種類   | 推奨 allowed-tools                  |
| -------------- | ----------------------------------- |
| 参照のみ       | "Read Glob Grep"                    |
| Web 調査       | "Read Glob Grep WebFetch WebSearch" |
| コード実行あり | "Read Glob Grep Bash Write Edit"    |
| 全権限必要     | （省略 = 全ツール許可）             |

最小権限の原則: 不要なツールへのアクセスを制限する。
ただし、全ツールが必要な場合は省略で OK。
