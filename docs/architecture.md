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
├── agents/                   # Claude / Codex 共有agent資産
│   ├── INSTRUCTIONS.md       # 共有instruction本体
│   ├── rules/                # 共有rule
│   ├── hooks/                # 製品非依存のhook実装
│   └── skills/               # Agent Skillsのsource of truth
│
├── nix/                      # Nix設定（メイン）
│   ├── darwin/               # macOS専用 (nix-darwin)
│   │   └── configuration.nix # システム設定、Homebrew管理
│   │
│   ├── home-manager/         # ユーザー設定
│   │   ├── home.nix          # home-managerエントリポイント
│   │   ├── hosts/            # host固有profile
│   │   │   └── homelab.nix   # Ubuntu homelabとSyncthing folder
│   │   └── programs/         # 各プログラムの設定
│   │       ├── packages.nix  # パッケージ、PATH、環境変数
│   │       ├── zsh.nix       # Zsh、abbr、help
│   │       ├── nh.nix        # nh 設定
│   │       ├── git.nix       # Git設定
│   │       ├── neovim.nix    # Neovim本体と開発ツール供給
│   │       ├── ghostty.nix   # Ghostty設定（programs.ghostty）
│   │       ├── karabiner.nix # Karabiner（karabiner/へのシンボリックリンク）
│   │       ├── claude-code.nix # Claude config symlink + MCP sync
│   │       ├── claude-code-proxy.nix # GPT backend wrapper + user service
│   │       ├── antigravity.nix # Antigravity CLI activation + updater
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
├── homelab/                 # Ubuntu systemとservice起動設定
│   ├── ansible/             # package・daemon・firewall・power・Compose起動
│   └── README.md            # bootstrap・data同期・検証
│
├── claude/                  # Claude Code設定（~/.claude/へリンク）
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
└── codex/                   # Codex設定
    ├── hooks.json           # Codex lifecycle hook登録
    └── prompts/             # ~/.codex/prompts へリンク（skill呼び出し用）
