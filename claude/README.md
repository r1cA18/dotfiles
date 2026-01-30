# Claude Code 設定

`~/.claude/` の設定ファイルを dotfiles で宣言的に管理。

## 構造

```
~/.claude/
├── settings.json        ← dotfiles/claude/settings.json (symlink)
├── settings.local.json  ← ランタイム生成（管理対象外）
├── commands/            ← dotfiles/claude/commands/ (symlink)
│   └── *.md             # スラッシュコマンド定義
├── agents/              ← dotfiles/claude/agents/ (symlink)
│   └── *.md             # カスタムエージェント定義
├── skills/              ← dotfiles/skills/ (agent-skills-nix で管理)
│
└── [その他]             ← ランタイムデータ（管理対象外）
    ├── cache/
    ├── history.jsonl
    ├── projects/
    ├── todos/
    └── ...
```

## 管理対象

| ファイル/ディレクトリ | 説明 | 管理方法 |
|---------------------|------|---------|
| `settings.json` | 全体設定（モデル、hooks、プラグイン等） | symlink |
| `commands/` | スラッシュコマンド（`/command-name`で呼び出し） | symlink |
| `agents/` | カスタムエージェント（Task toolで使用） | symlink |
| `skills/` | スキル定義 | agent-skills-nix |

## settings.json

```json
{
  "model": "opus",                    // デフォルトモデル
  "hooks": { ... },                   // 通知・停止時のフック
  "statusLine": { ... },              // ステータスライン設定
  "enabledPlugins": { ... },          // 有効なプラグイン
  "language": "日本語, 敬語非使用",     // 応答言語
  "permissions": { ... }              // 許可設定
}
```

## commands/（スラッシュコマンド）

`/command-name` で呼び出せるカスタムコマンドを定義。

### ファイル形式

```markdown
---
name: command-name
description: コマンドの説明
---

# Command Name

コマンドが呼び出されたときの指示...
```

### 使用例

```
/baseline-ui          # UI制約を適用
/baseline-ui file.tsx # ファイルをレビュー
```

## agents/（カスタムエージェント）

Task toolで使用するカスタムエージェントを定義。

### ファイル形式

```markdown
---
name: agent-name
description: |
  エージェントの説明（複数行可）
model: haiku  # 使用モデル（オプション）
tools:        # 使用可能ツール
  - Read
  - Glob
---

# Agent Name

エージェントへの指示...
```

## 追加方法

### 新しいコマンドを追加

1. `dotfiles/claude/commands/` に `.md` ファイルを作成
2. YAML frontmatter で `name` と `description` を定義
3. 変更は symlink なので即座に反映

### 新しいエージェントを追加

1. `dotfiles/claude/agents/` に `.md` ファイルを作成
2. YAML frontmatter で `name`、`description`、`model`、`tools` を定義
3. 変更は symlink なので即座に反映

## 注意事項

- symlink なのでファイルを直接編集可能（`dr` 不要）
- `settings.local.json` はランタイム設定なので管理対象外
- skills は `agent-skills-nix` 経由で管理（編集後は `dr` が必要）
