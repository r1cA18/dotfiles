# 開発環境の定期掃除

macOSのuser launchd jobで毎日01:00に掃除し1時間ごとに空き容量を確認する。
ログイン時にも容量を確認する。空き100GiB以上の監視処理は容量取得だけで終了する。
homelabはsystemd user timer`developer-cleanup.timer`で毎日01:00に同じ日次処理を行う。停止中に逃した回は次の起動時に実行する。容量監視はない。

設定は`nix/home-manager/programs/developer-cleanup.nix`と同じディレクトリの`developer-cleanup.py`で管理する。
通常の反映経路は`dr`。
Pythonは`-I`で起動しscript配置先のNix store直下をimport探索に加えない。
CPUはNice 10で低優先度にする。I/Oは標準設定にする。
この環境ではBackgroundとLowPriorityIOの組み合わせで起動と探索が数分以上待たされたため適用しない。

## 対象と保持条件

| 対象                           | 処理                                                                                                                   |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| Rust `target`                  | 通常7日保持。空き100GiB未満では3日以上未更新の非稼働生成物を掃除して空き150GiBを目指す                                 |
| `node_modules` `.next` `.venv` | 日次。14日保持。空き100GiB未満では7日。条件は下記                                                                      |
| Xcode DerivedData              | 日次。`~/Library/Developer/Xcode/DerivedData`の項目ごとに14日保持。MobileAndonは対象外                                 |
| Nix user profile               | 日次。最低5世代と30日以内の世代を保持。store GCとdirenv root削除は行わない                                             |
| uv                             | 日次。uvが動いていなければ`uv cache prune`で不要cacheを整理                                                            |
| pnpm                           | 日次。`pnpm store prune`でどのprojectも参照しないpackageを整理                                                         |
| Cargo home                     | 日次。Rust buildが動いていなければ`cargo-cache --autoclean`で展開済みsourceとgit checkoutを削除。取得済みarchiveは残す |
| OrbStack build cache           | 日次。7日以上未使用のcacheを対象に10GiBを目安とするGC                                                                  |
| Docker dangling images         | 日次。作成から30日以上のdangling imageを整理                                                                           |
| Git clone・worktree            | 日次の読み取り専用report。checkoutとbranchは削除しない                                                                 |

Rustの探索範囲は`~/Develop`と`~/Workspaces`。
project内の`.local`と`.device-lab`は永続データとiOS検証結果のため探索しない。
隣接する`Cargo.toml`と`.rustc_info.json`および正しいsignatureの`CACHEDIR.TAG`が必要。
配下の全ファイルとディレクトリのmtimeとctimeが保持期間より古い場合だけ候補にする。
symlinkを含む生成物とGit追跡済みの生成物および状態を確認できないprojectは残す。
最終アクセス日時ではないため更新のない生成物を最近使った場合は再buildが必要になる可能性がある。

## 依存とframeworkの生成物

`node_modules`と`.next`は隣に`package.json`がある場合だけ対象にする。`.venv`は`pyvenv.cfg`がある場合だけ対象にする。
Git管理下のprojectだけを対象にし生成物がGit追跡済みなら残す。
生成物自身と直下の項目・manifestとlockfile・worktreeのHEAD reflogのmtimeがすべて保持期間より古い場合に候補にする。
pnpmのsymlinkを含むため配下全体の走査はしない。
Git indexは走査やpromptの`git status`でも更新されるため活動の判定に使わない。
対象project内にopen fileやprocessの作業directoryがあれば残す。
同じproject内の一時pathへrenameしてから使用状況を再確認して削除する。使用が始まっていれば元へ戻す。

## 掃除しない印

projectかその親directoryに`.developer-cleanup-keep`を置くとそのproject内の生成物を掃除しない。
DerivedDataでは項目自身かその親に置く。

対象project内にopen fileや実行中の出力またはprocessの作業directoryがあれば残す。
Rust builderの作業directoryが対象の親directoryの場合も保護する。
無関係なXcodeや他projectのbuildを理由に全Rustの掃除を止めることはない。
削除直前にも使用状況と更新時刻を確認する。
確認した古いtargetを同じproject内の一時pathへrenameして使用状況と配下の更新時刻を再確認する。
新しく開始したbuildは元のtargetへ出力するため掃除先と重ならない。
Cargoは中立な作業directoryから`--offline --frozen`で起動しtargetとbuild directoryを切り離したpathに固定する。
競合や失敗時は残った出力を元へ戻す。新しいtargetができていれば上書きせず一時pathをログに残す。
processの強制終了などで`.developer-cleanup-*/target`が残った場合は自動削除せず調査対象にする。
二重起動は日次と毎時で共有するファイルlockで防ぐ。

## MobileAndonとiOSの保護

