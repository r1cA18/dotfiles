# Skill Quality Checklist

スキル生成後の自己レビューに使用する。
skill-auditor のルーブリックと Anthropic公式ガイドのベストプラクティスを統合。

## 必須チェック（全て OK でないとリリース不可）

### 1. Frontmatter

- [ ] `name` が kebab-case でフォルダ名と一致
- [ ] `description` が存在し、50文字以上
- [ ] description に WHAT（何をするか）が含まれる
- [ ] description に WHEN（いつ使うか/トリガー条件）が含まれる
- [ ] description が 1024文字以内
- [ ] XML タグ (< >) が含まれていない
- [ ] `---` デリミタが正しく閉じている

### 2. トリガー品質

- [ ] 英語トリガーフレーズが 3つ以上
- [ ] 日本語トリガーフレーズが 3つ以上（「〜して」形式）
- [ ] パラフレーズ（同じ意図の異なる言い回し）がある
- [ ] 必要に応じて negative trigger がある（「NOT for X」）
- [ ] 既存スキルとトリガーが競合しない

### 3. Body 品質

- [ ] 命令形（imperative form）で記述
- [ ] 二人称（「あなたは」「you should」）を使っていない
- [ ] SKILL.md body が 200行以下（Simple は 100行以下）
- [ ] 重要な情報が先頭に配置されている
- [ ] 判断基準が表で整理されている（該当する場合）

### 4. Progressive Disclosure

- [ ] SKILL.md body に全情報を詰め込んでいない
- [ ] references/ のファイルが SKILL.md からリンクされている
- [ ] 各 reference ファイルが 300行以下（超える場合は TOC あり）
- [ ] SKILL.md と references/ の間で内容が重複していない

### 5. 構造

- [ ] パターンに見合ったディレクトリ構成
- [ ] ファイル名が SKILL.md（大文字・小文字正確）
- [ ] 参照されている全ファイルが実在する
- [ ] スクリプトがある場合、実行権限あり

## 推奨チェック（品質向上に寄与）

### 6. 環境対応

- [ ] パスが ~/dotfiles/skills/ 前提で正しい
- [ ] Nix 環境固有の考慮事項がある場合、記載されている
- [ ] 外部ツールの依存が明記されている

### 7. 重複回避

- [ ] ~/dotfiles/skills/ 内の既存スキルとの重複を確認済み
- [ ] 関連スキルとの境界が明確（description で区別）
- [ ] 統合すべきスキルがないか検討済み

### 8. エラーハンドリング

- [ ] よくある失敗パターンの対処が記載
- [ ] MCP 接続エラーの対処（MCP 依存の場合）
- [ ] フォールバック手順がある

### 9. 実行可能性

- [ ] 手順が具体的（コマンド例、ファイルパス等）
- [ ] 抽象的な指示ではなく実行可能な指示
- [ ] テンプレートやスクリプトで自動化されている部分がある

## 簡易スコアリング

必須チェック (1-5) の OK 率で簡易判定:

| OK 率   | 判定                        |
| ------- | --------------------------- |
| 100%    | Excellent - リリース可能    |
| 80-99%  | Good - 軽微な修正後リリース |
| 60-79%  | Needs Work - 修正が必要     |
| 60%未満 | Weak - 再設計を検討         |

## 良い description の例

```yaml
# Category 1: Document & Asset Creation
description: |
  Create and edit presentation slides with consistent branding.
  Generates PPTX files from Markdown or natural language descriptions.
  Supports templates, brand colors, and custom layouts.
  Triggers: "create slides", "make a presentation", "build a deck", "pptx"
  日本語: 「スライド作って」「プレゼン資料作成」「デッキを作って」「発表資料」

# Category 2: Workflow Automation
description: |
  Automated sprint planning workflow for Linear projects.
  Fetches project status, analyzes velocity, suggests priorities, creates tasks.
  Triggers: "plan sprint", "sprint planning", "create sprint tasks", "Linear sprint"
  日本語: 「スプリント計画」「スプリントプランニング」「タスク作成」

# Category 3: MCP Enhancement
description: |
  Code review workflow using Sentry error data and GitHub PRs.
  Analyzes detected bugs, suggests fixes, and creates review comments.
  Requires: Sentry MCP + GitHub MCP.
  Triggers: "review with sentry", "sentry code review", "analyze errors in PR"
  日本語: 「Sentryでレビュー」「エラー分析」「PRのバグを確認」
```

## 悪い description の例と修正

```yaml
# Bad: 曖昧
description: Helps with projects.
# Fix: 具体的に
description: |
  Manage project tasks in Notion with automated status tracking.
  Triggers: "create project", "update task status", "project overview"
  日本語: 「プロジェクト作成」「タスク更新」「進捗確認」

# Bad: トリガーなし
description: Creates sophisticated multi-page documentation systems.
# Fix: トリガーを追加
description: |
  Generate multi-page technical documentation from codebase analysis.
  Triggers: "generate docs", "document this project", "create API docs"
  日本語: 「ドキュメント生成」「API仕様書作成」「このプロジェクトを文書化」

# Bad: 技術的すぎ
description: Implements the Project entity model with hierarchical relationships.
# Fix: ユーザー視点に
description: |
  Set up hierarchical project structures with parent-child task relationships.
  Triggers: "organize project", "create task hierarchy", "set up project structure"
  日本語: 「プロジェクト整理」「タスク階層作成」「構造化して」
```

## Over-trigger 対策

description が広すぎてノイズになる場合:

1. **Negative trigger を追加**:

   ```yaml
   description: |
     Advanced data analysis for CSV files. Statistical modeling, regression, clustering.
     NOT for simple data exploration (use data-viz skill instead).
   ```

2. **スコープを限定**:

   ```yaml
   description: |
     PayFlow payment processing for e-commerce.
     Specifically for online payment workflows, not general financial queries.
   ```

3. **関連スキルとの境界を明示**:
   ```yaml
   description: |
     PDF form filling and manipulation.
     For PDF creation from scratch, use document-builder skill instead.
   ```
