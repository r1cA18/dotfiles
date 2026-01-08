# Ubuntu/Linux セットアップガイド

home-manager (standalone) を使った Ubuntu/Linux 環境のセットアップと運用方法。

## 目次

1. [初回セットアップ](#初回セットアップ)
2. [日常の運用](#日常の運用)
3. [Linux 固有の設定](#linux-固有の設定)
4. [macOS との違い](#macos-との違い)
5. [トラブルシューティング](#トラブルシューティング)

---

## 初回セットアップ

### 1. Nix インストール

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

ターミナルを再起動。

### 2. リポジトリ clone

```bash
git clone https://github.com/r1cA18/dotfiles.git ~/dotfiles
```

### 3. 初回ビルド

```bash
cd ~/dotfiles/nix
nix run home-manager -- switch --flake .#r1ca18@linux
```

これで以下が自動的にセットアップされます：

- CLI ツール (Node.js, ripgrep, fd など)
- Zsh + oh-my-zsh + Powerlevel10k
- Git, Neovim の設定
- Ghostty 設定

### 4. デフォルトシェルを Zsh に変更

```bash
# Zsh のパスを確認
which zsh
# 通常: /home/r1ca18/.nix-profile/bin/zsh

# /etc/shells に追加
echo "$HOME/.nix-profile/bin/zsh" | sudo tee -a /etc/shells

# デフォルトシェルを変更
chsh -s "$HOME/.nix-profile/bin/zsh"
```

ログアウト & ログイン。

### 5. フォント設定

```bash
# フォントキャッシュを更新
fc-cache -fv
```

ターミナルアプリのフォント設定で `JetBrainsMono Nerd Font` を選択。

---

## 日常の運用

### 設定変更のフロー

```
1. 設定ファイルを編集
2. dr でリビルド
3. 問題なければ git commit & push
```

### よく使うエイリアス

| Alias | 説明 |
|-------|------|
| `dr` | `home-manager switch` - 設定を適用 |
| `dp` | `home-manager generations` - 世代一覧 |
| `du` | 依存を更新 (flake.lock) |
| `ds` | パッケージ検索 |
| `dg` | 古い世代を削除 |

### 定期メンテナンス

```bash
# 週1回: 依存を最新化
du && dr
git add flake.lock && git commit -m "chore: update flake.lock"

# 月1回: ディスク容量を確保
dg
```

---

## Linux 固有の設定

### home-manager で管理できること

- CLI ツール (`home.packages`)
- シェル設定 (`programs.zsh`)
- エディタ設定 (`xdg.configFile`)
- 環境変数 (`home.sessionVariables`)
- PATH (`home.sessionPath`)

### GUI アプリの管理

Linux では Homebrew の代わりに、システムのパッケージマネージャを使用：

```bash
# Ubuntu
sudo apt install アプリ名

# または Flatpak
flatpak install アプリ名
```

> **Note**: GUI アプリは Nix での管理対象外としています。

### 設定ファイルのパス

| 設定 | パス |
|-----|-----|
| Neovim | `~/.config/nvim/` |
| Ghostty | `~/.config/ghostty/config` |
| Zsh | `~/.zshrc` (home-manager 管理) |

---

## macOS との違い

### 管理構造

| 項目 | macOS | Linux |
|-----|-------|-------|
| システム設定 | nix-darwin | 対象外 |
| ユーザー設定 | home-manager | home-manager |
| GUI アプリ | Homebrew | システムのpkg manager |

### コマンドの違い

| 操作 | macOS | Linux |
|-----|-------|-------|
| リビルド | `darwin-rebuild switch` | `home-manager switch` |
| ロールバック | `darwin-rebuild --rollback` | 世代を指定して switch |

### 共通で動作するもの

- CLI ツール (Nix packages)
- Zsh + oh-my-zsh
- Powerlevel10k
- Git 設定
- Neovim 設定
- Ghostty 設定

### macOS 専用

- Homebrew 管理
- macOS システム設定 (Dock, Finder など)
- Touch ID for sudo
- Karabiner

---

## トラブルシューティング

### Zsh が起動しない

```bash
# Zsh が正しくインストールされているか確認
which zsh
ls -la ~/.nix-profile/bin/zsh

# パスが通っているか確認
echo $PATH | grep nix
```

### home-manager コマンドが見つからない

```bash
# パスを通す
export PATH="$HOME/.nix-profile/bin:$PATH"

# または nix run で実行
nix run home-manager -- switch --flake ~/dotfiles/nix#r1ca18@linux
```

### リビルドが失敗する

```bash
# 詳細エラーを確認
home-manager switch --flake ~/dotfiles/nix#r1ca18@linux --show-trace

# 変更を戻す
cd ~/dotfiles && git checkout .
```

### 特定の世代に戻したい

```bash
# 世代一覧を確認
home-manager generations

# 特定の世代に切り替え
/nix/store/xxx-home-manager-generation/activate
```

### ディスク容量が足りない

```bash
dg   # 古い世代を削除

# より強力なクリーンアップ
nix-collect-garbage -d
nix store gc
```

---

## 新しい Linux マシンへの移行

```bash
# 1. Nix インストール
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# 2. Clone
git clone https://github.com/r1cA18/dotfiles.git ~/dotfiles

# 3. ビルド
cd ~/dotfiles/nix
nix run home-manager -- switch --flake .#r1ca18@linux

# 4. デフォルトシェル変更
echo "$HOME/.nix-profile/bin/zsh" | sudo tee -a /etc/shells
chsh -s "$HOME/.nix-profile/bin/zsh"
```

---

## Tips

### WSL2 での利用

このdotfilesはWSL2でも動作します：

```bash
# 同じ手順でセットアップ
nix run home-manager -- switch --flake .#r1ca18@linux
```

### サーバー環境での利用

最小限の設定だけ使いたい場合は、`packages.nix` の重いパッケージ (texliveFull など) をコメントアウトしてください。