```

## シンボリックリンク管理

home-managerが以下のシンボリックリンクを自動管理：

| ソース                                     | リンク先                                 | 管理ファイル                                       |
| ------------------------------------------ | ---------------------------------------- | -------------------------------------------------- |
| `nvim/`                                    | `~/.config/nvim`                         | `neovim.nix` (mkOutOfStoreSymlink)                 |
| `programs.ghostty.settings`                | `~/.config/ghostty/config`               | `ghostty.nix` (programs.ghostty)                   |
| `karabiner/karabiner.json`                 | `~/.config/karabiner/karabiner.json`     | `karabiner.nix` (mkOutOfStoreSymlink)              |
| `agents/skills/`                           | `~/.claude/skills/` + `~/.codex/skills/` | `agent-skills.nix` (agent-skills-nix symlink-tree) |
| `programs.claude-code.settings` (attrset)  | `~/.claude/settings.json`                | `claude-code.nix` (Nix生成)                        |
| `agents/INSTRUCTIONS.md` + `agents/rules/` | `~/.claude/CLAUDE.md`                    | `agent-instructions.nix` で結合                    |
| `claude/rules/`                            | `~/.claude/rules/`                       | `claude-code.nix` (mkOutOfStoreSymlink)            |
| `claude/hooks/`                            | `~/.claude/hooks/`                       | `claude-code.nix` (mkOutOfStoreSymlink)            |
| `claude/commands/`                         | `~/.claude/commands/`                    | `claude-code.nix` (mkOutOfStoreSymlink)            |
| `claude/agents/`                           | `~/.claude/agents/`                      | `claude-code.nix` (mkOutOfStoreSymlink)            |
| `nix/home-manager/programs/codex.nix`      | `~/.codex/config.toml`                   | Nix生成の writable copy                            |
| `agents/INSTRUCTIONS.md` + `agents/rules/` | `~/.codex/AGENTS.md`                     | `agent-instructions.nix` で結合                    |
| `agents/INSTRUCTIONS.md` + `agents/rules/` | `~/.gemini/GEMINI.md`                    | `agent-instructions.nix` で結合                    |
| `codex/hooks.json`                         | `~/.codex/hooks.json`                    | `codex.nix` (mkOutOfStoreSymlink)                  |
| `codex/prompts/`                           | `~/.codex/prompts/`                      | `codex.nix` (mkOutOfStoreSymlink)                  |

Claude account profileは`claude-code.nix`が生成する`clp`で管理する。
Codex account profileは`codex.nix`が生成する`cxp`で管理する。
新規runtime stateは各製品の`$XDG_STATE_HOME`配下へ置き、
共有設定だけをprimary profileからlinkする。
詳細は[Agent account profile管理](guides/agent-profiles.md)を参照。

## Agent 運用の基本方針

- 共有したい知識は `agents/skills/` と project docs に置く
- 製品非依存の hook 実装は `agents/hooks/` に置き、登録は各製品側で管理する
- Claude 固有の強制は `claude/hooks/`, `claude/rules/`, `claude/commands/`, `claude/agents/` に置く
- Codex 固有の custom agent は `.codex/agents/` に置く
- Codex custom prompt は deprecated なので、`codex/prompts/` には skill wrapper だけを置く
- Claude / Codex plugin 本体や runtime cache は source of truth にしない
- Claude の user-level MCP は `claude/mcp-servers.json` を seed とし、`~/.claude.json` へ同期する
- plugin 棚卸し結果は `docs/claude-plugin-audit.md` に残す

詳細: [docs/agent-platforms.md](./agent-platforms.md)

GPT backend版Claude Codeの起動・Proxy管理・profile管理は
[docs/guides/claude-code-gpt.md](guides/claude-code-gpt.md)を参照。

## Claude Code 指示の強度階層

Claude への指示は強度順に以下の仕組みで管理する:

```
Hook (自動強制)  > Rule (常時ロード)  > CLAUDE.md (人格)       > Skill (オンデマンド)
claude/hooks/      claude/rules/        agents/{INSTRUCTIONS,rules}  agents/skills/*/SKILL.md
```

| 階層      | 配置先                                     | 役割                               | 例                                       |
| --------- | ------------------------------------------ | ---------------------------------- | ---------------------------------------- |
| Hook      | `claude/hooks/*.sh`                        | 違反を自動検出・ブロック           | emoji-guard, secret-guard, ai-slop-guard |
| Rule      | `claude/rules/*.md`                        | ドメイン別の明示的指示             | tool-preferences, workflow               |
| CLAUDE.md | `agents/INSTRUCTIONS.md` + `agents/rules/` | 共有の人格・行動原則               | 文体、調査、実装、検証                   |
| Skill     | `agents/skills/*/SKILL.md`                 | 複雑なドメイン知識（オンデマンド） | swift-dev-toolkit, video-editing         |

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

`nvim/` は out-of-store symlink なので編集は即反映（`dr` 不要）。プラグインは lazy.nvim が
`nvim/lazy-lock.json` で管理し、バイナリ / grammar は Nix (`neovim.nix`) が供給する。
詳細: [docs/guides/neovim.md](guides/neovim.md)

### Ghostty設定を変更

**編集:** `nix/home-manager/programs/ghostty.nix`

### カスタムスキルを追加

**編集:** `agents/skills/` に新しいディレクトリを作成し `SKILL.md` を配置

```
agents/skills/my-new-skill/
└── SKILL.md
```

追加したスキル名を `nix/home-manager/programs/agent-skills.nix` の `skills.enable` に追加する。

Claude / Codex の両方で使いたいものは、plugin や command に閉じずまず `agents/skills/` を検討する。

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

**編集:** `nix/home-manager/programs/claude-code.nix`

`~/.claude/settings.json` は `programs.claude-code.settings` の attrset から生成される。
Nix が source of truth なので、`dr` のたびにこの attrset の値で上書きされる。

### Claude の hooks / rules / commands / agents を変更

**編集:** `claude/` 以下の対応ディレクトリ

Claude 固有の強制や UX はここで管理する。共有知識を増やしたいときは `agents/skills/` や project docs を優先。

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

**編集:** `nix/home-manager/programs/codex.nix`

`~/.codex/config.toml` は Nix から writable copy として生成される。
global な model / plugin / marketplace / MCP 設定は `codex.nix` に追加する。
Codex は user-level config を中心に扱うため、project flake で plugin や skill を切り替えない。

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

| OS                      | コマンド                                      | エイリアス |
| ----------------------- | --------------------------------------------- | ---------- |
| macOS                   | `nh darwin switch ~/dotfiles -H <hostname>`   | `dr`       |
| Linux user設定          | `nh home switch ~/dotfiles -c r1ca18@homelab` | `dr`       |
| Linux system + user設定 | `nix run ~/dotfiles#homelab-apply`            | なし       |

## 重要な注意事項

1. 変更後は対象に応じて`dr`または`homelab-apply`でリビルド
2. **Nix設定のフォーマット**: `nix fmt` で整形可能
3. **パッケージ検索**: `nix search nixpkgs <name>` または https://search.nixos.org/packages
4. **home-managerオプション検索**: https://home-manager-options.extranix.com/
5. **nix-darwinオプション検索**: https://daiderd.com/nix-darwin/manual/index.html

## flake.nixの構造

- `inputs`: 依存関係（nixpkgs, home-manager, nix-darwin, nix-index-database, agent-skills-nix等）
- `outputs`:
  - `darwinConfigurations.RMB`: macOS設定
  - `homeConfigurations."r1ca18@homelab"`: Ubuntu homelab設定

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
