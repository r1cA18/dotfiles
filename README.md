# dotfiles

nix-darwin + home-manager による macOS 環境管理

## 構造

```
dotfiles/
├── nix/
│   ├── flake.nix                 # エントリポイント
│   ├── darwin/
│   │   └── configuration.nix     # macOS システム設定
│   ├── home-manager/
│   │   ├── home.nix              # ユーザー設定
│   │   └── programs/             # 分割された設定
│   │       ├── zsh.nix           # Zsh + oh-my-zsh
│   │       └── p10k.zsh          # Powerlevel10k テーマ設定
│   └── docs/                     # ドキュメント
├── nvim/                         # Neovim 設定
├── ghostty/                      # Ghostty 設定
└── karabiner/                    # Karabiner 設定
```

## クイックスタート

```bash
# Nix インストール
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# clone & 適用
git clone https://github.com/r1cA18/dotfiles.git ~/dotfiles
cd ~/dotfiles/nix
nix run nix-darwin -- switch --flake .#RMB

# 以降は
dr  # rebuild
```

## 基本操作

| Alias | Description |
|-------|-------------|
| `dr` | 設定を適用 |
| `du` | 依存を更新 |
| `ds` | パッケージ検索 |
| `dg` | ゴミ掃除 |

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
| [guide.md](nix/docs/guide.md) | 運用ガイド |
| [cheatsheet.md](nix/docs/cheatsheet.md) | コマンド一覧 |

## 参考

- [nix-darwin](https://github.com/nix-darwin/nix-darwin)
- [home-manager](https://github.com/nix-community/home-manager)
- [Nix パッケージ検索](https://search.nixos.org/packages)
