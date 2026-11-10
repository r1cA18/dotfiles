---
title: "個人版Orcaと公式スマホアプリの接続"
created: 2026-11-03
type: guide
tags: [orca, mobile, self-hosting, tailscale]
---

# 個人版Orcaと公式スマホアプリの接続

## 採用する構成

個人版Orcaへの接続は公式Orca Mobileを使う。自前ホストであることだけを理由に
iOS/Androidアプリを作り直す必要はない。通信仕様と提供するcapabilityの互換性が条件になる。
まずLANまたはTailscaleの直接接続を検証する。

2026-11-03に公式ドキュメントと個人版`1.4.247-personal.1`のsource・配布物を確認した。
App Storeの掲載版は`0.0.62`で個人版の基点に含まれるmobile sourceも同じversion。
掲載versionの一致は手元の実機にそのアプリが入っていることの証明ではない。

## 自作アプリが必要になる境界

| 変更・用途 | 対応 |
| --- | --- |
| 個人版desktopやheadless serverへ接続 | 対応する公式アプリからpairingする |
| 既存terminalでagentやDSHのTUIを操作 | 既存のterminal経路を利用。実機での操作確認は別途必要 |
| desktopだけのsidebar変更 | スマホの見た目へ自動反映されるとは扱わない |
| hostが配信するmobile画面の変更 | 既存shellのschema・protocol・native bridgeの対応範囲ならhost側bundleを更新できる |
| 新しいnative機能・bridge・独自のアプリ名や配布 | mobile sourceもforkして独自署名・配布を用意する |
| 公式サービスへの依存も除去 | 接続・Relay・Pushを別々に評価。Pushの独立にはnative appの配布やAPNs/FCM資格情報も関わる |

Orcaのmobile shellはpairingしたhostからmanifestと画面assetをRPCで取得する。
受信内容のhashと互換性を検証しcacheして表示する。すべての画面とOS機能を自由に置換できる仕組みではない。
Harness Consoleをスマホにも出す場合もmobile向けの画面と操作契約を用意する必要がある。

## 接続方式

| 経路 | 条件と境界 |
| --- | --- |
| 同じLAN | Mac/serverが起動中でスマホから到達可能。直接pairingにOrca Relayへのsign-inは不要 |
| Tailscale | Mac/serverとスマホが同じtailnetで通信可能。スマホから到達できるTailscale addressを選択 |
| Orca Relay | 公式のsign-inとRelayに依存する別の接続経路 |
| Push通知 | 直接接続とは別。現行のdesktop既定値は公式Push gateway |

直接通信でもdeviceごとのpairingと暗号化を使う。
pairing URL・QR・device tokenをGitHubや共有文書へ保存しない。
電話からの通常操作が成功したこととPush通知の到達は別の確認として記録する。

## このMacでの手順

稼働中のagentは継続する。個人版への入れ替えは
[同一Macの移行手順](personal-harness-migration.md)に従って作業終了後に行う。
既存pairingがある場合は先に接続を確認し、最初から登録を削除しない。

1. スマホへ公式Orca Mobileをインストールまたは更新する
2. 外出先から使う場合はスマホでも既存のTailscaleへ接続する
3. 個人版Orcaを起動してmobile pairing画面を開く
4. 直接接続を選びスマホから到達できるLANまたはTailscale addressを指定する
5. スマホのPairから画面上のQRを読むかpairing codeを入力する
6. 既存workspaceと専用の確認用terminalが見えることを確認する
7. 確認用terminalだけで表示と入力を試す
8. 一度接続を切って同じsessionへ戻れることを確認する

他のagentが作業中のterminalへ試験用の文字やCtrl-Cを送らない。
接続不能ならendpoint・protocol・permissionを確認し、既存作業を止める再起動を最初の対処にしない。

Mac上で動く仕事はMacが利用可能な間だけ操作できる。
Macを閉じている間も使う目的では常時稼働するhostへ仕事を配置し、そのhostへ接続する。
headless serverには公式の`--mobile-pairing`経路があるが、このMacと同じprofileで
desktopと別の`orca serve`を二重起動しない。

## 検証記録

| 項目 | 2026-11-03の結果 |
| --- | --- |
| forkによる通信契約の差分 | upstream stableからmobile sourceと対象のprotocol・RPC・Push実装に差分なし |
| mobile protocol | source上でversion 3。互換性の下限は2 |
| mobile側の対象テスト | 5ファイル57件成功。pairing・直接E2EE・protocol・bundle互換性と取得 |
| host側の対象テスト | 4ファイル70件成功。protocol・pairing offer・mobile bundle配信 |
| 配布済みmobile bundle | 181 assets・11 routes。全assetのhash・サイズとpackage検証が成功 |
| このMacの接続前提 | Orca runtime応答あり。Tailscale接続中 |
| 配布済みアプリへの隔離RPC試験 | `1.4.247-personal.1`へmobile scopeで暗号化接続。状態取得とbundle互換性判定が成功。HTMLとJavaScriptの取得・hash検証も成功 |
| 実機の画面・入力・復帰・Push | 未確認 |

実行したテストは署名済みパッケージと同じsourceを対象にしている。
スマホ実機のOS権限・ネットワーク経路・描画を代替するものではない。
隔離RPC試験では空のhome/profileを使い表示windowは0件。試験用アプリは終了済み。
稼働中のOrca・既存pairing・他のagentは変更していない。

## 参照

- [公式Mobile companion](https://www.onorca.dev/docs/mobile)
- [公式Remote Orca Servers](https://www.onorca.dev/docs/remote-servers)
- [iOSアプリ](https://apps.apple.com/us/app/orca-ide/id6766130217)
- [Android配布](https://www.onorca.dev/download/android)
- [個人版Orcaの進捗](../research/dsh-orca-integration-progress-2026-11-03.md)

sourceの確認箇所は`mobile/src/transport/protocol-version.ts`と
`mobile/src/transport/protocol-compat.ts`と`mobile/src/mobile-web-shell/mobile-web-shell-session-effects.ts`。
host側は`src/main/runtime/rpc/methods/mobile-web-bundle.ts`と
`src/main/runtime/runtime-rpc/runtime-rpc-mobile-pairing.ts`と
`src/main/runtime/push/push-gateway-origin.ts`。
