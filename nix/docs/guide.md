# Nix dotfiles 共通ガイド

このガイドでは、macOS と Linux で共通の運用方法を説明します。

**OS別の詳細ガイド:**
- [macOS ガイド](./guide-macos.md)
- [Ubuntu/Linux ガイド](./guide-ubuntu.md)

## 目次

1. [基本的な運用フロー](#基本的な運用フロー)
2. [パッケージの追加・削除](#パッケージの追加削除)
3. [設定の変更](#設定の変更)
4. [ファイル構成](#ファイル構成)
5. [よく使うコマンド](#よく使うコマンド)

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
vim ~/dotfiles/nix/home-manager/programs/packages.nix

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

`home-manager/programs/packages.nix` の `packages` に追加：

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
# generalAliases など適切なカテゴリに追加
generalAliases = {
  ll = { cmd = "eza -la --group-directories-first --icons=auto"; desc = "List files with eza"; };
};
```

> **Note**: OS固有のエイリアスは `nixDarwinAliases` または `nixLinuxAliases` に追加

### oh-my-zsh プラグイン

```nix
programs.zsh.oh-my-zsh = {
  enable = true;
  plugins = [
    "git"      # git エイリアス (gst, gco, gp など)
    "z"        # ディレクトリ高速移動
    "docker"   # docker 補完
    "sudo"     # ESC 2回で sudo 追加
    "extract"  # x で解凍
  ];
};
```

### 環境変数

`home-manager/programs/packages.nix`:

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

## ファイル構成

```
~/dotfiles/
├── flake.nix                 # エントリポイント
├── darwin/
│   └── configuration.nix     # macOS システム設定 (macOS only)
├── home-manager/
│   ├── home.nix              # ユーザー設定（メイン）
│   └── programs/
│       ├── packages.nix      # パッケージ、PATH、環境変数
│       ├── git.nix           # Git 設定
│       ├── zsh.nix           # Zsh 設定 (OS別エイリアス)
│       ├── neovim.nix        # Neovim 設定
│       ├── ghostty.nix       # Ghostty 設定 (OS別パス)
│       └── karabiner.nix     # Karabiner (macOS only)
└── docs/
    ├── guide.md              # このガイド
    ├── guide-macos.md        # macOS 専用
    ├── guide-ubuntu.md       # Linux 専用
    └── cheatsheet.md         # コマンド一覧
```

### 編集頻度

| ファイル | 頻度 | 内容 |
|---------|------|------|
| `packages.nix` | 高 | パッケージ、環境変数 |
| `programs/*.nix` | 中 | Git, Zsh 設定 |
| `configuration.nix` | 低 | macOS 設定、GUI アプリ |
| `flake.nix` | 低 | 依存関係 |

### OS による条件分岐

設定ファイル内で OS を判定:

```nix
{ pkgs, lib, ... }: {
  # macOS のみ
  some.option = lib.mkIf pkgs.stdenv.isDarwin "darwin value";

  # Linux のみ
  some.option = lib.mkIf pkgs.stdenv.isLinux "linux value";
}
```

---

## よく使うコマンド

> 詳細は [cheatsheet.md](./cheatsheet.md) を参照

| Alias | macOS | Linux | 説明 |
|-------|:-----:|:-----:|------|
| `dr` | ✅ | ✅ | 設定を適用 (rebuild) |
| `db` | ✅ | - | ビルドのみ |
| `dp` | ✅ | ✅ | ロールバック / 履歴 |
| `du` | ✅ | ✅ | 依存を更新 |
| `ds` | ✅ | ✅ | パッケージを検索 |
| `dg` | ✅ | ✅ | 古い世代を削除 |

### 定期的な更新

```bash
du       # 依存を更新
dr       # リビルド
git add flake.lock
git commit -m "chore: update flake.lock"
```

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
- [nix-darwin options](https://daiderd.com/nix-darwin/manual/index.html) (macOS)

### 設定の確認

```bash
# home-manager の世代を確認
home-manager generations

# nix store の容量確認
nix store --store-size
du -sh /nix/store
```
