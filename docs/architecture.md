# dotfiles アーキテクチャ & 開発ガイド

このドキュメントは Claude / Codex などの agent がこのリポジトリを理解し、適切に変更を加えるためのガイド。

## ディレクトリ構造

```
dotfiles/
├── CLAUDE.md                 # Claude向け指示（このドキュメントを参照）
├── flake.nix                 # flake エントリポイント
├── flake.lock                # flake ロックファイル
├── README.md                 # ユーザー向けクイックスタート
├── docs/                     # ドキュメント（このファイルを含む）
│   └── architecture.md       # このファイル
│
├── nix/                      # Nix設定（メイン）
│   ├── darwin/               # macOS専用 (nix-darwin)
│   │   └── configuration.nix # システム設定、Homebrew管理
│   │
│   ├── home-manager/         # ユーザー設定
│   │   ├── home.nix          # home-managerエントリポイント
│   │   └── programs/         # 各プログラムの設定
│   │       ├── packages.nix  # パッケージ、PATH、環境変数
│   │       ├── zsh.nix       # Zsh、abbr、help
│   │       ├── nh.nix        # nh 設定
│   │       ├── git.nix       # Git設定
│   │       ├── neovim.nix    # Neovim本体と開発ツール供給
│   │       ├── ghostty.nix   # Ghostty設定（programs.ghostty）
│   │       ├── karabiner.nix # Karabiner（karabiner/へのシンボリックリンク）
│   │       ├── claude-code.nix # Claude Code（claude/へのシンボリックリンク）
│   │       ├── nix-index.nix  # comma + nix-locate（nix-index-database）
│   │       └── p10k.zsh      # Powerlevel10kテーマ設定
│   │
│   ├── overlays/             # Nixpkgsオーバーレイ
│   ├── pkgs/                 # カスタムパッケージ
│   └── docs/                 # Nix運用ドキュメント
│       ├── guide.md          # 共通ガイド
│       ├── guide-macos.md    # macOS専用
│       ├── guide-ubuntu.md   # Ubuntu専用
│       └── cheatsheet.md     # コマンド一覧
│
├── skills/                   # Agent Skills（agent-skills-nix で管理）
│   ├── agent-browser/        # 各スキルディレクトリ
│   ├── video-editing/        # （SKILL.md を含む）
│   └── ...
│
├── nvim/                     # Neovim設定（~/.config/nvim へリンク）
│   ├── init.lua              # エントリポイント
│   └── lua/
│       ├── config/           # 基本設定
│       │   ├── options.lua
│       │   ├── keymaps.lua
│       │   ├── autocmds.lua
│       │   └── lazy.lua      # プラグインマネージャー設定
│       └── plugins/          # プラグイン設定
│
├── karabiner/               # Karabiner-Elements設定（macOS専用）
│   └── karabiner.json       # ~/.config/karabiner/へリンク
│
├── claude/                  # Claude Code設定（~/.claude/へリンク）
│   ├── settings.json        # 全体設定
│   ├── mcp-servers.json     # Claude用MCP seed定義
│   ├── rules/               # ドメイン別ルール（常時ロード）
│   ├── hooks/               # 自動実行フック
│   ├── commands/            # スラッシュコマンド
│   ├── agents/              # カスタムエージェント
│   └── scripts/             # Claude補助スクリプト
│
├── .codex/                  # リポジトリローカル Codex assets
│   └── agents/              # Codex custom agents
│
└── codex/                   # Codex CLI設定（~/.codex/へリンク）
    └── config.toml          # 設定ファイル（AGENTS.md共有設定含む）
```

## シンボリックリンク管理

home-managerが以下のシンボリックリンクを自動管理：

| ソース                          | リンク先                                                     | 管理ファイル                                       |
| ------------------------------- | ------------------------------------------------------------ | -------------------------------------------------- |
| `nvim/`                         | `~/.config/nvim`                                             | `neovim.nix` (xdg.configFile)                      |
| `programs.ghostty.settings`     | `~/.config/ghostty/config`                                   | `ghostty.nix` (programs.ghostty)                   |
| `karabiner/karabiner.json`      | `~/.config/karabiner/karabiner.json`                         | `karabiner.nix` (mkOutOfStoreSymlink)              |
| `skills/`                       | `~/.claude/skills/` + `~/.codex/skills/`                     | `agent-skills.nix` (agent-skills-nix symlink-tree) |
| `claude/settings.json`          | `~/.claude/settings.json`                                    | `claude-code.nix` (mkOutOfStoreSymlink)            |
| `shared/GLOBAL_INSTRUCTIONS.md` | `~/.claude/CLAUDE.md`                                        | `claude-code.nix` (mkOutOfStoreSymlink)            |
| `claude/rules/`                 | `~/.claude/rules/`                                           | `claude-code.nix` (mkOutOfStoreSymlink)            |
| `claude/hooks/`                 | `~/.claude/hooks/`                                           | `claude-code.nix` (mkOutOfStoreSymlink)            |
| `claude/commands/`              | `~/.claude/commands/`                                        | `claude-code.nix` (mkOutOfStoreSymlink)            |
| `claude/agents/`                | `~/.claude/agents/`                                          | `claude-code.nix` (mkOutOfStoreSymlink)            |
| `codex/config.toml`             | `~/.codex/config.toml`                                       | `codex.nix` (mkOutOfStoreSymlink)                  |
| `shared/GLOBAL_INSTRUCTIONS.md` | `~/.codex/AGENTS.md`                                         | `codex.nix` (mkOutOfStoreSymlink)                  |

