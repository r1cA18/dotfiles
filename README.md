# 🏠 dotfiles

nix-darwin + home-manager による macOS 環境設定管理

---

## 📁 ディレクトリ構造

```
dotfiles/
├── flake.nix                    # エントリポイント（全体の設計図）
├── flake.lock                   # 依存関係のロックファイル
│
├── darwin/                      # macOS/nix-darwin設定
│   └── configuration.nix        # システムレベル設定
│
├── home-manager/                # ユーザー環境設定
│   └── home.nix                 # ユーザーレベル設定
│
├── modules/                     # 再利用可能なモジュール
│   ├── darwin/                  # darwin用モジュール
│   │   └── default.nix
│   └── home-manager/            # home-manager用モジュール
│       └── default.nix
│
├── overlays/                    # パッケージのカスタマイズ
│   └── default.nix              # overlay定義
│
└── pkgs/                        # カスタムパッケージ
    └── default.nix              # 自作パッケージ定義
```

---

## 📖 各ファイルの役割

### `flake.nix`
- **役割**: プロジェクト全体のエントリポイント
- **内容**:
  - 依存関係の定義（nixpkgs, nix-darwin, home-manager）
  - システム構成のビルド設定
  - overlay, modules, packagesのエクスポート
- **編集頻度**: 低（構造変更時のみ）

### `darwin/configuration.nix`
- **役割**: macOS システムレベルの設定
- **内容**:
  - システムパッケージ（vim, git, curl など）
  - Homebrew 設定（GUI アプリ、CLI ツール、App Store アプリ）
  - macOS システム環境設定（Dock, Finder, キーボード等）
  - Touch ID, ネットワーク, ユーザー設定
- **編集頻度**: 中〜高
- **例**:
  ```nix
  # GUIアプリの追加
  homebrew.casks = [
    "google-chrome"
    "visual-studio-code"
  ];
  
  # Dock設定
  system.defaults.dock.autohide = true;
  ```

### `home-manager/home.nix`
- **役割**: ユーザーレベルの設定（dotfiles）
- **内容**:
  - ユーザーパッケージ（nodejs, python など）
  - Git 設定
  - Zsh 設定（エイリアス、プラグイン）
  - 環境変数
  - シンボリックリンク管理
- **編集頻度**: 高（日常的に編集）
- **例**:
  ```nix
  # パッケージ追加
  home.packages = with pkgs; [
    nodejs_latest
    ripgrep
  ];
  
  # エイリアス追加
  programs.zsh.shellAliases = {
    ll = "ls -la";
  };
  ```

### `overlays/default.nix`
- **役割**: パッケージのカスタマイズ・拡張
- **内容**:
  - `additions`: カスタムパッケージの追加
  - `modifications`: 既存パッケージの変更
  - `stable-packages`: 安定版パッケージへのアクセス
- **編集頻度**: 低〜中
- **使用例**:
  ```nix
  # バージョン固定
  modifications = final: prev: {
    nodejs = prev.nodejs_20;
  };
  
  # 安定版を使う
  home.packages = [ pkgs.stable.python3 ];
  ```

### `modules/`
- **役割**: 再利用可能な設定モジュール
- **内容**: 他のプロジェクトでも使えるモジュール定義
- **編集頻度**: 低（モジュール化する時のみ）

### `pkgs/default.nix`
- **役割**: 自作パッケージの定義
- **内容**: nixpkgs にないカスタムパッケージ
- **編集頻度**: 低（自作パッケージを作る時のみ）

---

## 🚀 セットアップ

### 初回セットアップ

1. **Nix をインストール**（済んでいる場合はスキップ）
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```

2. **リポジトリをクローン**
   ```bash
   git clone <your-repo-url> ~/dotfiles
   cd ~/dotfiles
   ```

3. **設定を適用**
   ```bash
   sudo darwin-rebuild switch --flake .#RMB
   ```

4. **シェルを再起動**
   ```bash
   exec zsh
   ```

---

## 🔄 日常的な運用

### 1. 設定ファイルを編集
```bash
cd ~/dotfiles

# ユーザー設定を編集
vim home-manager/home.nix

# システム設定を編集
vim darwin/configuration.nix
```

### 2. 変更を適用
```bash
# gitに追加（flakeはgit管理が必須）
git add .

# ビルド＆適用（エイリアス使用）
rebuild

# または直接
sudo darwin-rebuild switch --flake .#RMB
```

### 3. 動作確認
```bash
# シェル再起動
exec zsh

# インストールされたパッケージ確認
which <package-name>
```

---

## 📦 パッケージの追加

### CLIツールの追加 → `home-manager/home.nix`

```nix
home.packages = with pkgs; [
  # Development
  nodejs_latest
  python3
  go
  
  # CLI Tools
  ripgrep      # 高速grep
  fd           # 高速find
  fzf          # ファジー検索
  eza          # ls代替
  bat          # cat代替
  jq           # JSON処理
  gh           # GitHub CLI
  htop         # プロセスモニター
];
```

### GUIアプリの追加 → `darwin/configuration.nix`

```nix
homebrew = {
  enable = true;
  
  # CLIツール（Nixにない場合のみ）
  brews = [
    "mas"  # Mac App Store CLI
  ];
  
  # GUIアプリケーション
  casks = [
    "google-chrome"
    "visual-studio-code"
    "discord"
    "slack"
    "docker"
    "raycast"
    "rectangle"
    "notion"
    "spotify"
  ];
  
  # Mac App Storeアプリ
  masApps = {
    "LINE" = 539883307;
    "Keynote" = 409183694;
    "Numbers" = 409203825;
    "Pages" = 409201541;
  };
};
```

**App Store ID の調べ方:**
```bash
# masをインストール
brew install mas

