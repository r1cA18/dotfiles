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

起動したclientが引き継ぐ環境変数は`PATH`や`HOME`など決まった一覧だけである。
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
- `dotfiles.r1hn.enable`がtrueのhostだけがinputを取得する。既定はmacOSだけtrueでhomelabは`r1hnd-service.nix`がtrueにする
- inputはHTTPSで取得する。gitのcredential helper(`gh auth login`済み)があればSSH agentの承認なしで取得できる
- 無効なhostでは`cl`と`cx`は`claude`と`codex`へ展開される
- 更新は`flake.nix`の`rev`を書き換えて`nix flake update r1hn`を実行する
- dshは`nix/pkgs/deepseek-harness/`のpackageでmacOSに入る。`config.toml`の`[runtime] dsh`は`dsh`かNixが入れた絶対pathを指す
- homelabとMacでは`nix/home-manager/programs/r1hnd-service.nix`がr1hndと`t3-r1hn`を置く。homelabはsystemd user service、Macはlaunchd agent(`org.dotfiles.r1hnd`と`org.dotfiles.t3-r1hn`)である
- r1hndは`~/.config/r1hn/accounts.toml`が、`t3-r1hn`はそれに加えて`t3-r1hn-build`のbuildがあるときだけ起動する
- ファイルを用意した後に一度起動する。homelabは`systemctl --user start r1hnd t3-r1hn`、Macは`launchctl kickstart gui/$(id -u)/org.dotfiles.r1hnd`と`.../org.dotfiles.t3-r1hn`
- logはhomelabが`journalctl --user -u r1hnd`と`-u t3-r1hn`、Macが`~/Library/Logs/r1hn/`
- Macのlaunchd agentは失敗終了だけを再起動する。入力が無いときのwrapperは0で終わるので再起動を繰り返さない。consoleの再起動(exit 75)は`R1HN_SUPERVISED=1`とKeepAliveで動く
- T3 Codeに出すgroupは起動時に台帳から読む。accountを持つgroupをすべて出す(`r1hn group list --json`)
- `~/.config/t3-r1hn/env`の`T3CODE_R1HN_GROUPS`があればそれを優先する。fileは`KEY=value`の行をsystemdのEnvironmentFileと同じく文字通りに読む。`T3CODE_R1HN_COMMAND`・`T3CODE_LAN`・`T3CODE_PORT`も置ける。group名はこのrepositoryに書かない
- `t3 up`と`t3 service install`は使わない。upstreamのserviceが別に入る

## T3 Code

T3 Codeはr1hn gatewayだけを持つfork(`r1cA18/t3code`の`feature/r1hn-gateway`)のserverを各hostで動かす。
各hostのproviderへのloginはそのhostの`r1hn`の台帳で行い、credentialをhost間で複製しない。

### serverのbuild

```bash
git clone -b feature/r1hn-gateway https://github.com/r1cA18/t3code.git ~/.local/share/t3-r1hn/src
t3-r1hn-build ~/.local/share/t3-r1hn/src
```

checkoutは`~/Develop`の外に置く。`~/Develop`はSyncthingで同期される。
buildの後は表示された再起動commandを実行する。

### Macのdesktop app

Macではupstreamのcask `t3-code`をclientとして使う。
desktop appは通常は内蔵serverを起動し、そのserverは`claude`と`codex`のloginを直接使う。
`r1hnd-service.nix`のactivationが`~/.t3/userdata/desktop-settings.json`の`localEnvironmentEnabled`を毎回falseにする。
falseのdesktopは内蔵serverを起動せず、pairingで追加したenvironmentだけを使う。
`t3-r1hn`が`~/.t3`を使用中のときはlocal environmentを有効にしてもdesktopは起動を拒む。

desktopへのenvironmentの追加:

1. Macの`t3-r1hn`のpairing URLを出す: `t3 pair`
2. desktopのSettings → Connections → Add environmentで「Remote link」を選び、URLを貼る
3. homelabは同じ手順でhomelabの`t3 pair`のURLを使う。tailnetかT3 Connectで到達する

`t3 connect`をsubcommandなしで実行しない。desktop appの更新はapp自身とcaskが行う。