MobileAndonは名前の大文字小文字と区切り文字の違いを正規化して保護する。
別名cloneやworktreeについてもGit common directoryとremote URLを確認する。
該当projectはRust掃除とclone候補判定から除外する。

Swift `.build`・検証用の独立したDerivedData・Archives・DeviceSupport・Simulatorは自動削除しない。
Xcode DerivedDataはMobileAndonの名前を含む項目を残し他projectの項目だけを14日保持で掃除する。
MobileAndonの`.device-lab`と成果物も保持する。

DockerはOrbStackのローカルsocketと一時configを明示する。
remote contextや選択中builderを引き継がずOrbStack停止中は起動しない。
10GiBは未使用期間filterと稼働中cacheの保護を伴うGCの目安であり厳密な上限ではない。
Docker volumes・停止container・tag付きimageは削除しない。
Bun cache・アプリ設定・agent履歴とCargo homeの取得済みarchiveもこのjobでは削除しない。
Bunにはprojectが参照しないcacheだけを消す手段がないため手動で`bun pm cache rm`を使う。

## cloneのreport

Git statusだけではignoredの`.env`等を保護できないため別途検査する。
全local branchとHEADの未push相当commit・stash・ignored data・他worktree・入れ子repo・稼働状況を確認する。
条件を満たすstandalone cloneを`review_candidate`として記録する。
remote refsは取得済みの値でありfetchや作業完了確認は行わない。
この判定だけで安全な削除を保証するものではない。
ファイル内容はreportに保存しない。
候補と過去に記録したcloneは復元用のremote URLとHEADも永続台帳へ保存する。
URLの認証情報とqueryとfragmentは除去する。認証設定やremoteの存続は別途必要になる。

## cloneの日時と永続台帳

以前の候補表の日付はHEADのcommit日でありcloneした日時ではなかった。
commit日と作成・変更・観測の日時を分けて自動記録する。

| 記録                            | 意味と制約                                                                       |
| ------------------------------- | -------------------------------------------------------------------------------- |
| `directory_created_at`          | filesystemのbirthtime。コピーや復元でも変わるためclone実行日時の保証にはならない |
| `last_tracked_file_modified_at` | 現存するGit追跡ファイルの最新mtime。内容を変更した日時の目安                     |
| `last_tracked_file_changed_at`  | 同ファイルの最新ctime。metadataの変更も含む                                      |
| `head_committed_at`             | HEADのcommit日。ローカルの利用時期とは別                                         |
| `first_seen_at`                 | この台帳でそのcloneを初めて観測した日時                                          |
| `unchanged_since`               | ファイルmetadataとHEADとrefsと候補判定理由の変化を観測していない期間の開始       |
| `last_seen_at`                  | Git状態とファイルmetadataの観測に成功した最新日時                                |

最初の観測時に過去の未使用期間は付与しない。
日次観測で状態が30日間変わらず作成・変更日時も30日以上前の場合に`age_review_candidate`をtrueにする。
観測間隔が2日を超えた場合と時計が逆行した場合は不変期間を最初から数え直す。
読むだけの利用や観測の間に発生して痕跡が残らない操作は検出できない。
この判定は見直し用であり未使用や削除の安全性を保証しない。clone削除機能は無効のまま。

台帳は掃除対象外の`~/Develop/developer-cleanup/`に置く。
このdirectoryはRust掃除とclone候補の探索から除外する。
directoryは700でファイルは600。publicなdotfilesには実際の一覧を保存しない。

| ファイル                  | 内容                                                                  |
| ------------------------- | --------------------------------------------------------------------- |
| `repositories.json`       | 現在と過去のcloneの原本。元の場所・復元元・HEAD・日時・判定理由を保持 |
| `repository-events.jsonl` | 初回観測・変化・消失の追記履歴。定期掃除ではrotateも削除もしない      |
| `repositories.md`         | 閲覧用の一覧と復元先情報。原本から再生成                              |

cloneが消えても台帳の行は削除しない。
同じ場所にcloneを作り直した場合はfilesystem identityを分けて古い行も残す。
`missing`は場所が見つからないという意味で削除者と原因は未確認。
探索root自体にアクセスできない場合は`unverifiable`にする。
台帳を置くDevelop自体が利用できない場合は更新を中止し空のDevelopを作り直さない。
このツールによるclone削除履歴は現時点では存在しない。
将来clone削除を実装する場合は削除前の復元情報と実行結果を追記する必要がある。
この台帳は改ざんを防ぐ証明や完全なbackupではない。台帳専用のbackup設定は追加していない。
台帳は各hostの`~/Develop`に置き、host間で同期しない。

日次処理は新規候補も登録する。
`--inventory-only`は前回の候補と台帳の既知cloneだけを再確認しcacheを掃除しない。
全体の日次reportは上書きせず`inventory-report.json`に今回の確認結果を保存する。

## Nix storeとSyncthing

