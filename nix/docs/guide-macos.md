# macOS セットアップガイド

nix-darwin + home-manager を使った macOS 環境のセットアップと運用方法。

## 目次

1. [初回セットアップ](#初回セットアップ)
2. [日常の運用](#日常の運用)
3. [macOS 固有の設定](#macos-固有の設定)
4. [GUI アプリの管理](#gui-アプリの管理)
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
cd ~/dotfiles
nix run nix-darwin -- switch --flake .#RMB
```

これで以下が自動的にセットアップされます：

- CLI ツール (Node.js, ripgrep, fd など)
- Homebrew & GUI アプリ (Chrome, VSCode, Ghostty など)
- macOS システム設定 (Dock, Finder, キーボード など)
- Zsh + oh-my-zsh + Powerlevel10k
- Git, Neovim の設定

### 4. フォント設定

Ghostty や VSCode で Nerd Font を使うため、システムでフォントを認識させる：

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
| `dr` | `nh darwin switch ~/dotfiles -H <hostname>` - 設定を適用 |
| `db` | `nh darwin build ~/dotfiles -H <hostname>` - ビルドのみ |
| `dp` | `darwin-rebuild --rollback` - 戻す |
| `du` | 依存を更新 (flake.lock) |
| `ds` | パッケージ検索 |
| `dg` | 古い世代と store path を削除 |

### 定期メンテナンス

```bash
# 週1回: 依存を最新化
du && dr
git add flake.lock && git commit -m "chore: update flake.lock"

# 月1回: ディスク容量を確保
dg
```

---

## macOS 固有の設定

### ファイル構成

```
darwin/
└── configuration.nix   # macOS システム設定
    ├── homebrew        # GUI アプリ管理
    ├── system.defaults # Dock, Finder, キーボードなど
    └── security        # Touch ID for sudo
```

### システム設定の変更

`darwin/configuration.nix`:

```nix
system.defaults = {
  # Dock
  dock = {
    autohide = true;
    show-recents = false;
  };

  # Finder
  finder = {
    AppleShowAllExtensions = true;
    _FXShowPosixPathInTitle = true;
  };

  # キーボード
  NSGlobalDomain = {
    KeyRepeat = 2;           # 速い
    InitialKeyRepeat = 15;   # 速い
  };

  # トラックパッド
  trackpad = {
    Clicking = true;
    TrackpadThreeFingerDrag = true;
  };
};
```

設定オプション: [nix-darwin manual](https://daiderd.com/nix-darwin/manual/index.html)

### Touch ID for sudo

デフォルトで有効になっています：

```nix
security.pam.services.sudo_local.touchIdAuth = true;
```

---

## GUI アプリの管理

### Homebrew Casks

`darwin/configuration.nix`:

```nix
homebrew.casks = [
  "google-chrome"
  "visual-studio-code"
  "ghostty"
  "slack"        # ← 追加
];
```

### Mac App Store

```nix
homebrew.masApps = {
  "LINE" = 539883307;
};
```

App ID の調べ方:

```bash
mas search "アプリ名"
```

### 管理の使い分け

| 種類 | 管理場所 |
|-----|---------|
| CLI ツール | `home-manager/programs/packages.nix` (Nix) |
| GUI アプリ | `darwin/configuration.nix` (Homebrew) |
| App Store | `darwin/configuration.nix` (masApps) |

---

## トラブルシューティング

### "Git tree is dirty" 警告

コミットしていない変更がある。無視して OK。

### リビルドが失敗する

```bash
# 詳細エラーを確認
sudo darwin-rebuild switch --flake ~/dotfiles --show-trace

# 変更を戻す
cd ~/dotfiles && git checkout .
```

### Homebrew でエラー

```bash
# Homebrew 自体を更新
brew update && brew upgrade
```

### 設定を戻したい

```bash
dp   # 前の世代にロールバック
```

### ディスク容量が足りない

```bash
dg   # 古い世代を削除
```

---

## 新しい Mac への移行

```bash
# 1. Nix インストール
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# 2. Clone
git clone https://github.com/r1cA18/dotfiles.git ~/dotfiles

# 3. ビルド
cd ~/dotfiles
nix run nix-darwin -- switch --flake .#RMB
```

これだけで環境が完全に再現されます。
