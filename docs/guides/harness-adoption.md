# Harnessの導入候補と検証順

2026-10-24時点の実装状況。部品ごとの完成と日常運用の完成を分ける。
対象PRはDraftでありmainへmergeしていない。本番設定の適用も行っていない。

## 最初に試すrevision

| Repository   | 固定commit                                 | 含まれる範囲                                                                                   |
| ------------ | ------------------------------------------ | ---------------------------------------------------------------------------------------------- |
| dotfiles     | `4f5bf88a7dcff760c5fc57d64d8ee6cea11200e9` | dsh配置・runtime/model/account分離・共有Skill・portable profile・native binding                |
| harness-core | `106215d71d65a3d1442374e8e4d11f1ca30d2f2f` | bounded improvement・checkpoint・外部capture・明示dispatch・Publisher・Gateway認可とJSON proxy |

[dotfiles #30](https://github.com/r1cA18/dotfiles/pull/30)と
[Core #72](https://github.com/r1cA18/harness-core/pull/72)の先端を示す。
各先端はそのbaseへ積んだ変更を含む。個々のPRを別々にcherry-pickする必要はない。
取り込みはPRのbase依存を確認してから行う。運用中checkoutへの一括適用はまだ導入試験に含めない。

## 使える部品と未検証の体験

| Workflow              | 実装済み                                                                        | 残る検証・実装                                   |
| --------------------- | ------------------------------------------------------------------------------- | ------------------------------------------------ |
| profile選択           | runtime・model・group・account参照を分離                                        | 実loginとmodel entitlementの確認                 |
| device間profile共有   | 中央manifestとhost別private binding                                             | 選択した実accountでの導入試験                    |
| 未commit作業の移動    | 複数repo・staged/unstaged・選択済み未追跡file・binary・assetとcontextの保存復元 | live agentを含む両方向の通し操作                 |
| 移動元の停止と保存    | 対象worktree外からの`handoff capture`                                           | Mac実機でのnative停止・移動先起動の通し確認      |
| 明示hostへの配置      | signed DispatchPlanとaccount/group/host/budget照合                              | readyな実Orca destinationでの実行                |
| 公開                  | SHA・Attempt・Evidence・Reviewへ結合したcheck/comment gate                      | Draft PR作成とpush経路・本番のcredential分離     |
| Service Gateway       | signed session grant・WhoIs・request counter・op/curlのbuffered JSON proxy      | 実Service Account・Tailscale Serve・OS分離の配備 |
| slash操作             | 共有`harness` Skillから既存Orca/Core操作を案内                                  | 承認済みcontrollerとlive agentを接続した通し試験 |
| host自動割振り        | 明示host選択の土台                                                              | capabilityと鮮度付き負荷情報による自動選択       |
| dshでsubscription利用 | 対応gatewayがない経路を拒否                                                     | 正式な認証・protocol adapterと実推論             |
| Consoleと生活アプリ   | 構想と部分実装                                                                  | 今回の基盤導入試験の対象外                       |

local→cloud・cloud→local・local→localで同じcheckpointとdispatchを使う。
OS名で別workflowへ分岐しない。runtime/profile/groupの省略は現在の選択を維持する意味であり
不足bindingを別accountへのfallbackで解決しない。

## 試験の順序

1. 上記revisionを隔離checkoutへ置く
2. 実accountを使わないfixtureを実行する
3. 具体的なgroup・profile・modelと試験hostを固定する
4. `doctor`と`plan`と`resolve-core`でcatalogとhost bindingを照合する
5. readyなOrcaの隔離worktreeで合成shell作業を停止・保存・復元・dispatchする
6. 指定済みnative subscriptionで1件実行する
7. 切断と再接続と旧worker復帰時の公開拒否と別host復元を確認する
8. 合格した範囲を確認してから既存Nix運用で適用する

fixtureの成功は実accountの成功やlive handoffの成功には数えない。
`doctor`のreadyも実loginの証明ではない。SSH targetの登録だけではOrcaのpaired runtimeや
project host setupがreadyになったことにはならない。

合成試験の入口はCoreの`scripts/validate-checkpoint.py`と
`scripts/validate-handoff-controller.py`と`scripts/validate-improvement.py`と
`scripts/validate-gateway-proxy.py`。引数と隔離条件は各guideを参照する。
controllerは停止対象worktreeの外に置く。同一worktreeで`cd`するだけでは外部controllerにならない。

## 検証済みの根拠

- dotfiles #30はMac/Linux各121pass・3native skip・0fail
- native dshのmodel/tool/cancelは別gateで各3pass。合成endpointを使用
- Core #71はMac/Linux各444testとfmt・Clippy・fixture verifyに成功
- Core #71の固定dotfiles結合gateも成功。[Linux結果](https://github.com/r1cA18/harness-core/actions/runs/40058531645)
- Core #72はMac全457testとfmt・Clippy・OpenAPI照合・fixture verifyに成功
- Core #72の実CLI→trusted Unix ingress→実curl→合成HTTPSも成功
- Core #72のLinux full/joint/TLS結果は同PRのcheckと本文で確認
- 過去のMac→homelab→Mac checkpoint往復とLinux Orcaでの合成terminal停止は成功
- Macの隔離Orca起動は45秒でreadyへ到達せずnative destinationは未検証
- 最新のTailscale確認ではhomelab peerを検出できず

## 導入前に必要な入力

- 実subscription試験に使うgroup名・profile名・正確なmodel ID
- そのprofileに対応するhost-local login参照
- readyな試験用Orca destination
- Draft PR作成のheadをSHA専用branchへ固定するか既存branchを使うかの方針

Service Gatewayのsession capabilityはupstream API keyではない。native OAuthを配布する仕組みでもない。
Attempt単位のgrant発行と本番のworker/Publisher/Gateway分離は残る。
停止receiptやsession grantだけで旧workerの永久的なfencingを保証したと判断しない。

## 手順の正本

- [modelとaccountの設定](model-connections.md)
- [OrcaとCoreの引き継ぎ](harness-handoff.md)
- [Core外部controller](https://github.com/r1cA18/harness-core/blob/106215d71d65a3d1442374e8e4d11f1ca30d2f2f/docs/handoff-controller.md)
- [Core dispatch](https://github.com/r1cA18/harness-core/blob/106215d71d65a3d1442374e8e4d11f1ca30d2f2f/docs/dispatch.md)
- [Core Publisher](https://github.com/r1cA18/harness-core/blob/106215d71d65a3d1442374e8e4d11f1ca30d2f2f/docs/publisher.md)
- [Core Gateway](https://github.com/r1cA18/harness-core/blob/106215d71d65a3d1442374e8e4d11f1ca30d2f2f/docs/gateway.md)

共通Skillの正本は`agents/skills/`。CLIや承認の実装をSkillへ複製しない。
manifestは共有可能な選択情報を保持しprivate bindingとloginとledger stateの保存先を兼ねない。
