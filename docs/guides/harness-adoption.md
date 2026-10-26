# Harnessの導入候補と検証順

2026-10-27時点の実装状況。部品ごとの完成と日常運用の完成を分ける。
対象PRはDraftでありmainへmergeしていない。本番設定の適用も行っていない。

## 最初に試すrevision

| Repository   | 固定commit                                 | 含まれる範囲                                                                                                                        |
| ------------ | ------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------- |
| dotfiles     | `c027bad993f4d27f2bbdc77666b20dae155bd5f7` | dsh配置・runtime/model/account分離・共有Skill・portable profile・native binding・承認済み後続dispatch用共有Skill                    |
| harness-core | `a92f86c24748452182a51db35fdd38494290b40f` | bounded improvement・checkpoint・停止確認と結合capture・後続Attempt guard・承認済み後続dispatch・Publisher・Gateway認可とJSON proxy |

[dotfiles #32](https://github.com/r1cA18/dotfiles/pull/32)と
[Core #79](https://github.com/r1cA18/harness-core/pull/79)の先端を示す。
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
| slash操作              | Core管理とstandaloneを分けた共有`harness` Skillの操作手順                          | 承認済みcontrollerとlive agentを接続した通し試験 |
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

合成試験の入口はCoreの[validate-checkpoint.py](https://github.com/r1cA18/harness-core/blob/a92f86c24748452182a51db35fdd38494290b40f/scripts/validate-checkpoint.py)と
[validate-handoff-controller.py](https://github.com/r1cA18/harness-core/blob/a92f86c24748452182a51db35fdd38494290b40f/scripts/validate-handoff-controller.py)と[validate-improvement.py](https://github.com/r1cA18/harness-core/blob/a92f86c24748452182a51db35fdd38494290b40f/scripts/validate-improvement.py)と
[validate-gateway-proxy.py](https://github.com/r1cA18/harness-core/blob/a92f86c24748452182a51db35fdd38494290b40f/scripts/validate-gateway-proxy.py)。引数と隔離条件は各guideを参照する。
controllerは停止対象worktreeの外に置く。同一worktreeで`cd`するだけでは外部controllerにならない。

step 3の通しgateは[Coreの手順](https://github.com/r1cA18/harness-core/blob/a92f86c24748452182a51db35fdd38494290b40f/docs/handoff-controller.md#verification)を参照する。
`--dispatch-test`で合成workerの起動・結果回収・個別停止・結合capture・復元・新plan承認・後続dispatchと完了回収を確認できる。default CIではElectronを起動しない。
Linuxでは`--adapter-test`で実行中の合成親子processの停止確認もまとめて実行できる。
結果の`Verifying`は実行結果を回収した状態でありTask全体の完了ではない。

## 検証済みの根拠

- dotfiles #32はLinux全121pass・3native skip・0fail。既存4checkがすべて成功
- native dshのmodel/tool/cancelは別gateで3pass。合成endpointと共有Skill本文展開を確認
- 更新済み共有SkillとruntimeのMac関連18件が成功。0fail・74assertion
- 実際の更新済み`harness` Skillも固定dsh 0.2.1-rc.2の最初の合成requestへ本文を展開
- 通常promptの対照試験ではmetadataのみ。実agentの自動選択や移動操作の証明ではない
- Core #79はMac全509testとfmt・warnings denied ClippyとOpenAPI照合に成功
- Linuxの関連93回帰に成功。公開後の全体CI結果は実装PRを参照
- 固定commitのfixture verifyがchanged=falseとreused=falseで成功
- 実Orca 1.4.219の通しgateは隔離Linuxのamd64 emulationで246.145秒の成功
- CLI停止後の結合captureと復元と移動先plan承認と同じTaskの後続dispatchと完了回収を確認
- 同じrequest IDの再送で追加launchと再停止を行わないことを確認
- stale controllerと後続の重複と異なるpredecessorの再要求を拒否
- staged/unstaged差分と選択した未追跡fileとbinary assetを保持
- 仮group/profileと指定した空dsh homeを使用。実accountとmodelを使用していない
- 試験serverとdisplayと専用containerを終了。既存serviceの変更なし
- [Core #79の検証結果と再実行手順](https://github.com/r1cA18/harness-core/pull/79)
- 過去のMac→homelab→Mac checkpoint往復とLinux Orcaでの合成terminal停止は成功
- Macの隔離Orca起動は以前の45秒試験でreadyへ到達せずnative destinationは未検証
- 10/24のhomelab再確認は名前解決で失敗。認証とservice操作へ到達していない

過去の各PRの検証履歴は[進捗記録](../research/harness-native-profile-progress-2026-10-24.md)に残す。
共有Skillの検証範囲と再実行方法は[Skill検証記録](https://github.com/r1cA18/dotfiles/blob/c027bad993f4d27f2bbdc77666b20dae155bd5f7/docs/research/harness-resume-skill-progress-2026-10-24.md)を参照する。

## 停止後の再開

所有者の選択は現在のAttemptを閉じて同じTaskの新Attemptへ進む方式。
Coreの個別停止CLIが確認済みならAttemptは`Cancelled`になり後続を作成できる。
Task全体の取消や完了を意味しない。停止未確認やcontroller中断では`OutcomeUnknown`を保持して後続を拒否する。
同じrequest IDと理由の再要求は保存済み結果の取得であり再停止を行わない。

Coreで管理している仕事は次の順で進める。

1. 外部controllerの`dispatch stop`で記録済みterminalの停止を確認する
2. `dispatch capture`で停止したAttemptへ結合したcheckpointを新しいprivate directoryへ保存する
3. checkpointだけを転送して`checkpoint verify`と`checkpoint restore`を実行する
4. 移動先のplanを作成して入力や配置の変更を反映した現在のContractの承認を得る
5. 保存receiptのAttempt IDと承認済み移動先planを`dispatch resume --predecessor <closed-source-attempt>`へ渡す
6. 新Attemptの実行receiptを確認する。同じ要求の再送は同じAttemptとeffectを使う

`dispatch resume`はguard付き後続作成とreadyとstartとdispatchを既存serviceでまとめる。
`attempt create`だけでは`Created`のままであり実行準備と起動は完了しない。
準備中に失敗した場合は`attempt list`とproblemを確認して原因を解決してから同じrequest IDで再実行する。
unknown状態や予算拒否を新しいIDで回避しない。閉じた後続Attemptは再起動しない。

Attemptは作成時の承認済みContractへ結合される。
作成後にContractを変更しても結合先は更新されず起動を拒否されるため承認を先に行う。

直前Attemptの照合と後続作成は同じTask lock内で行う。
別controllerがTaskを進めていた場合は`predecessor_conflict`を返す。
新しいIDへ自動で置き換えずTaskの状態を確認する。
同じrequest IDとpredecessorの再要求は既存の後続Attemptを返す。
predecessorを変更した再要求は`request_conflict`になる。
[承認済み後続dispatchの手順](https://github.com/r1cA18/harness-core/blob/a92f86c24748452182a51db35fdd38494290b40f/docs/dispatch.md#prepare-and-dispatch-the-successor)を参照する。

保存receiptはTask・Attempt・effect・停止要求・plan・保存要求とcheckpoint digestを結合する。
同じ要求と保存先の再実行は既存artifactの検証。Orcaへの再接続と再停止を行わない。
未確認停止と別planと範囲外入力を拒否する。途中失敗や破損を成功として扱わない。
停止の確認はsourceを永久に固定するleaseではない。他のwriterは保存前に停止する。
[停止済み作業の保存手順](https://github.com/r1cA18/harness-core/blob/a92f86c24748452182a51db35fdd38494290b40f/docs/dispatch.md#capture-work-from-the-stopped-attempt)を参照する。

作業の保存・復元と新しい配置の承認は先行する明示操作。転送は明示した経路で行う。
後続作成と実行準備と起動を外部CLIでまとめる。
一度のslash入力からlive agentを停止・保存・移動・再開する通し操作は引き続き未完了。
Coreの現adapterはcontrollerと同じlocal filesystemとOrca runtimeを要求する。
remote Orcaへ接続できてもこれだけでremote dispatchにはならない。
ledgerと承認keyをWorkerへコピーしてこの境界を迂回しない。
[個別停止と再開の手順](https://github.com/r1cA18/harness-core/blob/a92f86c24748452182a51db35fdd38494290b40f/docs/dispatch.md#stop-and-continue-in-a-new-attempt)を参照する。

元Attemptの使用量がunknownのまま精算された場合は同じbudget windowの新規予約を拒否する。
予算上限を増やしても使用量は既知にならない。実agentの使用量収集と精算連携は残件。
成功経路の合成試験は既知の合成使用量を明示するため実subscriptionでの再開成功とは区別する。
unknownをゼロで置き換えない。

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
- [Core外部controller](https://github.com/r1cA18/harness-core/blob/a92f86c24748452182a51db35fdd38494290b40f/docs/handoff-controller.md)
- [Core dispatch](https://github.com/r1cA18/harness-core/blob/a92f86c24748452182a51db35fdd38494290b40f/docs/dispatch.md)
- [Core Publisher](https://github.com/r1cA18/harness-core/blob/a92f86c24748452182a51db35fdd38494290b40f/docs/publisher.md)
- [Core Gateway](https://github.com/r1cA18/harness-core/blob/a92f86c24748452182a51db35fdd38494290b40f/docs/gateway.md)

共通Skillの正本は`agents/skills/`。CLIや承認の実装をSkillへ複製しない。
manifestは共有可能な選択情報を保持しprivate bindingとloginとledger stateの保存先を兼ねない。
