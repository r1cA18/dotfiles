# Claude Code 設定

`~/.claude/` の設定ファイルを dotfiles で宣言的に管理。

## 構造

```
~/.claude/
├── CLAUDE.md            ← dotfiles/shared/GLOBAL_INSTRUCTIONS.md (symlink)
├── settings.json        ← dotfiles/claude/settings.json (symlink)
├── settings.local.json  ← ランタイム生成（管理対象外）
├── rules/               ← dotfiles/claude/rules/ (symlink)
│   └── *.md             # ドメイン別ルール（常時ロード）
├── hooks/               ← dotfiles/claude/hooks/ (symlink)
│   └── *.sh             # 自動実行フック
├── commands/            ← dotfiles/claude/commands/ (symlink)
│   └── *.md             # スラッシュコマンド定義
├── agents/              ← dotfiles/claude/agents/ (symlink)
│   └── *.md             # カスタムエージェント定義
├── skills/              ← dotfiles/skills/ (agent-skills-nix で管理)
│
└── [その他]             ← ランタイムデータ（管理対象外）
    ├── cache/
    ├── projects/
    ├── todos/
    └── ...
```

## 指示の強度階層

```
Hook (自動強制)  > Rule (常時ロード)  > CLAUDE.md (人格)  > Skill (オンデマンド)
hooks/*.sh         rules/*.md           CLAUDE.md           skills/*/SKILL.md
```

- **Hook**: 違反を自動検出・ブロック。最も強い強制力
- **Rule**: 毎セッション読み込み。ドメイン別に分離管理
- **CLAUDE.md**: グローバルな振る舞い定義（言語、行動原則）。薄く保つ
- **Skill**: キーワードトリガーでオンデマンドロード

## 管理対象

| ファイル/ディレクトリ | 説明                                            | 管理方法         | rebuild   |
| --------------------- | ----------------------------------------------- | ---------------- | --------- |
| `CLAUDE.md`           | グローバル指示（人格・行動原則）                | symlink          | 不要      |
| `settings.json`       | 全体設定（hooks、プラグイン等）                 | symlink          | 不要      |
| `rules/`              | ドメイン別ルール（常時ロード）                  | symlink          | 不要      |
| `hooks/`              | 自動実行フック                                  | symlink          | 不要      |
| `commands/`           | スラッシュコマンド（`/command-name`で呼び出し） | symlink          | 不要      |
| `agents/`             | カスタムエージェント（Task toolで使用）         | symlink          | 不要      |
| `skills/`             | スキル定義                                      | agent-skills-nix | `dr` 必要 |

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
model: haiku # 使用モデル（オプション）
tools: # 使用可能ツール
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
