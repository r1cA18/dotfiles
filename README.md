# dotfiles

Nix (nix-darwin + home-manager) によるクロスプラットフォーム環境管理

## サポート環境

| OS | 管理方法 | ビルドコマンド |
|----|---------|---------------|
| **macOS** | nix-darwin + home-manager | `dr` |
| **Ubuntu/Linux** | home-manager (standalone) | `dr` |

## クイックスタート

### 1. Nix インストール

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

### 2. dotfiles クローン & ビルド

```bash
git clone https://github.com/r1cA18/dotfiles.git ~/dotfiles
cd ~/dotfiles/nix

# macOS
nix run nix-darwin -- switch --flake .#RMB

# Linux
nix run home-manager -- switch --flake .#r1ca18@linux
```

### 3. 以降の更新

```bash
dr  # rebuild
```

## よく使うコマンド

```bash
h      # エイリアス一覧（説明付き）
hv     # エイリアス一覧（コマンド表示）
dr     # Nixリビルド
du     # flake更新
```

### Claude Code

```bash
cc     # Claude Code起動
ccc    # 前回のセッション継続
ccr    # セッション選択して再開
ccd    # 承認スキップモード
```

## 構造

```
dotfiles/
├── nix/
│   ├── flake.nix                 # エントリポイント
│   ├── darwin/configuration.nix  # macOS設定、Homebrew
│   └── home-manager/
│       ├── home.nix              # ユーザー設定
│       └── programs/
│           ├── packages.nix      # パッケージ、PATH、npmパッケージ
│           ├── zsh.nix           # エイリアス（自動ヘルプ付き）
│           ├── git.nix           # Git
│           ├── neovim.nix        # Neovim
│           ├── ghostty.nix       # Ghostty
│           └── karabiner.nix     # Karabiner
├── nvim/                         # Neovim設定
├── ghostty/                      # Ghostty設定
├── karabiner/                    # Karabiner設定
└── docs/                         # ドキュメント
```

## 自動インストールされるもの

### npmパッケージ（bun経由）

`dr`実行時に自動インストール：
- `@anthropic-ai/claude-code`
- `@google/gemini-cli`
- `@openai/codex`
- `agent-browser`
- `@ast-grep/cli`

### Skills

- **ui-skills** - UI/UXレビュー用スキル
- **vercel-react-best-practices** - React/Next.jsベストプラクティス
- **web-design-guidelines** - Webデザインガイドライン

## ドキュメント

| ドキュメント | 説明 |
|-------------|------|
| [docs/README.md](docs/README.md) | ドキュメント目次 |
| [docs/architecture.md](docs/architecture.md) | アーキテクチャ詳細 |
| [docs/guides/](docs/guides/) | 各種ガイド |

## 参考

- [nix-darwin](https://github.com/nix-darwin/nix-darwin)
- [home-manager](https://github.com/nix-community/home-manager)
- [Nix パッケージ検索](https://search.nixos.org/packages)
