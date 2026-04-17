# Nix Environment

開発環境は `~/dotfiles/` で Nix (nix-darwin + home-manager) により宣言的に管理。
JS/TS ランタイムは Bun 優先。環境を汚すグローバルインストールは禁止。

## 禁止操作

以下のコマンドでのグローバルインストールは禁止。環境を汚染する。

- `pip install` / `pip install --user` / `uv pip install`（グローバル）
- `npm install -g` / `pnpm add -g` / `yarn global add`
- `brew install` / `brew install --cask`
- `cargo install` / `go install` / `gem install`（グローバル目的）

## 永続的なツール追加

| 対象                       | 方法                                                             |
| -------------------------- | ---------------------------------------------------------------- |
| CLI ツール・フォーマッター | `packages.nix` の `commonPackages` に追加 → `dr`                |
| npm CLI (nixpkgs にある)   | `commonPackages` に追加                                          |
| npm CLI (nixpkgs にない)   | `nix/pkgs/<name>/` に `buildNpmPackage` で追加 → `default.nix` と `commonPackages` に登録 |
| GUI アプリ (macOS)         | `configuration.nix` の `homebrew.casks` に追加                  |

## 一時利用（環境を汚さず試す）

comma (`,`) を最優先で使う。パッケージ名不要でコマンド名から自動解決する。
`nix run` / `nix shell` は comma で対応できない場合（特定バージョン指定、複数パッケージの同時利用等）のフォールバック。

| 優先度 | 目的                     | コマンド                                  |
| ------ | ------------------------ | ----------------------------------------- |
| 1      | コマンド名だけで実行     | `, <cmd> <args>`                          |
| 2      | パッケージ名指定で実行   | `nix run nixpkgs#<pkg> -- <args>`         |
| 3      | 一時的に PATH 追加       | `nix shell nixpkgs#<pkg1> nixpkgs#<pkg2>` |
| -      | コマンドのパッケージ検索 | `nix-locate bin/<cmd>`                    |

## プロジェクト開発環境

| 対象     | 方法                                                                    |
| -------- | ----------------------------------------------------------------------- |
| 開発環境 | `flake.nix` + `nix develop`（`.envrc` に `use flake` で direnv 自動化） |
| JS/TS    | Bun 優先。`bun install` で依存管理（node_modules は .gitignore）        |
| Python   | devShell で `python3.withPackages` を使用（pip/uv/venv 不要）           |
| Node.js  | Bun 非対応の場合のみフォールバック                                      |

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
