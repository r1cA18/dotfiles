---
title: "r1hnによるaccount groupとagentの起動"
created: 2026-11-11
type: guide
tags: [r1hn, claude-code, codex, dsh, accounts]
---

# r1hnによるaccount groupとagentの起動

Claude Code・Codex・dshのaccountは自作の基盤CLI `r1hn`で扱う。
利用者が選ぶのはgroupとmodelで、accountは`r1hn`がgroupの中から選ぶ。
`r1hn`はtokenに触れない。accountは公式clientでlogin済みの設定directoryを指すだけである。

## groupの考え方

- groupは登録したaccountの集合
- 起動・session・limit時の切り替えはgroupの中で閉じる
- 別groupのaccountやgroup未割り当てのaccountでは起動しない
- groupを省くと現在のdirectoryに対応する規則(`config.toml`の`[[dir]]`)を使い、無ければpickerを出す

## 起動

```bash
cl                          # r1hn run --runtime claude
cx                          # r1hn run --runtime codex
cl --group <group>          # groupを指定
cl -- --resume              # "--"の後ろは公式clientへ渡す
r1hn run --runtime dsh      # dsh
r1hn run --group <group> --account <id> --runtime claude   # accountを明示
r1hn run --runtime claude --dry-run                        # 起動内容だけを表示
```

`cl`と`cx`はzsh-abbrの短縮形で、入力すると上の`r1hn run`へ展開される。
`clc`・`cxr`など他の短縮形は既定の設定directoryで公式clientを直接起動する。

起動したclientは親shellの環境変数を引き継がない。
`GH_TOKEN`などを渡す場合は`config.toml`の`[runtime] pass_env`へ変数名を書く。

## 使用量

```bash
r1hn usage                  # accountごとの残量とreset時刻
r1hn usage --group <group>
r1hn usage --json
r1hn account list --check   # login状態を確認
```

待機中のClaude accountの数値はsessionで観測するまで不明になる。
`r1hn usage --probe`はaccountごとに小さなturnを1回使って更新する。

画面表示は`r1hn serve`のendpointを読むclientが担う。dotfilesは表示用のappを入れない。

## accountの追加

1. 公式clientで新しい設定directoryへloginする
2. 必要ならgroupを作る: `r1hn group add <group>`
3. 登録する: `r1hn account add <id> --provider claude --config-dir <dir> --group <group>`
4. `r1hn account list --check`と`r1hn run --group <group> --dry-run`で確認する

Orcaが管理する設定directoryは`r1hn account discover`で一覧できる。

## 台帳の場所

台帳はdotfilesに置かない。account名やmail addressをこのrepositoryへ書かない。

| File                           | 内容                                                          |
| ------------------------------ | ------------------------------------------------------------- |
| `~/.config/r1hn/accounts.toml` | groupとaccount                                                |
| `~/.config/r1hn/config.toml`   | directoryとgroupの対応・clientのcommand・`pass_env`・endpoint |
| `~/.config/r1hn/models.toml`   | modelの台帳と`auto`の規則                                     |
| `~/.local/state/r1hn/`         | 使用量の観測・session・token                                  |

## Nixでの導入

- `r1hn`はprivateなflake input `r1hn`から入る。定義は`nix/home-manager/programs/r1hn.nix`
- `dotfiles.r1hn.enable`がtrueのhostだけがinputを取得する。既定はmacOSだけtrue
- 無効なhostでは`cl`と`cx`は`claude`と`codex`へ展開される
- 更新は`flake.nix`の`rev`を書き換えて`nix flake update r1hn`を実行する
- dshは`nix/pkgs/deepseek-harness/`のpackageでmacOSに入る。`config.toml`の`[runtime] dsh`は`dsh`かNixが入れた絶対pathを指す
- homelabで有効にするにはGitHubへのSSH鍵を用意し`nix/home-manager/hosts/homelab.nix`で`dotfiles.r1hn.enable = true`を設定する
