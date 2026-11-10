---
title: Harness2の調査と既存基盤への適用案
created: 2026-10-18
type: research
tags: [harness, agent-skills, architecture, evaluation]
---

# Harness2の調査と既存基盤への適用案

## 結論と調査範囲

Harness2は既存Coreの上でprompt・skill・helperの改善を試す仕組みの参考になる。実行権限と予算と完了判定はCoreへ残す構成を提案する。基盤完成を優先する既存方針は変更しない。

調査対象は[google-research/harness2](https://github.com/google-research/harness2/tree/1cfe254e8d25b15f37048c3730134686abe60335)。確認したcommitは`1cfe254e8d25b15f37048c3730134686abe60335`。READMEと論文と実装とテストを読み取りMacの一時環境で認証不要の検証を実行した。実装の取り込みとhostへの配備は行っていない。

[pyproject.toml](https://github.com/google-research/harness2/blob/1cfe254e8d25b15f37048c3730134686abe60335/pyproject.toml)ではversionは`0.1.0`。Pythonは`>=3.12,<3.14`。coreの必須Python依存は空でrenderとbridgeは追加依存になる。小規模なローカル検証を始めやすい。

## 改善の流れ

モデルを固定し実行結果を比較しながらagentの構成を変える。汎用の作業方法を改善するINVと分野固有の方法を改善するDOMを分けて提案し実行して比較する。その根拠から変更を合成して再実行する。並列探索と逐次改善の両方がある。過去の成果と教訓はdomain別libraryへ蓄積する。[論文](https://arxiv.org/html/2610.14224v1)

1. 同じbase構成で参照実行
2. INVとDOMの変更候補を生成
3. 候補を実行してtrajectoryと成果物を比較
4. 比較結果から変更を合成して実行
5. 複数の最終候補がある場合に成果物を匿名で選択
6. 変更と挙動の関係を振り返ってlibraryへ保存

各taskは共通baseから始める。直前のtaskの構成を無条件に継承せずlibraryから関連部分を参照する。選択対象は既に生成された成果物でありselectorが新しい最終回答を書き直す工程ではない。[schedule.py](https://github.com/google-research/harness2/blob/1cfe254e8d25b15f37048c3730134686abe60335/harness2/core/schedule.py)・[selection.py](https://github.com/google-research/harness2/blob/1cfe254e8d25b15f37048c3730134686abe60335/harness2/core/selection.py)

編集対象はsystem prompt・guardrails・memory・tool guidance・subagent・skill・script・pluginの8種類。実装ではruntimeごとに編集可能なファイルのsurfaceを定義している。[README](https://github.com/google-research/harness2/blob/1cfe254e8d25b15f37048c3730134686abe60335/README.md)・[tree.py](https://github.com/google-research/harness2/blob/1cfe254e8d25b15f37048c3730134686abe60335/harness2/core/tree.py)

## 構造から取り込める点

| 境界 | 確認した実装 | 既存基盤への適用案 |
| --- | --- | --- |
| 改善方法 | `core/recursion.py`が提案と試行と合成を担当 | Coreに依頼する改善workflowとして配置 |
| 実行runtime | `substrate/`が編集面とnative配置と実行とtrajectory読取を担当 | dsh・Claude Code・Codexをpeerとして扱う既存方針を保持 |
| 評価task | `BenchmarkAdapter`がtaskと入力と成果物と採点を担当 | 検証recipeをruntimeから分離 |
| 改善経験 | `library.py`が構成一式とEXPERIENCEとindexを保存 | privateな実行根拠と共有可能な手順を分けて保存 |
| 採点 | `judge.py`が最終選択後に採点 | 改善AIの判断と正式な完了Evidenceを区別 |

`Substrate`は`surface`・`materialise`・`execute`・`read_trajectory`・`preflight`を定義している。製品ごとのnative形式を保持しながら接続する境界として参考になる。`BenchSpec`も改善側channelと実行runtimeとbenchmarkを分ける。[base.py](https://github.com/google-research/harness2/blob/1cfe254e8d25b15f37048c3730134686abe60335/harness2/substrate/base.py)・[spec.py](https://github.com/google-research/harness2/blob/1cfe254e8d25b15f37048c3730134686abe60335/harness2/core/spec.py)

確認したsolver用substrateはOpenCodeとCodex。Claude CLIの改善役channelはあるがdsh用solver adapterはない。既存CoreのExecutionBackendへそのまま差し替えられるAPIでもない。接続するならCoreのdispatchを経由するadapterが必要になる。[substrate](https://github.com/google-research/harness2/tree/1cfe254e8d25b15f37048c3730134686abe60335/harness2/substrate)・[proposer.py](https://github.com/google-research/harness2/blob/1cfe254e8d25b15f37048c3730134686abe60335/harness2/core/proposer.py)

## skillの分野階層と経験の正本

INVとDOMの分割は汎用手順と専門領域の手順を整理する参考になる。一方で8種類のcomponentは資産の形式であり分野の分類とは別の軸になる。以下は既存catalogを拡張するときの案であり新しいschemaの決定ではない。

| 軸 | 例 | 所有するもの |
| --- | --- | --- |
| 資産の形式 | rule / skill / script / plugin / knowledge | 読込方法とruntimeとの接続 |
| 分野 | software → ui → design / personal → tax → jp | 発見と関連付けのcatalog |
| 適用条件 | runtime / 対象年度 / 有効期間 / account scope | metadataと実行時の判定 |
| 根拠と履歴 | 出典 / task ID / revision / supersedes | Knowledgeと実行Evidence |

標準の`SKILL.md`を分野ごとの深いdirectoryへ移動する必要はない。既存PR #22のsidecar catalogを維持し分野階層とruntimeへの配布を分離する。

libraryには再利用の適用状況を表す`cue`と実施する変更を表す`lesson`と根拠の`evidence`を保存する。この3つが揃わない経験は登録しない。indexから必要な構成一式とEXPERIENCEを開く方式で本文の常時読込を避ける。[library.py](https://github.com/google-research/harness2/blob/1cfe254e8d25b15f37048c3730134686abe60335/harness2/core/library.py)

共有資産の正本は引き続き`agents/`を候補にする。個人の入力や実行記録を含む改善経験はprivate Knowledgeへ保存し出典の権限を引き継ぐ。汎用化して検証した手順だけをPRで共有skillへ昇格させる。元のlibraryのdomain directoryはアクセス認可の代わりにはならない。

年度で変わる資料と本人の申告情報を共有skillの固定本文へ混ぜない。手順と対象年度の公式資料と個人データは別レコードとして参照する案が既存のKnowledge設計と整合する。

## 実行コストと保証の違い

`ledger.py`が数える基本量は1task・1modeにつき実行`4k`と提案／合成`3k`。selectionとreflectionはこの数の外にありretryも別に増える。`k=1`でも通常は4回のsolver実行と3回の改善sessionと1回のreflectionになる。これは8回の高位sessionであり8回のAPI requestという意味ではない。[ledger.py](https://github.com/google-research/harness2/blob/1cfe254e8d25b15f37048c3730134686abe60335/harness2/core/ledger.py)

このledgerは実験量と費用の記録でありCoreの事前budget予約と支出上限の代替にはならない。並列化による待ち時間短縮と総計算量の削減も区別する必要がある。

完了markerと構成fingerprintによるresumeは有用だが実験の再利用を判断する仕組みになる。別hostへの作業移動と古いworkerの公開阻止は別途必要になる。fingerprintも短縮SHA-1でありCoreの署名済みEvidenceとして採用する根拠にはならない。[runmark.py](https://github.com/google-research/harness2/blob/1cfe254e8d25b15f37048c3730134686abe60335/harness2/core/runmark.py)

Codexの参照起動にはapprovalとsandboxを無効化するflagが含まれる。さらに実験ガイドはnetwork制限がなく検証中にCodexが公開rubricを取得した事例を明記する。編集surfaceのvalidatorと本文filterだけでは実行隔離を保証できない。[codex.py](https://github.com/google-research/harness2/blob/1cfe254e8d25b15f37048c3730134686abe60335/harness2/substrate/codex.py)・[実験ガイド](https://github.com/google-research/harness2/blob/1cfe254e8d25b15f37048c3730134686abe60335/docs/EXPERIMENTS.md)

導入時は入力を絞った隔離workerで実行しmodel endpointなど必要な通信だけを許可する案にする。編集可能なのはtask用の資産overlayへ限定する。Core policyとsignerと認証情報と公開権限を改善対象へ渡さない。

モデルによる成果物選択は正しさの証明にはならない。論文も選択の失敗と共通の誤前提の伝播と追加コストを制限として扱う。論文の性能向上は著者のbenchmark結果であり自分たちの基盤での改善は未検証。[論文の失敗分析と制限](https://arxiv.org/html/2610.14224v1)

また採点失敗を0点ではなくunscoredとして残すため比較時は成功率だけでなく未採点件数と失敗件数も報告する。[judge.py](https://github.com/google-research/harness2/blob/1cfe254e8d25b15f37048c3730134686abe60335/harness2/core/judge.py)

## 今回実行した検証

Mac arm64で既存dotfilesのflake inputからNixのPython 3.12.14を一時利用した。依存のglobal installは不要だった。実行processのHOMEとXDG directoryは一時領域へ分離しAPI credentialを環境へ引き継がなかった。OS sandboxの強制隔離試験は行っていない。

| 検証 | 結果 | 確認範囲 |
| --- | --- | --- |
| upstream unittest | 5件成功 | `python3.12 -m unittest discover -s tests -v` |
| deterministic demo初回 | 2task完了 / 0失敗 | `--k 2 --mode both`で28回のscript実行と32回の固定editor呼出 |
| 同じdemoの再実行 | 2taskをskip | 追加script実行0回 / 追加editor呼出0回 |
| library参照 | 次taskの開始時に各modeで先行entryが1件 | 各modeの初回taskは0件 |
| repository差分 | なし | 取得したupstream checkoutは変更なし |

upstreamテストは候補構成の変更と成果物欠落による再実行も確認する。さらに不正なPython候補のretryと費用集計とNO_ENTRYの除外と選択失敗時の採点禁止を検査する。[test_workflow.py](https://github.com/google-research/harness2/blob/1cfe254e8d25b15f37048c3730134686abe60335/tests/test_workflow.py)

demoの提案と選択とreflectionは固定ロジック。修正されたPython scriptは実行されるがOpenCodeやCodexを起動する検証ではない。LLMによる改善能力と実モデル性能とLinuxでの動作とsubscription認証は今回の検証対象に含まれない。[demo.py](https://github.com/google-research/harness2/blob/1cfe254e8d25b15f37048c3730134686abe60335/harness2/demo.py)

## 適用順序の提案

1. 既存Coreのdispatchでaccount groupとbudget reservationとruntimeとhostと入力snapshotを結合
2. 起動失敗と不明な実行結果と再起動時の復旧を検証
3. その上で隔離した小規模な改善workflowを`k=1`から比較
4. 固定modelと環境と検証recipeで成功率と費用と時間と失敗件数を測定
5. 改善対象と分けた未使用taskでも確かめて共有skillへの昇格をreview

Coreには候補を普通のAttemptとして記録し承認と予算とEvidenceを既存APIで扱わせる構成を提案する。新しいrepoや常駐serviceが必要かは接続の規模が分かってから判断する。現在の調査だけでは分割しない。

接続実装を始める前には改善loopの導入範囲と費用上限を所有者へ確認する。今回の成果は調査と認証不要のローカル検証と記録までになる。既存の優先順位とruntime設定と共有instructionは変更していない。

関連する現在地は[全体レビュー](harness-architecture-review-2026-10-18.md)と[実装進捗](harness-implementation-progress-2026-10-02.md)を参照する。
