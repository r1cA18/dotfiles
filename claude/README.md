# Claude Code 設定

`~/.claude/` の設定ファイルを dotfiles で宣言的に管理。
ただし user-level runtime state の一部は `~/.claude.json` に別保存される。

## 構造

```
~/.claude/
├── CLAUDE.md            ← dotfiles/shared/GLOBAL_INSTRUCTIONS.md (symlink)
├── settings.json        ← dotfiles/claude/settings.json (symlink)
├── mcp-servers.json     ← dotfiles/claude/mcp-servers.json
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
    ├── plugins/
    ├── projects/
    ├── todos/
    └── ...

~/.claude.json           ← user-level runtime state（管理対象外、MCP実設定を含む）
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
| `mcp-servers.json`    | user-level MCP の seed 定義                     | repo file        | 不要      |
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

## MCP 管理

Claude の MCP サーバー実設定は `~/.claude.json` にあり、OAuth 状態や runtime 情報も混ざる。
そのため `~/.claude.json` 自体は dotfiles で完全管理せず、`claude/mcp-servers.json` を source of truth にする。

- declarative seed: `dotfiles/claude/mcp-servers.json`
- runtime state: `~/.claude.json`
- 同期スクリプト: `dotfiles/claude/scripts/sync-mcp-servers.py`
- `dr` 時の自動同期: `nix/home-manager/programs/claude-code.nix`

例:

```bash
python3 ~/dotfiles/claude/scripts/sync-mcp-servers.py ~/.claude.json ~/dotfiles/claude/mcp-servers.json
```

このスクリプトは `mcpServers` だけを upsert し、他の runtime state は残す。

## Plugin と skill の扱い

`enabledPlugins` は `settings.json` で宣言的に管理しているが、plugin 本体は `~/.claude/plugins/...` に runtime 展開される。
Claude plugin が配布する skill は、そのままでは Codex と共有できない。

- Claude / Codex の両方で使いたい skill は `dotfiles/skills/` に置く
- plugin 依存の UI 拡張や browser integration は Claude 専用として扱う

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
- `~/.claude.json` は runtime state を含むので完全な declarative 管理対象外
- skills は `agent-skills-nix` 経由で管理（編集後は `dr` が必要）
