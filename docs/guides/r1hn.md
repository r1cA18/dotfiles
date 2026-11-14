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

## config.tomlの管理するkey

`~/.config/r1hn/config.toml`は所有者のfileのままにする。r1hndのconsoleも書く。
`r1hnd-service.nix`のactivationは次のkeyだけをmergeし、他のkeyとtableは残す。
Nixで管理しなくなったkeyは次のactivationで消える。
既存の内容は変わらないがmergeで書き直すとcommentは消える。

| key                                          | 値                                                              |
| -------------------------------------------- | --------------------------------------------------------------- |
| `[worker] role`                              | `dotfiles.r1hn.serve.role`。homelabだけ`primary`でMacは`coding` |
| `[jobs] enabled`                             | roleが`primary`のhostだけtrue                                   |
| `[jobs] dir` / `tz` / `tick_seconds`         | `~/vault/40_AI/r1/jobs` / `Asia/Tokyo` / `30`                   |
| `[records] root` / `times_dir` / `tasks_dir` | `~/vault` / `11_Times` / `32_Tasks`                             |
| `[assistant] cwd`                            | `~/vault`                                                       |

- 新しいfileは0600で作る。既存fileのmodeは変えない
- homelabでは値が変わると`r1hnd.service`が再起動する。Macは`launchctl kickstart -k gui/$(id -u)/org.dotfiles.r1hnd`で読み直す
- assistantのgroupはrepositoryに書かない。consoleかappで選び、r1hndが`~/.local/state/r1hn/assistant.json`へ保存する
- permission modeもrepositoryに書かない。r1hndが`permissions.json`へ保存し、consoleかappか`/mode`で変える
- 何も設定しないときの既定modeは`auto`である。以前のr1hndが`permissions.json`を書いたworkerはその既定が残るので、device tokenを発行する前に各workerで`GET /v1/permissions`(consoleの設定)を確認し、必要なら`auto`へ変える

## vaultを書くworker

vaultはSyncthingで全hostに届く。2台のr1hndが同じTimesにidを付けるとconflict fileと重複postができるので、vaultを書くのは`primary`の1台だけにする。

- homelabは`dotfiles.r1hn.serve.role = "primary"`である。Times・tasksのwatcher・assistant(mainとside chat・memory・feed)・jobsを動かす
- Macは既定の`coding`である。sessionとT3・ACP・承認だけを扱い、Times・tasks・jobs・threadsなどのrouteは409を返す
- appとDiscord adapterはhomelabを向ける。Macのconsoleからは`/v1/peers/homelab/relay/...`でhomelabへ届く
- `r1hn peer check`とconsoleのワーカー画面は2台がprimaryのとき警告する
- roleを変えたらr1hndを再起動する

## workerとsession

- `config.toml`の`[[dir]]`はhostごとのfileにある。Macとhomelabのfileへ同じ規則を書く
- 別groupの`[[dir]]`に入るdirectoryではT3(ACP)・`POST /v1/sessions`・agentの`session_start`がsessionを作らない。所有者だけが`POST /v1/sessions`の`allow_other_group: true`で1回だけ上書きできる
- `r1hn session move ID --to homelab`はsessionのpermission modeも運ぶ。homelabの方が広いmodeでもsessionは元のmode以下で動く
- Macが閉じている間はpullできない。Macを閉じる前にsessionをhomelabへ移す
- `11_Times`と`10_Daily`の削除と書き換えはClaudeならどのmodeでも所有者の承認になる。r1hnが起動時にPreToolUse hook(`r1hn mcp guard`)を渡す。Codexは`full`と`auto`では対象外なので、vaultでは`ask`で使う
- projectのskill link(`.claude/skills/<id>`と`.agents/skills/<id>`)は`~/.local/share/r1hn/skills/<id>`への相対linkである。各hostが自分のNix storeへのlinkをそこに持つので、Syncthingで同期してもhost同士がlinkを書き換え合わない

### 所有者が書くkey

次はprivateな値なので、homelabの`config.toml`へ所有者が直接書く。

```toml
[push]
key = "op://<vault>/<item>/<field>"   # または "file:~/.config/r1hn/apns.p8" (0600)
key_id = "<10文字のkey id>"
team_id = "<10文字のteam id>"
bundle_id = "<appのbundle id>"
env = "production"                    # Xcodeから入れたbuildだけなら "sandbox"
```

- `key`がなければpushは送らない。`key`だけを書いて他を空にしない
- `[fallback]`は既定(`cross_provider = false`)のままにする。groupごとの上書き`[fallback.group.<group>]`もここへ書く
- 書いた後は`systemctl --user restart r1hnd`で読み直す

## jobsとOlympusの移行

- homelabのr1hndが`~/vault/40_AI/r1/jobs/`のjobを実行する。夜のfeedは組み込みjob `feed-nightly`である
- 以前の`r1hn-feed.timer`はdotfilesにもhomelabにも無い。feedが二重に走ることはない
- 秘書のskillは`secretary` bundleにまとめた。vaultで有効にする: `r1hn capability enable bundle:secretary --project ~/vault`
- `olympus-times-triage`と`olympus-deadline-scheduler`は`nix/home-manager/hosts/olympus-legacy.nix`に残す
- jobの`times-triage`と`deadline-allocation`が1週間動いたら、`homelab.nix`に`dotfiles.olympus.legacyUnits.enable = false;`を書いてapplyする
- 並行期間に片方だけ止めるときは`systemctl --user stop olympus-times-triage.timer`を実行し`~/.local/state/olympus-times-triage/enabled`を消す。flag fileが無いtimerは再起動後も起動しない。deadlineも同じ手順である

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
