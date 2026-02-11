# Global Instructions

全プロジェクト・全エージェントに適用されるグローバル指示。

## 言語

- 日本語で応答、敬語不使用（タメ口）
- 技術用語・コード識別子は原語のまま

## コード規約

- **絵文字禁止**: コード、コメント、コミットメッセージ、Markdownすべてで絵文字を使わない
- シンプルさを優先、過度な抽象化を避ける
- 既存のコードスタイルに従う
- 不要なコメント・ドキュメントを追加しない
- 過剰に装飾されたprint/log文を書かない（シンプルなデバッグ出力で十分）

## Git規約

- コミットメッセージ: 英語、Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`)
- ブランチ名: `feature/xxx`, `fix/xxx`, `docs/xxx`
- mainへの直接pushは避ける（小さな修正を除く）

## 開発環境 (Nix管理)

開発環境は `~/dotfiles/` で Nix (nix-darwin + home-manager) により宣言的に管理。
**`npm install -g`, `pip install`, `brew install` でグローバルインストール禁止。必ずNix経由。**

### パッケージ管理の原則

| 対象                      | 方法                                                                   |
| ------------------------- | ---------------------------------------------------------------------- |
| CLIツール・フォーマッター | `packages.nix` の `commonPackages` に追加                              |
| グローバルnpmパッケージ   | `packages.nix` の `globalNpmPackages` に追加                           |
| Pythonライブラリ          | プロジェクトごとに `uv venv` + `uv pip install`（グローバル pip 禁止） |
| Node.jsライブラリ         | プロジェクトの `package.json` で管理                                   |
| 開発環境                  | `flake.nix` + `nix develop`（なければ作成。`nix-shell` も可）          |

### dotfiles 編集先

| やりたいこと         | 編集ファイル                                        |
| -------------------- | --------------------------------------------------- |
| CLIツール/パッケージ | `~/dotfiles/nix/home-manager/programs/packages.nix` |
| GUIアプリ (macOS)    | `~/dotfiles/nix/darwin/configuration.nix`           |
| エイリアス           | `~/dotfiles/nix/home-manager/programs/zsh.nix`      |
| 環境変数/PATH        | `~/dotfiles/nix/home-manager/programs/packages.nix` |
| Claude Code設定      | `~/dotfiles/claude/settings.json`                   |
| エージェント         | `~/dotfiles/claude/agents/`                         |
| グローバルルール     | `~/dotfiles/claude/rules/`                          |
| グローバルスキル     | `~/dotfiles/skills/<name>/SKILL.md`                 |

### symlink構造

- `~/dotfiles/claude/settings.json` -> `~/.claude/settings.json`
- `~/dotfiles/shared/GLOBAL_INSTRUCTIONS.md` -> `~/.claude/CLAUDE.md`
- `~/dotfiles/claude/agents/` -> `~/.claude/agents/`
- `~/dotfiles/skills/` -> `~/.claude/skills/` (agent-skills-nix経由)
- 変更後は `dr` でリビルド
- 詳細: `~/dotfiles/docs/architecture.md`

## ワークフロー

- 複雑な実装前にプランを立てる
- テスト駆動開発を推奨
- コードレビューを活用（`codex review` 等）
- グローバルスキル作成: `~/dotfiles/skills/<name>/SKILL.md` に配置、`dr` で同期
