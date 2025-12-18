# Nix dotfiles 運用ガイド

このガイドでは、Nix (nix-darwin + home-manager) を使った dotfiles の運用方法を説明します。

## 目次

1. [基本的な運用フロー](#基本的な運用フロー)
2. [パッケージの追加・削除](#パッケージの追加削除)
3. [GUI アプリの追加](#gui-アプリの追加)
4. [macOS 設定のカスタマイズ](#macos-設定のカスタマイズ)
5. [設定の変更](#設定の変更)
6. [よく使うコマンド](#よく使うコマンド)
7. [トラブルシューティング](#トラブルシューティング)
8. [ファイル構成](#ファイル構成)

---

## 基本的な運用フロー

```
1. 設定ファイルを編集
2. dr でリビルド
3. 問題なければ git commit & push
```

### 具体例

```bash
# 1. 設定を編集（例：パッケージ追加）
vim ~/dotfiles/nix/home-manager/home.nix

# 2. リビルドして適用
dr

# 3. 動作確認して問題なければコミット
cd ~/dotfiles
git add .
git commit -m "feat: add ripgrep"
git push
```

---

## パッケージの追加・削除

### CLI ツールを追加する

`home-manager/home.nix` の `packages` に追加：

```nix
home.packages = with pkgs; [
  nodejs_latest
  neovim
  htop   # ← 追加
  tree   # ← 追加
];
```

追加したら `dr` を実行。

### パッケージを削除する

リストから削除して `dr` するだけ。

### パッケージを探す

```bash
ds ripgrep   # エイリアス使用
# または
nix search nixpkgs ripgrep
```

Web: [search.nixos.org](https://search.nixos.org/packages)

### よく使うパッケージ例

| パッケージ | 説明 |
|-----------|------|
| `ripgrep` | 高速 grep |
| `fd` | 高速 find |
| `fzf` | ファジーファインダー |
| `bat` | cat の代替 |
| `eza` | ls の代替 |
| `jq` | JSON 処理 |
| `gh` | GitHub CLI |

---

## GUI アプリの追加

`darwin/configuration.nix` の `homebrew.casks` に追加：

```nix
homebrew = {
  enable = true;
  casks = [
    "google-chrome"
    "visual-studio-code"
    "slack"        # ← 追加
    "spotify"      # ← 追加
  ];
};
```

### Mac App Store アプリ

```nix
homebrew.masApps = {
  "LINE" = 539883307;
  "Keynote" = 409183694;
};
```

App ID の調べ方:
```bash
mas search "LINE"
# 出力: 539883307  LINE (...)
```

### Nix と Homebrew の使い分け

| 種類 | どこで管理 |
|-----|-----------|
| CLI ツール | `home.packages` (Nix) |
| GUI アプリ | `homebrew.casks` |
| App Store | `homebrew.masApps` |

---

## macOS 設定のカスタマイズ

`darwin/configuration.nix` で設定：

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
    KeyRepeat = 2;
    InitialKeyRepeat = 15;
  };

  # トラックパッド
  trackpad = {
    Clicking = true;
    TrackpadThreeFingerDrag = true;
  };

  # スクリーンショット
  screencapture = {
    location = "~/Downloads";
  };
};
```

設定オプション: [nix-darwin options](https://daiderd.com/nix-darwin/manual/index.html)

---

## 設定の変更

### Git

`home-manager/programs/git.nix`:

```nix
programs.git = {
  enable = true;
  settings = {
    user.name = "your-name";
    user.email = "your-email@example.com";
    init.defaultBranch = "main";
  };
};
```

### Zsh エイリアス

`home-manager/programs/zsh.nix`:

```nix
programs.zsh.shellAliases = {
  ll = "ls -la";
  g = "git";
};
```

### 環境変数

```nix
home.sessionVariables = {
  EDITOR = "nvim";
};
```

### PATH

```nix
home.sessionPath = [
  "$HOME/.local/bin"
];
```

---

## よく使うコマンド

> 詳細は [cheatsheet.md](./cheatsheet.md) を参照

| Alias | 説明 |
|-------|------|
| `dr` | 設定を適用 (rebuild) |
| `db` | ビルドのみ |
| `dp` | 前のバージョンに戻す |
| `du` | 依存を更新 |
| `ds` | パッケージを検索 |
| `dg` | 古い世代を削除 |

### 定期的な更新

```bash
du       # 依存を更新
dr       # リビルド
git add flake.lock
git commit -m "chore: update flake.lock"
```

---

## トラブルシューティング

### "Git tree is dirty" 警告

**意味**: コミットしていない変更がある
**対処**: 無視して OK

### パッケージが見つからない

```bash
ds パッケージ名   # 正しい名前を検索
```

### リビルドが失敗する

```bash
# エラー詳細を見る
sudo darwin-rebuild switch --flake ~/dotfiles/nix --show-trace

# 変更を戻す
git checkout .
```

### ディスク容量が足りない

```bash
dg   # 古い世代を削除
```

### 設定ミスで戻したい

```bash
dp   # 前のバージョンにロールバック
```

---

## ファイル構成

```
~/dotfiles/nix/
├── flake.nix                 # エントリポイント
├── darwin/
│   └── configuration.nix     # macOS システム設定
├── home-manager/
│   ├── home.nix              # ユーザー設定（メイン）
│   └── programs/
│       ├── git.nix           # Git 設定
│       └── zsh.nix           # Zsh 設定
└── docs/
    ├── guide.md              # このガイド
    └── cheatsheet.md         # コマンド一覧
```

### 編集頻度

| ファイル | 頻度 | 内容 |
|---------|------|------|
| `home.nix` | 高 | パッケージ、環境変数 |
| `programs/*.nix` | 中 | Git, Zsh 設定 |
| `configuration.nix` | 低 | macOS 設定、GUI アプリ |
| `flake.nix` | 低 | 依存関係 |

---

## 新しい Mac への移行

```bash
# 1. Nix インストール
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# 2. clone
git clone https://github.com/r1cA18/dotfiles.git ~/dotfiles

# 3. 初回ビルド
cd ~/dotfiles/nix
nix run nix-darwin -- switch --flake .#RMB
```

これだけで同じ環境が再現されます。

---

## Tips

### programs.xxx を使う

home-manager は多くのツールを `programs.xxx` で設定できます：

```nix
programs.fzf.enable = true;   # fzf + シェル統合
programs.eza.enable = true;   # eza + エイリアス
programs.bat.enable = true;   # bat
```

`packages` に追加するより設定が楽な場合があります。

### 設定オプションを調べる

- [home-manager options](https://home-manager-options.extranix.com/)
- [nix-darwin options](https://daiderd.com/nix-darwin/manual/index.html)
