# dotfiles

Nix (nix-darwin + home-manager) によるクロスプラットフォーム環境管理

## サポート環境

| OS                 | 管理方法                                   | ビルドコマンド            |
| ------------------ | ------------------------------------------ | ------------------------- |
| **macOS**          | nix-darwin + home-manager                  | `dr`                      |
| **Ubuntu homelab** | Nix app + Ansible + home-manager + Compose | `nix run .#homelab-apply` |

## クイックスタート

### 1. Nix インストール

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

### 2. dotfiles クローン & ビルド

```bash
git clone https://github.com/r1cA18/dotfiles.git ~/dotfiles
cd ~/dotfiles

# macOS (RMB)
nix run nix-darwin -- switch --flake .#RMB

# macOS (r1ca18lab)
nix run nix-darwin -- switch --flake .#r1ca18lab

# Ubuntu homelab
nix run .#homelab-apply
```

> **Linux初回セットアップの注意点**
>
> `nix run` がエラーになる場合は experimental features を有効化してから再実行:
>
> ```bash
> echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf
> sudo systemctl restart nix-daemon
> ```
>
> Ghostty を使っている場合、SSH先に terminfo を転送する（Mac側で実行）:
>
> ```bash
> infocmp -x xterm-ghostty | ssh USER@HOST 'tic -x /dev/stdin'
> ```

### 3. 以降の更新

```bash
dr  # macOS全体またはLinuxのHome Managerだけを適用
nix run ~/dotfiles#homelab-apply  # Linuxのsystem設定とHome Managerを一括適用
```

## よく使うコマンド

```bash
h      # エイリアス一覧（説明付き）
hv nix # エイリアス一覧を絞り込み
dr     # macOS全体またはLinuxのHome Managerをリビルド
du     # flake更新
```

### Claude Code

```bash
cl     # Claude Code起動
clc    # 前回のセッション継続
clr    # セッション選択して再開
cld    # 承認スキップモード
```

### Codex

```bash
codex          # Codex 起動
codex mcp list # Codex 側の MCP 設定確認
```

## 構造

```
dotfiles/
├── flake.nix                     # flake エントリポイント
├── flake.lock                    # 依存ロック
├── nix/
│   ├── darwin/configuration.nix  # macOS設定、Homebrew
│   └── home-manager/
│       ├── home.nix              # ユーザー設定
│       ├── hosts/homelab.nix     # Ubuntu homelab profile
│       └── programs/
│           ├── packages.nix      # CLIパッケージ、PATH
│           ├── zsh.nix           # エイリアス（自動ヘルプ付き）
│           ├── nh.nix            # nh設定
│           ├── git.nix           # Git
│           ├── neovim.nix        # Neovim
│           ├── ghostty.nix       # Ghostty設定
│           └── karabiner.nix     # Karabiner
├── nvim/                         # Neovim設定
├── karabiner/                    # Karabiner設定
├── homelab/                      # Ansible・service起動・移行手順
└── docs/                         # ドキュメント
```

## 自動インストールされるもの

### CLIツール（Nix経由）

`dr`実行時に自動インストール：

- `nh`
- `gemini-cli`
- `codex`
- `agent-browser`
- `ast-grep`

`Claude Code` 本体は native install 前提。dotfiles では `~/.claude/` 配下の設定と MCP seed だけを管理する。

### Skills

- **ui-skills** - UI/UXレビュー用スキル
- **vercel-react-best-practices** - React/Next.jsベストプラクティス
- **web-design-guidelines** - Webデザインガイドライン
- **design-md / enhance-prompt / react-components / shadcn-ui** - Stitch 周辺 workflow

CLI 依存の skill 運用は [docs/guides/skills.md](docs/guides/skills.md) にまとめてある。

## ドキュメント

| ドキュメント                                               | 説明                    |
| ---------------------------------------------------------- | ----------------------- |
| [docs/README.md](docs/README.md)                           | ドキュメント目次        |
| [docs/architecture.md](docs/architecture.md)               | アーキテクチャ詳細      |
| [docs/agent-platforms.md](docs/agent-platforms.md)         | Claude / Codex 運用整理 |
| [docs/claude-plugin-audit.md](docs/claude-plugin-audit.md) | Claude plugin 棚卸し    |
| [docs/guides/](docs/guides/)                               | 各種ガイド              |
| [homelab/README.md](homelab/README.md)                     | 新homelab構築・移行     |

## 参考

- [nix-darwin](https://github.com/nix-darwin/nix-darwin)
- [home-manager](https://github.com/nix-community/home-manager)
- [Nix パッケージ検索](https://search.nixos.org/packages)
