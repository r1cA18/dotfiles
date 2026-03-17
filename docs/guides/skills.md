# Agent Skills 運用ガイド

## 仕組み

```
dotfiles/skills/<name>/SKILL.md
        ↓ dr でリビルド（agent-skills-nix）
~/.claude/skills/<name> → dotfiles/skills/<name> (symlink)
        ↓
Claude Codeが /<name> として呼び出せる
```

`enableAll = ["custom"]` により `skills/` 以下の全スキルが自動で有効化される。

## スキルの種類と置き場所

### グローバルスキル（dotfiles/skills/）

どのプロジェクトでも使う汎用スキル。`dr` でリビルドすると全環境に反映される。

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

| スキル               | 用途                                                          |
| -------------------- | ------------------------------------------------------------- |
| `agent-browser`      | ブラウザ操作全般（URL閲覧・スクリーンショット・フォーム操作） |
| `firecrawl`          | Firecrawl CLIのルーター（以下の各スキルへの入口）             |
| `firecrawl-search`   | Web検索 + ページ内容取得                                      |
| `firecrawl-scrape`   | URLのコンテンツ取得（静的・SPA対応）                          |
| `firecrawl-crawl`    | サイト全体のバルク取得                                        |
| `firecrawl-map`      | サイトのURL一覧取得                                           |
| `firecrawl-agent`    | 構造化データ抽出                                              |
| `firecrawl-browser`  | インタラクションが必要なページ操作                            |
| `firecrawl-download` | サイトをローカルにダウンロード                                |

### 開発

| スキル              | 用途                                         |
| ------------------- | -------------------------------------------- |
| `autonomous-dev`    | 要件整理→TDD→レビュー→マージまで自律実行     |
| `ios-device-build`  | iOSアプリを実機にビルド・インストール・起動  |
| `swift-dev-toolkit` | Swift/iOS/macOS開発ツールキット              |
| `skill-builder`     | スキルの作成・改善                           |
| `skill-auditor`     | スキルの品質監査                             |
| `tmux-ai-cli`       | Gemini CLI + Codex CLIのオーケストレーション |

### UI / デザイン

| スキル                        | 用途                                                 |
| ----------------------------- | ---------------------------------------------------- |
| `baseline-ui`                 | AI生成UIのスラップ防止ベースライン                   |
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

### 知識管理

| スキル                  | 用途                                  |
| ----------------------- | ------------------------------------- |
| `knowledge-extract`     | セッションの学びをVaultに保存         |
| `session-documentation` | セッション内容をdocs/にドキュメント化 |

## スキルの呼び出し方

Claude Codeで `/スキル名` と入力するか、Claude Codeがタスクに応じて自動で呼び出す。

```
/firecrawl-search Nixのflake.nix書き方
/agent-browser https://example.com
/video-editing
```

## 削除・整理の検討候補

| スキル                          | 理由                                                     |
| ------------------------------- | -------------------------------------------------------- |
| `x-article-publisher-workspace` | SKILL.mdがなく、`trigger-eval.json` のみ。動作しない残骸 |
| `security-check`                | デモスキルと明記されている。実用性なし                   |