## Agent 運用の基本方針

- 共有したい知識は `skills/` と project docs に置く
- Claude 固有の強制は `claude/hooks/`, `claude/rules/`, `claude/commands/`, `claude/agents/` に置く
- Codex 固有の custom agent は `.codex/agents/` に置く
- Claude plugin 本体や runtime cache は source of truth にしない
- Claude の user-level MCP は `claude/mcp-servers.json` を seed とし、`~/.claude.json` へ同期する
- plugin 棚卸し結果は `docs/claude-plugin-audit.md` に残す

詳細: [docs/agent-platforms.md](./agent-platforms.md)

## Claude Code 指示の強度階層

Claude への指示は強度順に以下の仕組みで管理する:

```
Hook (自動強制)  > Rule (常時ロード)  > CLAUDE.md (人格)  > Skill (オンデマンド)
claude/hooks/      claude/rules/        shared/GLOBAL_...    skills/*/SKILL.md
```

| 階層      | 配置先                          | 役割                               | 例                                          |
| --------- | ------------------------------- | ---------------------------------- | ------------------------------------------- |
| Hook      | `claude/hooks/*.sh`             | 違反を自動検出・ブロック           | emoji-guard, secret-guard, ai-slop-guard    |
| Rule      | `claude/rules/*.md`             | ドメイン別の明示的指示             | code-conventions, workflow, nix-environment |
| CLAUDE.md | `shared/GLOBAL_INSTRUCTIONS.md` | 人格・行動原則（薄く保つ）         | 忖度禁止、調査と検証の義務                  |
| Skill     | `skills/*/SKILL.md`             | 複雑なドメイン知識（オンデマンド） | swift-dev-toolkit, video-editing            |

学習内容の蓄積先も同じ階層で選択する:

- 自動防止できるもの → Hook 作成
- 明示的な指示が必要 → Rule 作成/更新
- 複雑なワークフロー知識 → Skill 作成
- CLAUDE.md への lessons 蓄積は避ける

## よくあるタスクと編集場所

### CLIツール/パッケージを追加

**編集:** `nix/home-manager/programs/packages.nix`

```nix
commonPackages = with pkgs; [
  # ここに追加
  ripgrep
  fd
];
```

macOS専用は `darwinPackages` に追加。

### Node系CLIを追加

**編集:** `nix/home-manager/programs/packages.nix`

`nixpkgs` にある CLI は `commonPackages` / `darwinPackages` に追加。
`nixpkgs` にない npm CLI は `nix/pkgs/<name>/` に custom package を作ってから `commonPackages` に追加。
詳細: [docs/guides/nix-npm-packages.md](guides/nix-npm-packages.md)

### GUIアプリを追加（macOS）

**編集:** `nix/darwin/configuration.nix`

```nix
homebrew.casks = [
  # ここに追加
  "firefox"
];
```

### シェルエイリアスを追加

**編集:** `nix/home-manager/programs/zsh.nix`

エイリアスは `cmd + desc` 形式で定義（ヘルプ自動生成のため）：

```nix
generalAliases = {
  myalias = {cmd = "some-command"; desc = "説明文";};
};
```

カテゴリ：

- `generalAliases` - 汎用（両OS共通）
- `nixCommonAliases` - Nix共通
- `nixDarwinAliases` / `nixLinuxAliases` - Nix OS別
- `dirDarwinAliases` / `dirLinuxAliases` - ディレクトリ移動
- `claudeAliases` - Claude Code関連

詳細: [docs/guides/alias-auto-help.md](guides/alias-auto-help.md)

### 環境変数を追加

**編集:** `nix/home-manager/programs/packages.nix`

```nix
home.sessionVariables = {
  EDITOR = "nvim";
  # ここに追加
};
```

### PATHを追加

**編集:** `nix/home-manager/programs/packages.nix`

```nix
home.sessionPath = [
  "$HOME/.local/bin"
  # ここに追加
];
```

### Git設定を変更

**編集:** `nix/home-manager/programs/git.nix`

### Neovim設定を変更

**編集:** `nvim/` ディレクトリ内のファイル

