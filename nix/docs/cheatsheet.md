# Cheatsheet

よく使うエイリアスとコマンドのクイックリファレンス。

## dot コマンド

dotfilesの操作は実行file`dot`のsubcommandに揃えている。対話shell以外(agentやscript)からも呼べる。一覧は`dot help`で表示する。

| Command             | 実行内容                                                                       | Description                          |
| ------------------- | ------------------------------------------------------------------------------ | ------------------------------------ |
| `dot apply`         | macOS: `nh darwin switch ~/dotfiles -H <hostname>` / Linux: `nh home switch`   | 設定を適用 (rebuild)                 |
| `dot build`         | macOS: `nh darwin build` / Linux: `nh home build`                              | ビルドのみ (適用しない)              |
| `dot rollback`      | `sudo darwin-rebuild switch --rollback` (macOSのみ)                            | 前の世代に戻す                       |
| `dot generations`   | macOS: `darwin-rebuild --list-generations` / Linux: `home-manager generations` | 世代一覧を表示                       |
| `dot update`        | 下記の全段階を順に実行                                                         | flake・native tool・Homebrewを更新   |
| `dot search <名前>` | `nix search nixpkgs`                                                           | パッケージを検索                     |
| `dot clean`         | `nh clean all --keep-since 14d --keep 5`                                       | 古い generation と store path を削除 |
| `dot fmt`           | `nix run ~/dotfiles#fmt`                                                       | repositoryを整形                     |
| `dot server <動作>` | `nix run ~/dotfiles#server-<動作>` (Linuxのみ)                                 | homelabのserver workflowを実行       |

### dot update の段階

`dot update`は次の段階を順に実行する。失敗した段階があっても残りを続行し、最後に段階ごとの成否を表示する。1つでも失敗すると終了codeは非0になる。`dot update codex brew`のように段階名を渡すとその段階だけを実行する。

| 段階          | 内容                                                      |
| ------------- | --------------------------------------------------------- |
| `flake`       | `r1hn`以外のflake inputを更新 (`r1hn`はrev固定)           |
| `github-apps` | `nix/pkgs/github-apps.json`のGitHub release appを最新版へ |
| `claude-code` | Claude Code native版を`managed-channel`に従い更新         |
| `codex`       | Codex CLI native版を更新                                  |
| `antigravity` | Antigravity CLIを更新                                     |
| `brew`        | `brew update`と`brew upgrade` (macOSのみ)                 |

Homebrewの更新は`dot update`だけが行う。`dot apply`(`dr`)はHomebrewの更新確認をしない。

## Nix エイリアス

2文字のabbrは`dot`への短縮形。

| Alias | Command           | Description                          |
| ----- | ----------------- | ------------------------------------ |
| `dr`  | `dot apply`       | 設定を適用 (rebuild)                 |
| `db`  | `dot build`       | ビルドのみ (適用しない)              |
| `dp`  | `dot rollback`    | macOS: 前の世代に戻す                |
| `dp`  | `dot generations` | Linux: 世代一覧を表示                |
| `ds`  | `dot search`      | パッケージを検索                     |
| `dg`  | `dot clean`       | 古い generation と store path を削除 |
| `nx`  | `cd ~/dotfiles`   | flake ルートへ移動                   |
| `nd`  | `nix develop`     | 開発環境に入る                       |

## Agent起動とaccount

accountは`r1hn`がgroupの中から選ぶ。詳細は[r1hnガイド](../../docs/guides/r1hn.md)を参照。

| Command                          | Description                         |
| -------------------------------- | ----------------------------------- |
| `cl`                             | `r1hn run --runtime claude`へ展開   |
| `cx`                             | `r1hn run --runtime codex`へ展開    |
| `cl --group <group> -- --resume` | groupを指定し公式clientへ引数を渡す |
| `r1hn run --runtime dsh`         | dshを起動                           |
| `r1hn usage`                     | accountごとの残量とreset時刻        |
| `r1hn group list`                | groupとprovider別のaccount数        |
| `r1hn account list --check`      | accountの一覧とlogin状態            |

---

## 使用例

### macOS

```bash
# 設定を変更したらリビルド
dr

# パッケージを探す
ds ripgrep

# 依存を最新にする（週1くらい）
dot update && dr

# ディスク容量を確保（月1くらい）
dg

# 設定をミスったら戻す
dp
```

### Linux

```bash
# Home Managerだけを変更したらリビルド
dr

# Ubuntu system設定も含めて適用
dot server apply

# パッケージを探す
ds nodejs

# 依存を最新にする
dot update && dr

# 世代を確認
dp

# ディスク容量を確保
dg
```

---

## ディレクトリ エイリアス

### macOS

| Alias       | Path                                               |
| ----------- | -------------------------------------------------- |
| `dev`       | `~/Develop/`                                       |
| `drive`     | `~/Library/CloudStorage/GoogleDrive-.../My Drive/` |
| `kosen`     | `~/Develop/.../kosen/5y/spring_semester/`          |
| `downloads` | `~/Downloads/`                                     |

### Linux

| Alias       | Path           |
| ----------- | -------------- |
| `dev`       | `~/Develop/`   |
| `downloads` | `~/Downloads/` |

---

## その他 (共通)

| Alias | Command                                          |
| ----- | ------------------------------------------------ |
| `nv`  | `nvim`                                           |
| `ll`  | `eza -la --group-directories-first --icons=auto` |
| `..`  | `cd ..`                                          |
| `...` | `cd ../..`                                       |

---

## Git エイリアス (oh-my-zsh)

| Alias   | Command                                |
| ------- | -------------------------------------- |
| `gst`   | `git status`                           |
| `gco`   | `git checkout`                         |
| `gcb`   | `git checkout -b`                      |
| `gp`    | `git push`                             |
| `gl`    | `git pull`                             |
| `ga`    | `git add`                              |
| `gaa`   | `git add --all`                        |
| `gcmsg` | `git commit -m`                        |
| `gd`    | `git diff`                             |
| `glog`  | `git log --oneline --decorate --graph` |

---

## 基本フロー

```
1. 設定ファイルを編集
2. macOSまたはLinux user設定は`dr`でリビルド
3. Linux system設定を含む場合は`dot server apply`でリビルド
4. git commit & push
```

詳細は:

- [guide.md](./guide.md) - 共通ガイド
- [guide-macos.md](./guide-macos.md) - macOS 専用
- [guide-ubuntu.md](./guide-ubuntu.md) - Linux 専用
