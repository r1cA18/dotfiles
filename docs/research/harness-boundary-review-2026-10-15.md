---
title: Harnessの環境移動とデータ正本とOrca境界の設計レビュー
created: 2026-10-15
type: research
tags: [harness, architecture, handoff, orca]
---

# 判定と確認範囲

議論の方向は既存conceptと整合する。ただし実装済みと将来の保証を区別しないと過大な運用保証になる。Orcaを開発frontに使いCoreを実行契約と権限と結果の管理に絞る。知識と添付の全機能をCoreへ追加する構成は避ける。

2026-10-15にGitHub mainを取得して確認。Coreは4dd4beb778bfdc8d979aabe86d7b9fabfb8b39ff。Olympusはacf0bc8d3054f0cf2a41c342d5e33c7f7fd2100a。Coreのopen PRは0件。dotfiles PR #19はfcae180でDraftのまま。homelabへの接続と配置と現行Orca実機の確認は今回行っていない。以前の358 test成功を今回の実行結果とは扱わない。

- [Core MVP検証](https://github.com/r1cA18/harness-core/blob/4dd4beb/docs/mvp-validation.md): Manual pathと隔離test authorityによる検証。live Orca/Tailscale/owner keyの検証ではない
- [引き継ぎ #9](https://github.com/r1cA18/harness-core/issues/9): reconnectとsuccessor Attemptを区別する方針は既存
- [遠隔配置 #60](https://github.com/r1cA18/harness-core/issues/60): 受入チェック未完了
- [環境PR #19](https://github.com/r1cA18/dotfiles/pull/19): CI成功と環境適用は別

# 残す責務と追加契約

| 主体 | 正本・責務 | 担当しないもの |
| --- | --- | --- |
| Core | Contract / Attempt / 承認 / 予算 / 担当権 / Evidence / 外部公開intent | 会話UIと技術ごとのcheck本体 |
| Orca | host側worktreeとterminalとnative sessionの表示・操作 | Core Taskの正式完了と独立した公開承認 |
| 環境adapter | 登録済み環境への配置と起動と観測と停止 | 配置成功からのTask成功の推定 |
| Olympus | 人間のTaskとTimesとKnowledgeとInbox | 別のgeneric schedulerと開発terminal UI |
| asset resolver | immutable参照からの内容取得とhash検証 | 全backendで同一の保存完了保証 |
| Publisher | 現行担当権と対象digestを確認した外部更新 | workerが生成したshellの実行 |

論理境界であり初期から別daemonへ分割する必要はない。既存integration ownership ADRを更新する形で責務を固定する。CoreのWorkspaceはpolicy境界。配置workspaceは別概念としてProjectとCheckoutとAttemptから参照する。新たなExecutionをAttemptと並列の正本にしない。

# 専用rootと目次

専用rootは妥当。名前よりIDと配置規則が重要。以下は提案であり移行済みではない。

```text
<root>/
  registry/                         # Git管理のProjectとRepoとrecipeの登録
  knowledge/<security-scope>/        # 権限単位の正本。形式は移行ADRで決定
  workspaces/<project-id>/<checkout-id>/
    repos/<alias>/                  # 単一repoでも同じ相対配置
    inputs/                         # version付き入力参照からmaterialize
    outputs/                        # 未退避の成果物はcacheではない
  artifacts/                        # 保存済み成果物。durableとcacheを区別
```

rootはhostごとに設定する。dotfilesとOS設定はhome/XDGに残せる。credentialとsocketとlive DBをrootごとのコピー対象にしない。state/cache/configの場所はXDG規約を参考にしつつOS固有pathへ対応する。Windowsも想定するなら大小文字と予約名とsymlink対応をcapabilityとして扱う。

単一repoだけ直下checkoutにする例外は初期には不要。repoなしもinputs/outputsを持つCheckoutとして扱えば同じsnapshot形式に乗る。既存Developはlocation登録して当面保持する。Orca worktreeは既存の管理pathを参照できることを優先し最初から物理移動しない。

目次は大量の本文を複製しない。Project/Repo/Knowledge/AssetのIDとoriginとentrypointとタグとscopeとrevisionを登録する。host固有の配置と最終観測時刻はlocal projectionにする。検索は認可してから候補抽出し本文を予算内で返す。本文の全部返却を常に最小hopと見なさずトークン量と検索漏れも測る。

AIにはclone/ensureとupdateを別操作として提示する。ensureは不足repoのみ配置し既存dirty checkoutを変更しない。updateは対象refとexpected HEADとdirty判定を要求する。GitHubに置くだけで必要なcloneやasset取得が不要になるわけではない。既存ws syncはorigin確認と不足cloneを再利用できるがrevision pinとdirty転送は別実装。

# 引き継ぎの整合性

現行Handoffは単一head_shaとledger headとEvidenceとnext actionを持つ。未commit差分や複数repoやrepoなしの実体を転送する仕組みではない。現行Orca adapterはeffect IDに対応するterminal handleを管理しnative provider sessionのresumeは扱わない。

SnapshotとRealizationを分ける。

- Snapshot: repo IDごとのbase/headとindex/working tree差分と選択したuntracked内容のhashとasset版とrecipe/policy/instructionのdigest
- Realization: 実際のhostとOSとtoolchainとmaterialize結果と検証結果

MacとLinuxで同じ入力snapshotを使えても同じbuild成功を意味しない。移動先で必要なcheckを再実行する。差分はbinaryとmodeとsymlinkとsubmodule/LFSを表現する。secret候補と大きなignored fileは自動転送せず不足を明示する。Git bundleだけではindex/working treeを運べない。

別hostへの移動はprepare → 元worker停止確認 → immutable checkpoint確定 → destination復元・hash確認 → 担当権更新 → successor Attempt開始とする。元workerを観測できない場合は停止成功を推定せずunknownで停止する。転送失敗時に元へ戻す条件も定義する。キャンセル要求とprocess tree停止確認を分ける。

現行per-effect directoryはhost内の重複起動対策。cross-hostのfencing tokenではない。担当権には単調増加generationを持たせPublisherなど副作用を受け付ける境界で再確認する。workerへ直接write credentialを配るなら古いworkerのpushをCoreで拒否できず保証が崩れる。一般の外部APIをexactly-onceと呼ばず重複排除可能性と結果不明を記録する。

Control Host切断中はローカルの編集・commit・検証を継続可能とする。一方で共有Taskの担当切替と外部公開は独断で実行しない。新Control Hostの復旧時は古いControl Hostの鍵・担当権を失効させる手順が必要。Git mirrorだけでは未push ledger tailや外部副作用を復旧できない。保存確認済みsequenceとRPO/RTOを定義する。

# Orcaとの契約

OrcaのDB名とschemaをCoreの契約にしない。内部DBを読んだ調査結果は版依存の観測として保存し対応するCLI/APIを優先する。

対応表はAttempt IDからenvironment ID / runtime instance ID / worktree ID / terminal handle / nullable provider session ID / account profile refを指す。runtime再生成やnative resumeでhandleが変わるため単一session_idへ潰さない。secret値は含めない。

操作はreconnectとnative resumeとhandoffとforkを区別する。新promptが開いただけの場合をresume成功にしない。最新公式資料のOrcaではdaemonがPTYを保持するがhost rebootでagent processは消失する。hibernationは実験機能でresume失敗時に新promptになることも説明されている。現行manifestの観測版1.4.219とLinux pin1.4.215には自動で保証を移さない。

Orcaから直接会話・編集を続ける操作は許可できる。一方Coreの管理対象Taskを別hostで開始する操作や正式公開はCoreへ接続する。Orcaのcommit/push機能とCore Publisherのどちらを使うかをscopeごとに決める。手動運用のrepoまで一律の承認フローに閉じ込めない。

# Knowledgeとassets

JSON正本は合理的な候補だがAI専用であることだけではMarkdown移行の理由にならない。Olympusの現行docs/data-model.mdはMarkdown正本とSQLite mirrorを定義しNotifications等は別のdurable dataとする。JSONとMarkdownを二重の正本にしない。先にIDとrevision付きAPIを固定し同じ契約で保存形式を比較する。移行時はversion付き変換と復元とindex再生成を検証して旧writerを止める。

採用知識はsingle integration writerとexpected revisionで更新する。offline workerはproposalを残し確定正本を同時更新しない。出典原文・observation・本人の決定・summaryを区別し有効期間とsupersedesを持つ。updated_atの新しさだけで優先しない。個人と会社の境界はタグではなくrepoと認可と配布scopeにする。

日本語検索はFTS5採用だけでは完成しない。trigram MATCHには3文字未満の制約があるため「税」「扶養」のようなqueryを受入例に含める。属性一致とaliasと短語fallbackを組み合わせ測定する。後から意味検索を足しても認可とindex watermarkは共通にする。

Assetはmutableな論理IDとimmutableな版/hashを分ける。locatorはbackend別のtyped referenceとする。read/verify/replicateとdurability receiptを分けDrive folderへのwrite成功をremote保存保証へ昇格しない。LFS pointerとLFS contentも別に確認する。originalのretentionとbackup世代と削除権限を設定する。全backendを先に実装せずfolderとLFSから始める。

# CIとレビュー

現行CoreのReviewResultとbudgetとSHA gateは活かす。LLMレビューの自動起動とrepairとPublisherは別の接続課題であり #28等が未完了。Actionsを通知とchecksの入口に残す。self-hosted runnerの実行料金は確認時点のGitHub公式では無料だがmachine/LLM/storage費用は別。

静的fix → 固定snapshotでcheck → 別権限contextでreview → findingに対応したsuccessor修正 → 新snapshotで再検証 → Publisherでbot branch更新を一周させる。reviewerは変更権限を持たない。checkでPR由来コードを実行するならreviewer側にも隔離が必要。CI workflowとcheck definitionをPR内の変更だけで自由に弱められないようtrusted policy revisionを別に固定する。

findingは安定IDと対象snapshotと証拠とstatusを持つ。review対象外になったことを解決と扱わない。差分reviewは範囲を記録する。最大roundと時間とtoken/金額予算を定義し同じ原因・同じtreeで進捗がない場合も停止する。cache keyにsnapshotだけでなくrecipe/toolchain/checkと必要な外部入力を含める。

GitHub Agentic Workflowsのsafe outputsから権限分離した公開を借りられる。OpenHandsのconversation persistenceはruntime固有状態の保存例になるが異種runtimeへの移植契約ではない。Qodoの商用機能とOSS PR-Agentの機能は区別する。製品を丸ごと導入するより必要な契約だけ適用する。

# 実装順と完成条件

1. 用語とdata ownerとOrca capabilityをADRに固定。既存locationを登録して移動しない
2. #9/#60で2 repoとrepoなしのMac → Linux → Macを往復。dirty/index/untracked/binaryと入力assetのhashを確認
3. source不通と再送とキャンセルと旧worker復帰を試験。二重起動と古い公開がないことを確認
4. 別hostにControl Hostを復旧。保存確認済みledgerとassetから続行し旧Control Hostを無効化
5. #28を含む静的checkと1種類のLLM review/repairを一周。costとroundを計測
6. Knowledge APIと検索品質を確認してから保存形式移行とSyncthing縮小。root全体の一括移動は最後

# 外部一次資料

- [Orca Remote Servers](https://www.onorca.dev/docs/remote-servers)
- [Orca Session restore](https://www.onorca.dev/docs/model/session-restore)
- [Orca Agent hibernation](https://www.onorca.dev/docs/agents/hibernation)
- [Git bundleの対象外状態](https://git-scm.com/docs/git-bundle)
- [SQLite FTS5](https://www.sqlite.org/fts5.html)
- [XDG Base Directory](https://specifications.freedesktop.org/basedir/latest/)
- [GitHub Actions料金](https://docs.github.com/en/billing/concepts/product-billing/github-actions)
- [GitHub ephemeral self-hosted runners](https://docs.github.com/en/actions/reference/runners/self-hosted-runners)
- [GitHub Agentic Workflows safe outputs](https://github.github.io/gh-aw/reference/safe-outputs/)
- [OpenHands persistence](https://docs.openhands.dev/sdk/guides/convo-persistence)
- [QodoとOSSの機能比較](https://qodo-merge-docs.qodo.ai/index)
