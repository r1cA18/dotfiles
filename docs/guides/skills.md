# Agent Skills 運用ガイド

## 仕組み

```
dotfiles/agents/skills/<name>/SKILL.md
        ↓ dr でリビルド（agent-skills-nix）
~/.claude/skills/<name>
~/.codex/skills/<name>
        ↓
Claude Code / Codex の両方から利用
```

スキルはすべて global として `nix/home-manager/programs/agent-skills.nix` の
`skills.enable` に明示する。project flake では skill を切り替えない。

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

`skills` CLIは検索時だけ`bunx skills`経由で使う。`find-skills` skillも同じ検索処理を案内する。

`skills add -g`は使わない。このcommandは`~/.agents/skills`へ別のglobal管理領域を作り、Nix管理のskillと重複する。永続追加は次のどちらかに統一する。

- custom skillは`agents/skills/`へ追加する
- external skillは`flake.nix`と`agent-skills.nix`へ追加する

## スキルの種類と置き場所

### グローバルスキル（dotfiles/agents/skills/）

どのプロジェクトでも使う汎用スキル。`dr` でリビルドすると Claude / Codex の両環境に反映される。

追加方法：

```bash
mkdir agents/skills/my-skill
# SKILL.mdを作成
dr  # リビルドで自動反映
```

### 外部スキル

`agent-skills.nix` の `enable` リストにスキル名を追加して `dr` でリビルド。

```nix
# nix/home-manager/programs/agent-skills.nix
skills.enable = [
  "pdf"
  "xlsx"
  "frontend-design"
];
```

