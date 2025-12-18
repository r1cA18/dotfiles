# Nix dotfiles 運用ガイド

このガイドでは、Nix (nix-darwin + home-manager) を使った dotfiles の運用方法を説明します。

## 目次

1. [基本的な運用フロー](#基本的な運用フロー)
2. [パッケージの追加・削除](#パッケージの追加削除)
3. [設定の変更](#設定の変更)
4. [よく使うコマンド](#よく使うコマンド)
5. [トラブルシューティング](#トラブルシューティング)
6. [ファイル構成](#ファイル構成)

---

## 基本的な運用フロー

```
1. 設定ファイルを編集
2. rebuild で動作確認
3. 問題なければ git commit & push
```

### 具体例

```bash
# 1. 設定を編集（例：パッケージ追加）
vim ~/dotfiles/nix/home-manager/home.nix

# 2. リビルドして適用
rebuild

# 3. 動作確認して問題なければコミット
cd ~/dotfiles
git add .
git commit -m "feat: add ripgrep"
git push
```

---

## パッケージの追加・削除

### パッケージを追加する

`home-manager/home.nix` の `packages` に追加：

```nix
home = {
  packages = with pkgs; [
    # 既存のパッケージ
    nodejs_latest
    neovim

    # ここに新しいパッケージを追加
    htop        # ← 追加
    tree        # ← 追加
  ];
};
```

追加したら `rebuild` を実行。

### パッケージを削除する

リストから削除して `rebuild` するだけ。
Nix は使われなくなったパッケージを自動で管理します。

### パッケージを探す

```bash
# パッケージ名で検索
nix search nixpkgs パッケージ名

# 例：ripgrep を探す
nix search nixpkgs ripgrep
```

または [search.nixos.org](https://search.nixos.org/packages) で検索。

### よく使うパッケージ例

| パッケージ名 | 説明 |
|------------|------|
| `ripgrep` | 高速 grep |
| `fd` | 高速 find |
| `fzf` | ファジーファインダー |
| `bat` | cat の代替（シンタックスハイライト付き） |
| `eza` | ls の代替（モダン） |
| `jq` | JSON 処理 |
| `gh` | GitHub CLI |
| `htop` | プロセスモニター |
| `tree` | ディレクトリツリー表示 |
| `wget` | ファイルダウンロード |
| `tmux` | ターミナルマルチプレクサ |

---

## 設定の変更

### Git の設定

`home-manager/home.nix` 内：

```nix
programs.git = {
  enable = true;
  ignores = [
    ".DS_Store"
    "*.swp"
  ];
  settings = {
    user.name = "your-name";
    user.email = "your-email@example.com";
    init.defaultBranch = "main";
    push.autoSetupRemote = true;
    pull.rebase = true;
    # ここに追加の設定を書ける
    core.editor = "nvim";
  };
};
```

### Zsh エイリアスの追加

```nix
programs.zsh = {
  shellAliases = {
    ll = "ls -la";
    ".." = "cd ..";
    # 新しいエイリアスを追加
    g = "git";
    gs = "git status";
    gc = "git commit";
  };
};
```

### 環境変数の追加

```nix
home = {
  sessionVariables = {
    EDITOR = "nvim";
    # 新しい環境変数を追加
    LANG = "ja_JP.UTF-8";
    MY_VAR = "value";
  };
};
```

### PATH の追加

```nix
home = {
  sessionPath = [
    "$HOME/.local/bin"
    # 新しいパスを追加
    "$HOME/bin"
    "/opt/homebrew/bin"
  ];
};
```

---

## よく使うコマンド

| コマンド | 説明 |
|---------|------|
| `rebuild` | 設定を適用（`sudo darwin-rebuild switch --flake ~/dotfiles/nix`） |
| `nix search nixpkgs <name>` | パッケージを検索 |
| `nix-collect-garbage` | 使われていないパッケージを削除 |
| `nix-collect-garbage -d` | 古い世代も含めて削除（容量節約） |
| `nix flake update` | 全パッケージを最新版に更新 |

### リビルドのオプション

```bash
# 通常のリビルド
rebuild

# 詳細なログを見たい場合
sudo darwin-rebuild switch --flake ~/dotfiles/nix --show-trace

# ドライラン（実際には適用しない）
sudo darwin-rebuild build --flake ~/dotfiles/nix
```

---

## トラブルシューティング

### "Git tree is dirty" 警告

```
warning: Git tree '/Users/xxx/dotfiles' is dirty
```

**意味**: コミットしていない変更がある。
**対処**: 無視して OK。気になるなら先にコミットする。

### オプション名変更の警告

```
trace: warning: The option 'programs.git.userName' has been renamed to...
```

**意味**: home-manager がオプション名を新しくした。
**対処**: 指示通りに名前を変更する。

### パッケージが見つからない

```
error: attribute 'xxx' not found
```

**対処**:
1. パッケージ名が正しいか確認: `nix search nixpkgs xxx`
2. 正しいパッケージ名を使う

### リビルドが失敗する

```bash
# エラーの詳細を見る
sudo darwin-rebuild switch --flake ~/dotfiles/nix --show-trace

# 直前の変更を戻す
git checkout home-manager/home.nix
```

### ディスク容量が足りない

```bash
# 古いパッケージを削除
nix-collect-garbage -d

# さらに削除
nix store gc
```

---

## ファイル構成

```
~/dotfiles/nix/
├── flake.nix              # Nix Flake のエントリーポイント
├── flake.lock             # 依存関係のバージョン固定
├── darwin/
│   └── configuration.nix  # macOS システム設定
├── home-manager/
│   └── home.nix           # ユーザー設定（メインで編集するファイル）
└── docs/
    └── guide.md           # このガイド
```

### 各ファイルの役割

| ファイル | 編集頻度 | 内容 |
|---------|---------|------|
| `home-manager/home.nix` | **高** | パッケージ、エイリアス、設定など |
| `darwin/configuration.nix` | 低 | macOS システム設定 |
| `flake.nix` | 低 | 依存関係の定義 |
| `flake.lock` | 編集しない | 自動生成 |

**基本的には `home-manager/home.nix` だけ編集すれば OK。**

---

## 新しい Mac への移行

1. Nix をインストール
2. dotfiles を clone
3. `rebuild` を実行

これだけで同じ環境が再現されます。

```bash
# 1. Nix インストール（Determinate Systems 版推奨）
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# 2. dotfiles を clone
git clone https://github.com/your-username/dotfiles.git ~/dotfiles

# 3. 初回ビルド
cd ~/dotfiles/nix
nix run nix-darwin -- switch --flake .
```

---

## Tips

### programs で設定できるツール

home-manager は多くのツールを `programs.xxx` で設定できます：

```nix
programs.fzf.enable = true;      # fzf + シェル統合
programs.eza.enable = true;      # eza + エイリアス
programs.bat.enable = true;      # bat
programs.gh.enable = true;       # GitHub CLI
programs.tmux.enable = true;     # tmux
```

`packages` に追加するより設定が楽な場合があります。

### 設定オプションを調べる

- [home-manager オプション検索](https://home-manager-options.extranix.com/)
- [nix-darwin オプション](https://daiderd.com/nix-darwin/manual/index.html)