### Ghostty設定を変更

**編集:** `nix/home-manager/programs/ghostty.nix`

### カスタムスキルを追加

**編集:** `skills/` に新しいディレクトリを作成し `SKILL.md` を配置

```
skills/my-new-skill/
└── SKILL.md
```

自作スキルは `enableAll = ["custom"]` により自動で有効化される。

Claude / Codex の両方で使いたいものは、plugin や command に閉じずまず `skills/` を検討する。

### 公式スキルを有効化

**編集:** `nix/home-manager/programs/agent-skills.nix`

```nix
skills.enable = [
  "pdf"
  "xlsx"
];
```

### Claude の MCP seed を更新

**編集:** `claude/mcp-servers.json`

Claude の実ランタイム設定は `~/.claude.json` にあり、そのままでは dotfiles 管理されない。
`claude/mcp-servers.json` を source of truth にして、必要に応じて `claude/scripts/sync-mcp-servers.py` で同期する。

### Karabiner設定を変更

**編集:** `karabiner/karabiner.json`

### Claude Code設定を変更

**編集:** `claude/settings.json`

### Claude の hooks / rules / commands / agents を変更

**編集:** `claude/` 以下の対応ディレクトリ

Claude 固有の強制や UX はここで管理する。共有知識を増やしたいときは `skills/` や project docs を優先。

### Claude Codeコマンドを追加

**編集:** `claude/commands/` に `.md` ファイルを作成

```markdown
---
name: command-name
description: コマンドの説明
---

# Command Name

コマンドの指示...
```

### Claude Codeエージェントを追加

**編集:** `claude/agents/` に `.md` ファイルを作成

```markdown
---
name: agent-name
description: エージェントの説明
model: haiku
tools:
  - Read
  - Glob
---

# Agent Name

エージェントの指示...
```

### Codex設定を変更

**編集:** `codex/config.toml`

```toml
# CLAUDE.md を共有で読み込む
project_doc_fallback_filenames = ["CODEX.md", "AGENTS.md", "CLAUDE.md"]

[features]
skills = true
```

### Codex custom agent を追加

**編集:** `.codex/agents/*.toml`

Codex では Claude の Markdown agent 定義はそのまま使えない。role ごとに TOML で定義する。

### macOSシステム設定を変更

**編集:** `nix/darwin/configuration.nix` の `system.defaults`

## OS分岐パターン

```nix
{ pkgs, lib, ... }:
let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
in {
  # 条件付き設定
  some.option = lib.mkIf isDarwin "darwin value";

  # リストのマージ
  packages = commonPkgs ++ (if isDarwin then darwinPkgs else linuxPkgs);
}
```

## ビルドコマンド

| OS    | コマンド                      | エイリアス |
| ----- | ----------------------------- | ---------- |
| macOS | `nh darwin switch ~/dotfiles -H <hostname>` | `dr` |
| Linux | `nh home switch ~/dotfiles -c <user>@linux` | `dr` |

## 重要な注意事項

1. **変更後は必ず `dr` でリビルド**
2. **Nix設定のフォーマット**: `nix fmt` で整形可能
3. **パッケージ検索**: `nix search nixpkgs <name>` または https://search.nixos.org/packages
4. **home-managerオプション検索**: https://home-manager-options.extranix.com/
5. **nix-darwinオプション検索**: https://daiderd.com/nix-darwin/manual/index.html

## flake.nixの構造

- `inputs`: 依存関係（nixpkgs, home-manager, nix-darwin, nix-index-database, agent-skills-nix等）
- `outputs`:
  - `darwinConfigurations.RMB`: macOS設定
  - `homeConfigurations."r1ca18@linux"`: Linux設定

### プロジェクトごとの開発環境を作る

dotfilesにはプロジェクト固有ツール（nodejs, pnpm, uv等）を入れない。各プロジェクトに `flake.nix` + `.envrc` を置く。

```bash
cd my-project
nix flake init -t github:akirak/flake-templates#minimal
git add flake.nix
echo "use flake" > .envrc
direnv allow
```

`.envrc` の扱いはプロジェクトごとに決める。必要ならローカル or リポジトリの `.gitignore` で管理する。
詳細: [docs/guides/project-env.md](guides/project-env.md)

## 既存ドキュメント

詳細な運用方法は以下を参照：

- `docs/guides/project-env.md` - プロジェクトごとの開発環境（flake + direnv + agent-skills）
- `docs/agent-platforms.md` - Claude / Codex / plugin / MCP の責務分離と移行方針
- `docs/claude-plugin-audit.md` - Claude plugin / runtime skill の棚卸し
- `docs/guides/skills.md` - Agent Skills運用ガイド（スキル一覧・追加方法）
- `nix/docs/guide.md` - 共通運用ガイド
- `nix/docs/cheatsheet.md` - コマンドチートシート
