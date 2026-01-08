# dotfiles

Nix (nix-darwin + home-manager) によるクロスプラットフォーム環境管理

## サポート環境

| OS | 管理方法 | ビルドコマンド |
|----|---------|---------------|
| **macOS** | nix-darwin + home-manager | `darwin-rebuild switch --flake .#RMB` |
| **Ubuntu/Linux** | home-manager (standalone) | `home-manager switch --flake .#r1ca18@linux` |

## 構造

```
dotfiles/
├── nix/
│   ├── flake.nix                 # エントリポイント
│   ├── darwin/
│   │   └── configuration.nix     # macOS システム設定
│   ├── home-manager/
│   │   ├── home.nix              # ユーザー設定 (共通)
│   │   └── programs/             # 分割された設定
│   │       ├── zsh.nix           # Zsh + oh-my-zsh (OS別エイリアス)
│   │       ├── packages.nix      # パッケージ
│   │       ├── git.nix           # Git
│   │       ├── neovim.nix        # Neovim
│   │       ├── ghostty.nix       # Ghostty (OS別パス)
│   │       ├── karabiner.nix     # Karabiner (macOS only)
│   │       └── p10k.zsh          # Powerlevel10k テーマ
│   └── docs/                     # ドキュメント
├── nvim/                         # Neovim 設定
├── ghostty/                      # Ghostty 設定
└── karabiner/                    # Karabiner 設定 (macOS only)
```

## クイックスタート

### 共通: Nix インストール

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

### macOS

```bash
git clone https://github.com/r1cA18/dotfiles.git ~/dotfiles
cd ~/dotfiles/nix
nix run nix-darwin -- switch --flake .#RMB

# 以降は
dr  # rebuild
```

### Ubuntu/Linux

```bash
git clone https://github.com/r1cA18/dotfiles.git ~/dotfiles
cd ~/dotfiles/nix
nix run home-manager -- switch --flake .#r1ca18@linux

# 以降は
dr  # rebuild (home-manager switch)
```

## 基本操作

### 共通エイリアス

| Alias | Description | macOS | Linux |
|-------|-------------|:-----:|:-----:|
| `dr` | 設定を適用 | ✅ | ✅ |
| `du` | 依存を更新 | ✅ | ✅ |
| `ds` | パッケージ検索 | ✅ | ✅ |
| `dg` | ゴミ掃除 | ✅ | ✅ |
| `db` | ビルドのみ | ✅ | - |
| `dp` | ロールバック / 履歴表示 | ✅ | ✅ |

### oh-my-zsh (git プラグイン)

| Alias | Description |
|-------|-------------|
| `gst` | git status |
| `gco` | git checkout |
| `gcb` | git checkout -b |
| `gp` | git push |
| `gl` | git pull |
| `ga` | git add |
| `gcmsg` | git commit -m |

詳細は [docs/cheatsheet.md](nix/docs/cheatsheet.md) を参照。

## ドキュメント

| Doc | Description |
|-----|-------------|
| [guide.md](nix/docs/guide.md) | 共通運用ガイド |
| [guide-macos.md](nix/docs/guide-macos.md) | macOS セットアップ & 運用 |
| [guide-ubuntu.md](nix/docs/guide-ubuntu.md) | Ubuntu/Linux セットアップ & 運用 |
| [cheatsheet.md](nix/docs/cheatsheet.md) | コマンド一覧 |

## 参考

- [nix-darwin](https://github.com/nix-darwin/nix-darwin)
- [home-manager](https://github.com/nix-community/home-manager)
- [Nix パッケージ検索](https://search.nixos.org/packages)