# アプリを検索
mas search "LINE"
# 出力: 539883307  LINE (...)

# インストール済みアプリ一覧
mas list
```

---

## ⚙️ macOS設定のカスタマイズ

`darwin/configuration.nix` で設定可能：

```nix
system.defaults = {
  # Dock設定
  dock = {
    autohide = true;
    show-recents = false;
    tilesize = 48;
    orientation = "bottom";
  };

  # Finder設定
  finder = {
    AppleShowAllExtensions = true;
    FXEnableExtensionChangeWarning = false;
    _FXShowPosixPathInTitle = true;
    ShowPathbar = true;
    ShowStatusBar = true;
  };

  # グローバル設定
  NSGlobalDomain = {
    AppleShowAllExtensions = true;
    KeyRepeat = 2;
    InitialKeyRepeat = 15;
    "com.apple.swipescrolldirection" = false;  # ナチュラルスクロール無効
  };

  # トラックパッド
  trackpad = {
    Clicking = true;
    TrackpadThreeFingerDrag = true;
  };
};
```

---

## 🛠️ よく使うコマンド

### 設定管理
```bash
# 設定を適用
rebuild

# テストビルド（適用しない）
darwin-rebuild build --flake ~/dotfiles

# 世代を確認
darwin-rebuild --list-generations

# 前の世代にロールバック
sudo darwin-rebuild --rollback

# 特定の世代に戻る
sudo darwin-rebuild switch --rollback <generation-number>
```

### パッケージ検索
```bash
# Nixパッケージを検索
nix search nixpkgs nodejs
nix search nixpkgs python

# Homebrewパッケージを検索
brew search <package-name>
```

### メンテナンス
```bash
# 依存関係を更新
nix flake update

# ゴミ掃除（古い世代を削除）
nix-collect-garbage -d

# ストア最適化
nix-store --optimise

# Homebrewの更新
brew update && brew upgrade
```

---

## 📁 設定ファイルの分割

設定が大きくなったら分割できます：

### 例: Zsh設定を分離

1. **ファイル作成**
   ```bash
   mkdir -p ~/dotfiles/home-manager/programs
   vim ~/dotfiles/home-manager/programs/zsh.nix
   ```

2. **zsh.nix に移動**
   ```nix
   { config, pkgs, ... }:
   {
     programs.zsh = {
       enable = true;
       shellAliases = {
         # エイリアス定義
       };
     };
   }
   ```

3. **home.nix で読み込み**
   ```nix
   imports = [
     ./programs/zsh.nix
   ];
   ```

### 推奨分割例
```
home-manager/
├── home.nix              # メインファイル
└── programs/
    ├── git.nix           # Git設定
    ├── zsh.nix           # Zsh設定
    ├── neovim.nix        # Neovim設定
    └── ssh.nix           # SSH設定
```

---

## 🎯 NixとHomebrewの使い分け

| 種類 | Nix | Homebrew |
|-----|-----|----------|
| **CLIツール** | ✅ 推奨（再現性◎） | △ Nixにない時のみ |
| **開発ツール** | ✅ 推奨 | △ |
| **GUIアプリ** | △ 一部のみ | ✅ 推奨（Cask豊富） |
| **App Storeアプリ** | ❌ 不可 | ✅ `mas`経由で可能 |

**方針:**
- CLI・開発ツール → Nixで管理（`home.packages`）
- GUIアプリ → Homebrewで管理（`homebrew.casks`）
- App Store → Homebrewで管理（`homebrew.masApps`）

---

## 🔐 シークレット管理

Git にコミットしたくない情報の扱い方：

### 方法1: .gitignore を使う
```bash
# secrets/ を作成
mkdir ~/dotfiles/secrets
echo "secrets/" >> ~/dotfiles/.gitignore

# 使用例
programs.git.extraConfig = {
  user.signingkey = builtins.readFile ./secrets/gpg-key;
};
```

### 方法2: sops-nix を使う
暗号化してGitにコミットする方法もあります。

---

## 🐛 トラブルシューティング

### エラー: `path does not exist`
**原因**: 新しいファイルがgitに追加されていない

**解決方法**:
```bash
git add .
sudo darwin-rebuild switch --flake .
```

### エラー: `would be clobbered`
**原因**: 既存のdotfilesと衝突

**解決方法**: flake.nixに以下を追加済み
```nix
home-manager.backupFileExtension = "backup";
```

### ビルドが遅い
**解決方法**:
```bash
# キャッシュを使う（通常は自動）
nix.settings.substituters = [
  "https://cache.nixos.org"
];
```

### 設定が反映されない
```bash
# シェルを再起動
exec zsh

# または完全にログアウト/ログイン
```

---

## 🔄 更新フロー

### 定期的な更新
```bash
cd ~/dotfiles

# 1. 依存関係を更新
nix flake update

# 2. 変更をコミット
git add flake.lock
git commit -m "chore: update flake.lock"

# 3. ビルド＆適用
rebuild

# 4. 問題なければpush
git push
```

---

## 📚 参考リンク

- [Nix公式](https://nixos.org/)
- [nix-darwin](https://github.com/LnL7/nix-darwin)
- [home-manager](https://github.com/nix-community/home-manager)
- [Nixパッケージ検索](https://search.nixos.org/)

---

## 📝 メモ

### システム情報
- **ホスト名**: RMB
- **ユーザー名**: r1ca18
- **アーキテクチャ**: aarch64-darwin (Apple Silicon)

### 初回セットアップ日
[TODO: 日付を記入]

### バックアップ
既存の設定ファイルは `.backup` 拡張子でバックアップされます。
