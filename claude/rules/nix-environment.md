# Nix Environment

開発環境は `~/dotfiles/` で Nix (nix-darwin + home-manager) により宣言的に管理。
`npm install -g`, `pip install`, `brew install` でグローバルインストール禁止。必ず Nix 経由。

## パッケージ管理の原則

| 対象                       | 方法                                                                   |
| -------------------------- | ---------------------------------------------------------------------- |
| CLI ツール・フォーマッター | `packages.nix` の `commonPackages` に追加                              |
| グローバル npm パッケージ  | `packages.nix` の `globalNpmPackages` に追加                           |
| Python ライブラリ          | プロジェクトごとに `uv venv` + `uv pip install`（グローバル pip 禁止） |
| Node.js ライブラリ         | プロジェクトの `package.json` で管理                                   |
| 開発環境                   | `flake.nix` + `nix develop`（なければ作成。`nix-shell` も可）          |

## dotfiles 編集先

| やりたいこと          | 編集ファイル                                        |
| --------------------- | --------------------------------------------------- |
| CLI ツール/パッケージ | `~/dotfiles/nix/home-manager/programs/packages.nix` |
| GUI アプリ (macOS)    | `~/dotfiles/nix/darwin/configuration.nix`           |
| エイリアス            | `~/dotfiles/nix/home-manager/programs/zsh.nix`      |
| 環境変数/PATH         | `~/dotfiles/nix/home-manager/programs/packages.nix` |
| Claude Code 設定      | `~/dotfiles/claude/settings.json`                   |
| エージェント          | `~/dotfiles/claude/agents/`                         |
| グローバルルール      | `~/dotfiles/claude/rules/`                          |
| グローバルスキル      | `~/dotfiles/skills/<name>/SKILL.md`                 |

## symlink 構造

- `~/dotfiles/claude/settings.json` -> `~/.claude/settings.json`
- `~/dotfiles/shared/GLOBAL_INSTRUCTIONS.md` -> `~/.claude/CLAUDE.md`
- `~/dotfiles/claude/agents/` -> `~/.claude/agents/`
- `~/dotfiles/claude/rules/` -> `~/.claude/rules/`
- `~/dotfiles/skills/` -> `~/.claude/skills/` (agent-skills-nix 経由)
- 変更後は `dr` でリビルド（rules/agents/hooks は symlink なので即反映）
