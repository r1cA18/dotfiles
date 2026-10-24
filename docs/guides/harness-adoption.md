# Harnessの導入候補と検証順

2026-10-24時点の実装状況。部品ごとの完成と日常運用の完成を分ける。
対象PRはDraftでありmainへmergeしていない。本番設定の適用も行っていない。

## 最初に試すrevision

| Repository   | 固定commit                                 | 含まれる範囲                                                                                             |
| ------------ | ------------------------------------------ | -------------------------------------------------------------------------------------------------------- |
| dotfiles     | `4f5bf88a7dcff760c5fc57d64d8ee6cea11200e9` | dsh配置・runtime/model/account分離・共有Skill・portable profile・native binding                          |
| harness-core | `a57f88af575a1c28424cfc0e329094ee3087f419` | bounded improvement・checkpoint・停止確認と結合capture・明示dispatch・Publisher・Gateway認可とJSON proxy |

[dotfiles #30](https://github.com/r1cA18/dotfiles/pull/30)と
[Core #77](https://github.com/r1cA18/harness-core/pull/77)の先端を示す。
各先端はそのbaseへ積んだ変更を含む。個々のPRを別々にcherry-pickする必要はない。
取り込みはPRのbase依存を確認してから行う。運用中checkoutへの一括適用はまだ導入試験に含めない。

## 使える部品と未検証の体験

| Workflow               | 実装済み                                                                           | 残る検証・実装                                   |
| ---------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------ |
| profile選択            | runtime・model・group・account参照を分離                                           | 実loginとmodel entitlementの確認                 |
| device間profile共有    | 中央manifestとhost別private binding                                                | 選択した実accountでの導入試験                    |
| 未commit作業の移動     | 複数repo・staged/unstaged・選択済み未追跡file・binary・assetとcontextの保存復元    | live agentを含む両方向の通し操作                 |
| 移動元の停止と保存     | 外部controllerの`handoff capture`と停止済み`dispatch capture`                      | Mac実機でのnative停止・移動先起動の通し確認      |
| 明示hostへの配置       | signed DispatchPlanと実Orca 1.4.219での合成起動・結果回収                          | 実accountでのlive agent実行                      |
| 実行中workerの停止確認 | 個別停止CLI・停止event・実Orcaでの合成親子process停止                              | hard deadlineとremote切断時の照合                |
| 公開                   | SHA・Attempt・Evidence・Reviewへ結合したcheck/comment gate                         | Draft PR作成とpush経路・本番のcredential分離     |
| Service Gateway        | signed session/Attempt grant・WhoIs・request counter・op/curlのbuffered JSON proxy | 実Service Account・Tailscale Serve・OS分離の配備 |
| slash操作              | 共有`harness` Skillから既存Orca/Core操作を案内                                     | 承認済みcontrollerとlive agentを接続した通し試験 |
| host自動割振り         | 明示host選択の土台                                                                 | capabilityと鮮度付き負荷情報による自動選択       |
| dshでsubscription利用  | 対応gatewayがない経路を拒否                                                        | 正式な認証・protocol adapterと実推論             |
| Consoleと生活アプリ    | 構想と部分実装                                                                     | 今回の基盤導入試験の対象外                       |

local→cloud・cloud→local・local→localで同じcheckpointとdispatchを使う。
OS名で別workflowへ分岐しない。runtime/profile/groupの省略は現在の選択を維持する意味であり
不足bindingを別accountへのfallbackで解決しない。

## 試験の順序

1. 上記revisionを隔離checkoutへ置く
2. 実accountを使わないfixtureを実行する
3. readyなOrcaの隔離worktreeで合成作業を停止・保存・復元・dispatchする
4. 実試験の具体的なgroup・profile・modelと試験hostを固定する
5. `doctor`と`plan`と`resolve-core`でcatalogとhost bindingを照合する
6. 指定済みnative subscriptionで1件実行する
7. 切断と再接続と旧worker復帰時の公開拒否と別host復元を確認する
8. 合格した範囲を確認してから既存Nix運用で適用する

fixtureの成功は実accountの成功やlive handoffの成功には数えない。
`doctor`のreadyも実loginの証明ではない。SSH targetの登録だけではOrcaのpaired runtimeや
project host setupがreadyになったことにはならない。

合成試験の入口はCoreの[validate-checkpoint.py](https://github.com/r1cA18/harness-core/blob/a57f88af575a1c28424cfc0e329094ee3087f419/scripts/validate-checkpoint.py)と
[validate-handoff-controller.py](https://github.com/r1cA18/harness-core/blob/a57f88af575a1c28424cfc0e329094ee3087f419/scripts/validate-handoff-controller.py)と[validate-improvement.py](https://github.com/r1cA18/harness-core/blob/a57f88af575a1c28424cfc0e329094ee3087f419/scripts/validate-improvement.py)と
[validate-gateway-proxy.py](https://github.com/r1cA18/harness-core/blob/a57f88af575a1c28424cfc0e329094ee3087f419/scripts/validate-gateway-proxy.py)。引数と隔離条件は各guideを参照する。
controllerは停止対象worktreeの外に置く。同一worktreeで`cd`するだけでは外部controllerにならない。

step 3の通しgateは[Coreの手順](https://github.com/r1cA18/harness-core/blob/a57f88af575a1c28424cfc0e329094ee3087f419/docs/handoff-controller.md#verification)を参照する。
`--dispatch-test`で合成workerの起動・結果回収・個別停止・結合capture・復元・新Attempt作成を確認できる。default CIではElectronを起動しない。
Linuxでは`--adapter-test`で実行中の合成親子processの停止確認もまとめて実行できる。
結果の`Verifying`は実行結果を回収した状態でありTask全体の完了ではない。

## 検証済みの根拠

- dotfiles #30はMac/Linux各121pass・3native skip・0fail
- native dshのmodel/tool/cancelは別gateで各3pass。合成endpointを使用
- Core #77はMac全493testとfmt・warnings denied ClippyとOpenAPI照合に成功
- Linuxの関連117回帰と最終差分の18回帰に成功
- 実Orca 1.4.219の最終通しgateは隔離Linuxのamd64 emulationで91.968秒の成功
- CLI停止後の結合captureと復元と同じTaskの新Attempt作成とreplayを確認
- staged/unstaged差分と選択した未追跡fileとbinary assetを保持
- 仮group/profileと指定した空dsh homeを使用。実accountとmodelを使用していない
- 試験serverとdisplayと専用containerを終了。既存serviceの変更なし
- [Core #77の検証結果と再実行手順](https://github.com/r1cA18/harness-core/pull/77)
- 過去のMac→homelab→Mac checkpoint往復とLinux Orcaでの合成terminal停止は成功
- Macの隔離Orca起動は以前の45秒試験でreadyへ到達せずnative destinationは未検証
- 10/24の今回のhomelab再確認は名前解決で失敗。認証とservice操作へ到達していない

過去の各PRの検証履歴は[進捗記録](../research/harness-native-profile-progress-2026-10-24.md)に残す。

## 停止後の再開

所有者の選択は現在のAttemptを閉じて同じTaskの新Attemptへ進む方式。
Coreの個別停止CLIが確認済みならAttemptは`Cancelled`になり後続を作成できる。
Task全体の取消や完了を意味しない。停止未確認やcontroller中断では`OutcomeUnknown`を保持して後続を拒否する。
同じrequest IDと理由の再要求は保存済み結果の取得であり再停止を行わない。

Coreで管理している仕事は次の順で進める。

1. 外部controllerの`dispatch stop`で記録済みterminalの停止を確認する
2. `dispatch capture`で停止したAttemptへ結合したcheckpointを新しいprivate directoryへ保存する
3. checkpointだけを転送して`checkpoint verify`と`checkpoint restore`を実行する
4. 同じTaskの新Attemptを作成して前のAttemptがpredecessorに記録されたことを確認する
5. 入力や配置が変わる場合は新しいplanの承認を得て`dispatch run`へ進む

保存receiptはTask・Attempt・effect・停止要求・plan・保存要求とcheckpoint digestを結合する。
同じ要求と保存先の再実行は既存artifactの検証。Orcaへの再接続と再停止を行わない。
未確認停止と別planと範囲外入力を拒否する。途中失敗や破損を成功として扱わない。
停止の確認はsourceを永久に固定するleaseではない。他のwriterは保存前に停止する。
[停止済み作業の保存手順](https://github.com/r1cA18/harness-core/blob/a57f88af575a1c28424cfc0e329094ee3087f419/docs/dispatch.md#capture-work-from-the-stopped-attempt)を参照する。

作業の保存・復元と新しい配置の承認と後続dispatchは個別操作。転送は明示した経路で行う。
一度のslash入力からlive agentを停止・保存・移動・再開する通し操作は引き続き未完了。
[個別停止と再開の手順](https://github.com/r1cA18/harness-core/blob/a57f88af575a1c28424cfc0e329094ee3087f419/docs/dispatch.md#stop-and-continue-in-a-new-attempt)を参照する。

## 実装中の仮登録

group・profile・modelの実物登録は実装後に所有者と一緒に行う。
実装と合成試験は隔離した試験ledgerと空のaccount homeで進める。
catalog結合試験は`testing` groupと`test-default` profileと`fixture-model`を使用する。
実Orcaの通しgateは仮group/profileでPythonの合成commandを動かす。modelは呼び出さない。

## 実装後に一緒に行う初期登録

- 実subscription試験に使うgroup名・profile名・正確なmodel ID
- そのprofileに対応するhost-local login参照
- 実subscription用のreadyな試験Orca destination

実groupの作成とhost登録と実accountの割当を済ませてから中央catalogへprofile/modelを設定する。
各hostでは既存loginの参照をprivate bindingへ登録する。認証情報の複製は行わない。
その後に`resolve-core`で照合し実subscriptionの1件試験へ進む。

Draft PR自動公開のheadをSHA専用branchへ固定するか既存branchを使うかは別の未決定事項。

Service Gatewayのsession capabilityはupstream API keyではない。native OAuthを配布する仕組みでもない。
Attempt grantは現在のTask/Attempt/Contractを照合する。Cancel後の新規requestを拒否する。
Cancel前に受付済みのrequestは完了する可能性がある。
dispatch時のtoken配布と本番のworker/Publisher/Gateway分離は残る。
停止receiptやsession grantだけで旧workerの永久的なfencingを保証したと判断しない。

## 手順の正本

- [modelとaccountの設定](model-connections.md)
- [OrcaとCoreの引き継ぎ](harness-handoff.md)
- [Core外部controller](https://github.com/r1cA18/harness-core/blob/a57f88af575a1c28424cfc0e329094ee3087f419/docs/handoff-controller.md)
- [Core dispatch](https://github.com/r1cA18/harness-core/blob/a57f88af575a1c28424cfc0e329094ee3087f419/docs/dispatch.md)
- [Core Publisher](https://github.com/r1cA18/harness-core/blob/a57f88af575a1c28424cfc0e329094ee3087f419/docs/publisher.md)
- [Core Gateway](https://github.com/r1cA18/harness-core/blob/a57f88af575a1c28424cfc0e329094ee3087f419/docs/gateway.md)

共通Skillの正本は`agents/skills/`。CLIや承認の実装をSkillへ複製しない。
manifestは共有可能な選択情報を保持しprivate bindingとloginとledger stateの保存先を兼ねない。
