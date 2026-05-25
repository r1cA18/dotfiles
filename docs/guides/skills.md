# Agent Skills 運用ガイド

## 仕組み

```
dotfiles/skills/<name>/SKILL.md
        ↓ dr でリビルド（agent-skills-nix）
~/.claude/skills/<name> → dotfiles/skills/<name> (symlink)
~/.codex/skills/<name>  → dotfiles/skills/<name> (symlink)
        ↓
Claude Code / Codex の両方から利用
```

`enableAll = ["custom"]` により `skills/` 以下の全スキルが自動で有効化される。

## CLI 依存

skill の中には追加の CLI を前提にするものがある。
この repo では、それらを `bunx` や手動 install に逃がさず、できるだけ Nix で宣言的に入れる。

現時点で dotfiles 管理している主な runtime CLI:

- `agent-browser`
- `codex`
- `gemini`

確認例:

```bash
command -v agent-browser
```

`skills` CLI は必要なときに `bunx skills` を使う。

## スキルの種類と置き場所

### グローバルスキル（dotfiles/skills/）

どのプロジェクトでも使う汎用スキル。`dr` でリビルドすると Claude / Codex の両環境に反映される。

追加方法：

```bash
mkdir skills/my-skill
# SKILL.mdを作成
dr  # リビルドで自動反映
```

### プロジェクトローカルスキル（flake.nixのdevShell）

そのプロジェクトだけで必要なスキル（例: Next.jsプロジェクトにvercel/next-skillsを入れる）。
`nix develop`（または direnv）に入った瞬間に `~/.claude/skills/` に配置され、抜けると消える。

詳細な設定例: [docs/guides/project-env.md](project-env.md)

### 公式スキル（anthropic/skills）

`agent-skills.nix` の `enable` リストにスキル名を追加して `dr` でリビルド。

```nix
# nix/home-manager/programs/agent-skills.nix
skills.enable = [
  "pdf"
  "xlsx"
  "frontend-design"
];
```

利用可能な公式スキル一覧: `ls $(nix eval --raw inputs.anthropic-skills)/skills/`

## 現在のグローバルスキル一覧

### Web / ブラウザ

| スキル          | 用途                                                          |
| --------------- | ------------------------------------------------------------- |
| `agent-browser` | ブラウザ操作全般（URL閲覧・スクリーンショット・フォーム操作） |

### 開発

| スキル              | 用途                                        |
| ------------------- | ------------------------------------------- |
| `autonomous-dev`    | 要件整理→TDD→レビュー→マージまで自律実行    |
| `ios-device-build`  | iOSアプリを実機にビルド・インストール・起動 |
| `swift-dev-toolkit` | Swift/iOS/macOS開発ツールキット             |
| `skill-builder`     | スキルの作成・改善                          |
| `skill-auditor`     | スキルの品質監査                            |
| `post-review`       | 実装後レビューと修正のループ                |

### UI / デザイン

| スキル                        | 用途                                                 |
| ----------------------------- | ---------------------------------------------------- |
| `baseline-ui`                 | AI生成UIのスラップ防止ベースライン                   |
| `frontend-design`             | official の frontend-design skill                    |
| `design-md`                   | Stitch project から DESIGN.md を生成                 |
| `enhance-prompt`              | Stitch 向けに UI prompt を強化                       |
| `react-components`            | Stitch screen を React component system に変換       |
| `shadcn-ui`                   | shadcn/ui 統合のガイド                               |
| `ui-skills`                   | UI構築の制約・ベストプラクティス                     |
| `design-capture`              | WebデザインのスクショとデザイントークンをVaultに保存 |
| `web-design-guidelines`       | UIコードのアクセシビリティ・設計レビュー             |
| `vercel-react-best-practices` | React/Next.jsのパフォーマンス最適化ガイドライン      |
| `remotion-best-practices`     | Remotion（React動画制作）のベストプラクティス        |
| `video-editing`               | FFmpeg + FrameScriptによる動画編集                   |

### コンテンツ

| スキル                | 用途                           |
| --------------------- | ------------------------------ |
| `x-research`          | X(Twitter)検索を使ったリサーチ |
| `x-article-publisher` | MarkdownをX Articlesに投稿     |
| `pdf`                 | PDF の読解・変換               |
| `xlsx`                | Excel ファイルの読解・変換     |

### 知識管理

| スキル                  | 用途                                  |
| ----------------------- | ------------------------------------- |
| `knowledge-extract`     | セッションの学びをVaultに保存         |
| `session-documentation` | セッション内容をdocs/にドキュメント化 |

## Plugin skill との関係

Claude plugin が runtime で提供する skill は、そのままでは dotfiles の source of truth にならない。
Claude / Codex の両方で使いたいものは `skills/` に共有 skill として置く。

- runtime plugin skill の実体: `~/.claude/plugins/...`
- 共有したい skill の正本: `dotfiles/skills/...`
- plugin 固有の browser automation や UI 拡張は Claude 専用として扱う
- 外部 OSS skill repo を使う場合は `flake.nix` + `agent-skills.nix` で source を追加して宣言的に管理する

## スキルの呼び出し方

Claude Code では `/スキル名` と入力するか、Claude Code がタスクに応じて自動で呼び出す。
Codex では `~/.codex/skills/` に同期された skill として参照される。

```bash
/agent-browser https://example.com
/video-editing
```

## 削除・整理の検討候補

| スキル                          | 理由                                                     |
| ------------------------------- | -------------------------------------------------------- |
| `x-article-publisher-workspace` | SKILL.mdがなく、`trigger-eval.json` のみ。動作しない残骸 |
| `security-check`                | デモスキルと明記されている。実用性なし                   |
