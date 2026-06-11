# Ubuntu Desktop セットアップガイド

home-manager (standalone) を使った Ubuntu Desktop 環境のセットアップと運用方法。
`linux-desktop.nix` により `targets.genericLinux` (XDG/デスクトップ統合) と
`fonts.fontconfig` (フォント解決) が自動で有効になる。

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
cd ~/dotfiles
nh home switch . -c r1ca18@linux
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

`nerd-fonts.jetbrains-mono` は `linuxPackages` 経由で `dr` 時に入り、
`fonts.fontconfig.enable` (linux-desktop.nix) によりキャッシュも自動で更新される。
ターミナルアプリのフォント設定で `JetBrainsMono Nerd Font` を選択するだけでよい。

### 6. 1Password desktop (SSH agent + git 署名)

SSH agent と git commit 署名は 1Password desktop を前提にしている。

```bash
# https://support.1password.com/install-linux/ に従いインストール
# その後 1Password の設定で SSH Agent を有効化
```

- 未導入でも `dr` は通る。git 署名は op-ssh-sign (`/opt/1Password/op-ssh-sign`)
  が見つからない間は自動で無効化され、commit は無署名で通る
- 導入後にもう一度 `dr` すれば署名が自動で有効になる
- `SSH_AUTH_SOCK` は `~/.1password/agent.sock` を指す。1Password 起動前は
  agent 経由の鍵は使えないが、ssh 自体は通常の鍵認証にフォールバックする

### 7. Claude Code セットアップ

`programs.claude-code` は `package = null` で settings.json と plugins だけを管理し、バイナリ自体は公式インストーラ (auto-update) に任せている。Linux でも公式手順で `~/.local/bin/claude` に入れる。

```bash
curl -fsSL https://claude.ai/install.sh | bash
which claude    # ~/.local/bin/claude を指していることを確認
claude --version
```

> **Warning**: 過去に `bun install -g @anthropic-ai/claude-code` を走らせていたマシンでは `~/.bun/bin/claude` の残骸が PATH 優先で拾われ、`claude native binary not installed` で起動失敗する。残骸を消してから公式インストーラを走らせる:
>
> ```bash
> bun remove -g @anthropic-ai/claude-code 2>/dev/null || rm -f ~/.bun/bin/claude
> rm -rf ~/.bun/install/global/node_modules/@anthropic-ai/claude-code
> ```

---

## 日常の運用

### 設定変更のフロー

```
1. 設定ファイルを編集
2. dr でリビルド
3. 問題なければ git commit & push
```

### よく使うエイリアス

| Alias | 説明                                                     |
| ----- | -------------------------------------------------------- |
| `dr`  | `nh home switch ~/dotfiles -c <user>@linux` - 設定を適用 |
| `db`  | `nh home build ~/dotfiles -c <user>@linux` - ビルドのみ  |
| `dp`  | `home-manager generations` - 世代一覧                    |
| `du`  | 依存を更新 (flake.lock)                                  |
| `ds`  | パッケージ検索                                           |
| `dg`  | 古い世代と store path を削除                             |

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

| 設定    | パス                           |
| ------- | ------------------------------ |
| Neovim  | `~/.config/nvim/`              |
| Ghostty | `~/.config/ghostty/config`     |
| Zsh     | `~/.zshrc` (home-manager 管理) |

---

## macOS との違い

### 管理構造

| 項目         | macOS        | Linux                 |
| ------------ | ------------ | --------------------- |
| システム設定 | nix-darwin   | 対象外                |
| ユーザー設定 | home-manager | home-manager          |
| GUI アプリ   | Homebrew     | システムのpkg manager |

### コマンドの違い

| 操作         | macOS                                       | Linux                                       |
| ------------ | ------------------------------------------- | ------------------------------------------- |
| リビルド     | `nh darwin switch ~/dotfiles -H <hostname>` | `nh home switch ~/dotfiles -c <user>@linux` |
| ロールバック | `darwin-rebuild --rollback`                 | 世代を指定して switch                       |

### 共通で動作するもの

- CLI ツール (Nix packages)
- Zsh + oh-my-zsh + Powerlevel10k + abbr
- Git 設定 (1Password 署名含む)
- SSH 設定 (1Password agent / homelab ホスト定義)
- Neovim 設定
- Ghostty 設定
- Claude Code / Codex 設定一式 (settings, rules, hooks, commands, agents, skills)
- Syncthing / atuin / zoxide / direnv / comma

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

# または nh で実行
nh home switch ~/dotfiles -c r1ca18@linux
```

### リビルドが失敗する

```bash
# 詳細エラーを確認
nh home switch ~/dotfiles -c r1ca18@linux --show-trace

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
cd ~/dotfiles
nix run home-manager -- switch --flake .#r1ca18@linux

# 4. デフォルトシェル変更
echo "$HOME/.nix-profile/bin/zsh" | sudo tee -a /etc/shells
chsh -s "$HOME/.nix-profile/bin/zsh"

# 5. Claude Code 公式インストーラ (auto-update に任せる方針)
curl -fsSL https://claude.ai/install.sh | bash

# 6. 1Password desktop を導入して再度 dr (SSH agent + git 署名が有効化される)
```

---

## Tips

### WSL2 での利用

このdotfilesはWSL2でも動作します：

```bash
# 同じ手順でセットアップ
nix run home-manager -- switch --flake .#r1ca18@linux
```