| host  | 処理                                                                                                        |
| ----- | ----------------------------------------------------------------------------------------------------------- |
| macOS | nix-darwinの`nix.gc`が日曜02:00に30日より古い世代を削除する。`nix.optimise`がstoreを定期的にhard link化する |
| Linux | Home Managerの`nh-clean.timer`が毎週`--keep 5 --keep-since 14d`で世代を削除しstore GCを行う                 |
| Linux | Ansibleが`/etc/nix/nix.custom.conf`へ`auto-optimise-store = true`を書く。`dot server apply`で反映する       |

`~/Develop`はSyncthingで同期しない。host間の作業の移動はr1hnのsession moveがgitで運ぶ。
vaultはSyncthingで同期し、homelabは置き換えたファイルを30日保持する。
`dot storage`は`~/Develop/.stversions`が10GiBを超えると警告する。

## 容量の確認とworktree

```bash
dot storage           # このhostの主な消費先
dot storage homelab   # SSH先で同じreport
dot worktrees         # 14日以上触っていない削除可能なlinked worktree
dot worktrees --days 30 --remove
```

`dot worktrees`はghq rootの`~/Develop`以下のlinked worktreeを調べる。
変更と未追跡ファイルがなく全commitがremoteにありbuild出力以外のignoredファイルもなくHEAD reflogが指定日数以上更新されていないものを表示する。
lockされたworktreeは除外する。
`--remove`は1件ずつ確認して`git worktree remove`を実行する。branchは削除しない。

Cargoの共有target directoryは使わない。掃除と使用状況の判定がproject隣の`target`を前提にしているため。

## 手動確認とログ

引数なしではdry-runになる。削除候補と予定する処理を記録する。
Nixは`--dry`で候補を表示しDockerは容量を表示する。

```bash
developer-cleanup
developer-cleanup --apply
developer-cleanup --monitor
developer-cleanup --inventory-only
launchctl print gui/$(id -u)/org.dotfiles.developer-cleanup
launchctl print gui/$(id -u)/org.dotfiles.developer-cleanup-monitor
systemctl --user list-timers developer-cleanup.timer   # homelab
journalctl --user -u developer-cleanup.service         # homelab
```

状態は所有者だけが読める`~/.local/state/developer-cleanup/`に保存する。

| ファイル                 | 内容                                                       |
| ------------------------ | ---------------------------------------------------------- |
| `cleanup.log`            | 実行ログ。2MBでrotateして3世代保持                         |
| `daily-summary.json`     | 最後の日次処理の空き容量・候補数・掃除数・skip理由・失敗数 |
| `monitor-summary.json`   | 最後の毎時監視結果                                         |
| `latest-summary.json`    | 最後に実行した処理の結果                                   |
| `repo-report.json`       | 最後の日次処理で確認したcloneとworktreeの状態              |
| `inventory-report.json`  | 最後に`--inventory-only`で再確認した既知cloneの状態        |
| `inventory-summary.json` | 最後の台帳更新結果                                         |
| `launchd-error.log`      | launchd側の起動エラー。macOSのみ                           |

候補数と掃除数はRust target・依存とframeworkの生成物・DerivedDataの合計件数。uv・pnpm・Cargo home・Nix・Dockerの実行結果はログに残す。
空き容量の前後差には同時に動く他processの増減も含まれる。
削除できない対象があっても他の対象を続ける。ツールの失敗があれば終了コード1になる。
容量不足が続く場合は1日1回までmacOS通知を要求する。実際の表示はOSの通知設定に依存する。Linuxでは通知しない。

## 個別適用と検証

他作業の未適用変更がある場合は固定済みflake入力で対象moduleだけのHome Manager構成を評価する。
Nix生成のコマンドと2つのplistを個別に登録し全体rebuildを避ける。
store rootはstate directoryの`deployment`で保持する。
次回の通常のHome Manager適用後にactivationがこの一時rootを取り除く。

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p test_developer_cleanup.py -v
```

テストでは更新時刻と使用状況の再確認・MobileAndonの別名cloneとworktree・iOS保護・容量閾値・並行buildと失敗時の出力保護・Gitのignored dataとstash・Dockerの接続先隔離を確認する。
台帳は日時の分離・30日判定・観測中断・編集・cloneの消失と置換・認証情報除去・書き込み失敗時の履歴保持も確認する。
一時projectで実際のCargo cleanも検証しproject設定が別の共有出力を指す場合でも指定target以外を残すことを確認した。

現在のCargoは並行build中でもcleanを開始するためlock待ちによる保護には依存しない。
一時projectでclean直前に新しいCargo buildを開始し新しいbinaryが残ることを実証した。

容量不足時の3日保持と150GiB到達時の停止は回帰testで検証した。実環境を意図的に100GiB未満にする検証は行っていない。
