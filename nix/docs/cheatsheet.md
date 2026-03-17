# Cheatsheet

よく使うエイリアスとコマンドのクイックリファレンス。

## Nix エイリアス

### 共通 (macOS & Linux)

| Alias | Command | Description |
|-------|---------|-------------|
| `nx` | `cd ~/dotfiles` | flake ルートへ移動 |
| `du` | `nix flake update ...` | 依存パッケージを最新に |
| `ds` | `nix search nixpkgs` | パッケージを検索 |
| `dg` | `nix-collect-garbage -d` | 古いバージョンを削除 |
| `nd` | `nix develop` | 開発環境に入る |

### macOS 専用 (nix-darwin)

| Alias | Command | Description |
|-------|---------|-------------|
| `dr` | `darwin-rebuild switch ...` | 設定を適用 (rebuild) |
| `db` | `darwin-rebuild build ...` | ビルドのみ (適用しない) |
| `dp` | `darwin-rebuild switch --rollback` | 前のバージョンに戻す |

### Linux 専用 (home-manager)

| Alias | Command | Description |
|-------|---------|-------------|
| `dr` | `home-manager switch ...` | 設定を適用 |
| `dp` | `home-manager generations` | 世代一覧を表示 |

---

## 使用例

### macOS

```bash
# 設定を変更したらリビルド
dr

# パッケージを探す
ds ripgrep

# 依存を最新にする（週1くらい）
du && dr

# ディスク容量を確保（月1くらい）
dg

# 設定をミスったら戻す
dp
```

### Linux

```bash
# 設定を変更したらリビルド
dr

# パッケージを探す
ds nodejs

# 依存を最新にする
du && dr

# 世代を確認
dp

# ディスク容量を確保
dg
```

---

## ディレクトリ エイリアス

### macOS

| Alias | Path |
|-------|------|
| `dev` | `~/Develop/` |
| `drive` | `~/Library/CloudStorage/GoogleDrive-.../My Drive/` |
| `kosen` | `.../Kosen/4y/fall_semester/` |
| `downloads` | `~/Downloads/` |

### Linux

| Alias | Path |
|-------|------|
| `dev` | `~/develop/` |
| `downloads` | `~/Downloads/` |

---

## その他 (共通)

| Alias | Command |
|-------|---------|
| `nv` | `nvim` |
| `ll` | `ls -la` |
| `..` | `cd ..` |
| `...` | `cd ../..` |

---

## Git エイリアス (oh-my-zsh)

| Alias | Command |
|-------|---------|
| `gst` | `git status` |
| `gco` | `git checkout` |
| `gcb` | `git checkout -b` |
| `gp` | `git push` |
| `gl` | `git pull` |
| `ga` | `git add` |
| `gaa` | `git add --all` |
| `gcmsg` | `git commit -m` |
| `gd` | `git diff` |
| `glog` | `git log --oneline --decorate --graph` |

---

## 基本フロー

```
1. 設定ファイルを編集
2. dr でリビルド
3. git commit & push
```

詳細は:
- [guide.md](./guide.md) - 共通ガイド
- [guide-macos.md](./guide-macos.md) - macOS 専用
- [guide-ubuntu.md](./guide-ubuntu.md) - Linux 専用
