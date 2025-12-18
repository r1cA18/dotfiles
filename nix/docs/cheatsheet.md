# Cheatsheet

よく使うエイリアスとコマンドのクイックリファレンス。

## Nix / Darwin エイリアス

| Alias | Command | Description |
|-------|---------|-------------|
| `nx` | `cd ~/dotfiles/nix` | flake ディレクトリへ移動 |
| `dr` | `darwin-rebuild switch ...` | 設定を適用 (rebuild) |
| `db` | `darwin-rebuild build ...` | ビルドのみ (適用しない) |
| `dp` | `darwin-rebuild switch --rollback` | 前のバージョンに戻す |
| `du` | `nix flake update ...` | 依存パッケージを最新に |
| `ds` | `nix search nixpkgs` | パッケージを検索 |
| `dg` | `nix-collect-garbage -d` | 古いバージョンを削除 |
| `nd` | `nix develop` | 開発環境に入る |

### 使用例

```bash
# 設定を変更したらリビルド
dr

# パッケージを探す
ds ripgrep
ds nodejs

# 依存を最新にする（週1くらい）
du && dr

# ディスク容量を確保（月1くらい）
dg

# 設定をミスったら戻す
dp
```

## ディレクトリ エイリアス

| Alias | Path |
|-------|------|
| `dev` | `~/Develop/` |
| `drive` | `~/Google Drive/My Drive/MainFolder/` |
| `kosen` | `.../Kosen/4y/fall_semester/` |
| `downloads` | `~/Downloads/` |

## その他

| Alias | Command |
|-------|---------|
| `nv` | `nvim` |
| `ll` | `ls -la` |
| `..` | `cd ..` |
| `...` | `cd ../..` |

## 基本フロー

```
1. 設定ファイルを編集
2. dr でリビルド
3. git commit & push
```

詳細は [guide.md](./guide.md) を参照。