利用候補は[Anthropicの公開skill一覧](https://github.com/anthropics/skills/tree/main/skills)から確認する。
repo全体のlicenseだけでなく各skill内の`LICENSE.txt`も読む。

OpenAI由来の共有skillは`openai-skills` inputから必要なものだけを選ぶ。
`openai/skills`は非推奨catalogであり、現在の配布例は`openai/plugins`へ移っている。
今回選んだCLI・reference workflowは旧catalogのcommitを固定し、
Codex pluginのapp/MCP依存を共有領域へ持ち込まない。

sourceの追加だけでは有効化しない。`skills.enable`または`skills.explicit`で選択する。
同名skillがあるsourceは`filter.nameRegex`でdiscoveryを絞り、
systemの`skill-creator`や`openai-docs`を上書きしない。

## 主なグローバルskill

### Web / ブラウザ

| スキル          | 用途                                             |
| --------------- | ------------------------------------------------ |
| `agent-browser` | ブラウザUI確認・スクリーンショット・フォーム操作 |

### 開発

| スキル                    | 用途                                        |
| ------------------------- | ------------------------------------------- |
| `ios-device-build`        | iOSアプリを実機にビルド・インストール・起動 |
| `swift-dev-toolkit`       | Swift/iOS/macOS開発ツールキット             |
| `skill-builder`           | スキルの作成・改善                          |
| `skill-auditor`           | スキルの品質監査                            |
| `post-review`             | 実装後レビューと修正のループ                |
| `idea-to-ship`            | 調査から実装・検証・pushまでのworkflow      |
| `project-init`            | flake・direnv・agent docsの初期化           |
| `gh-fix-ci`               | GitHub ActionsのPR失敗調査と修正            |
| `security-best-practices` | 明示的なPython・JS/TS・Goのsecurity review  |
| `property-based-testing`  | parser・変換・正規化等の性質を検証するtest  |

### UI / デザイン

| スキル                        | 用途                                                 |
| ----------------------------- | ---------------------------------------------------- |
| `baseline-ui`                 | AI生成UIのスラップ防止ベースライン                   |
| `frontend-design`             | official の frontend-design skill                    |
| `design-capture`              | WebデザインのスクショとデザイントークンをVaultに保存 |
| `web-design-guidelines`       | UIコードのアクセシビリティ・設計レビュー             |
| `vercel-react-best-practices` | React/Next.jsのパフォーマンス最適化ガイドライン      |
| `remotion-best-practices`     | Remotion（React動画制作）のベストプラクティス        |
| `video-editing`               | FFmpeg + FrameScriptによる動画編集                   |
| `design-taste-frontend`       | project文脈に合わせたanti-slop frontend実装          |
| `redesign-existing-projects`  | 既存UIのauditと改善                                  |
| `image-to-code`               | image基準のfrontend実装                              |

### コンテンツ

| スキル                  | 用途                                |
| ----------------------- | ----------------------------------- |
| `x-research`            | X(Twitter)検索を使ったリサーチ      |
| `x-article-publisher`   | MarkdownをX Articlesに投稿          |
| `codex-app-screenshots` | ChatGPT Web UIでApp Store画像を生成 |
| `app-store-screenshots` | App Store screenshot素材の作成      |
| `pdf`                   | PDF の読解・変換                    |
| `xlsx`                  | Excel ファイルの読解・変換          |
| `typst-author`          | Typst文書の作成・修正               |
| `touying-author`        | Touying slideの作成・修正           |
| `text-to-lottie`        | Lottie animationの作成・修正        |

### 知識管理

| スキル                  | 用途                                                  |
| ----------------------- | ----------------------------------------------------- |
| `knowledge-extract`     | セッションの学びをVaultに保存                         |
| `session-documentation` | セッション内容をdocs/にドキュメント化                 |
| `session-handoff`       | 別session・account・agentから未完了作業を回収して続行 |
| `indexion-workspace`    | 複数repoのworkspaceで共通指示とcontextを扱う          |
| `forms-archive`         | Microsoft FormsをPDF/MHTMLで保存                      |

引き継ぎ方法とnative resume/importの違いは[session引き継ぎガイド](agent-session-handoff.md)を参照。

## Plugin skill との関係

Claude plugin が runtime で提供する skill は、そのままでは dotfiles の source of truth にならない。
Claude / Codex の両方で使いたいものは`agents/skills/`に共有skillとして置く。

- runtime plugin skill の実体: `~/.claude/plugins/...`
- 共有したいskillの正本: `dotfiles/agents/skills/...`
- plugin 固有の browser automation や UI 拡張は Claude 専用として扱う
- 外部 OSS skill repo を使う場合は `flake.nix` + `agent-skills.nix` で source を追加して宣言的に管理する

Codex plugin も同じく runtime cache は source of truth にしない。
Codex 側で継続利用する plugin は、`nix/home-manager/programs/codex.nix` に宣言する。

- runtime Codex plugin cache: `~/.codex/plugins/cache/...`
- global Codex plugin: `nix/home-manager/programs/codex.nix`
- Codex から Claude Code を呼ぶ bridge: `claude-code-advisor@claude-plugin-codex`

## スキルの呼び出し方

Claude Code では `/スキル名` と入力するか、Claude Code がタスクに応じて自動で呼び出す。
Codex では `~/.codex/skills/` に同期された skill として参照される。
CLI/IDE では `/skills` や `$skill-name` で明示呼び出しできる。

Codex custom prompt は deprecated なので、再利用 workflow の正本にはしない。
slash-command 風に呼びたい場合だけ `codex/prompts/*.md` に薄い wrapper を置く。
例: `/prompts:init` は `$project-init` skill を呼び出す。

```bash
/agent-browser https://example.com
/video-editing
```

正確な有効一覧は`nix/home-manager/programs/agent-skills.nix`の`skills.enable`と`skills.explicit`をsource of truthにする。

## 2026-09追加の基礎skill

| Skill                     | 用途と非対象                                                   | Runtime                                   |
| ------------------------- | -------------------------------------------------------------- | ----------------------------------------- |
| `gh-fix-ci`               | PRのGitHub Actions失敗。一般reviewや外部CIは非対象             | Nixの`gh`と既存のGitHub認証               |
| `security-best-practices` | 明示的なsecurity依頼。通常のbug修正では自動適用しない          | repo読取。追加のAPIやMCPは不要            |
| `property-based-testing`  | roundtrip・idempotence・invariant等。UI E2Eやbenchmarkは非対象 | 対象projectが使うPBT libraryとtest runner |

全てClaude/Codex両targetへglobal配布する。GitHubへのcomment投稿・push・workflow再実行は、
skill導入とは別にその作業の依頼範囲で判断する。PBT libraryはglobal installせず対象projectで管理する。

`gh-fix-ci`は[local adapter](../../agents/skills/upstream-adapters/gh-fix-ci.md)を配布時に適用する。
旧Python helperへの依存と固定の承認段階を除き、現在の`gh`のJSON出力を直接使う。
`property-based-testing`はprovider固有の`effort` metadataだけを除き、出典とlicense情報を追記する。
upstreamのLICENSEやreferencesはbundleまたは参照先のNix store sourceに保持する。

採用候補・見送り理由・固定revision・検証範囲は
[基礎skill選定記録](../research/shared-foundation-skills-2026-09.md)を参照。
