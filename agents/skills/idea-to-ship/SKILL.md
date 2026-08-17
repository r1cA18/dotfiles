---
name: idea-to-ship
description: |
  Turn a rough product or tool idea into a researched, implemented, tested, reviewed, pushed, and documented result.
  Use for autonomous end-to-end work that must compare competitors, inspect the local environment, choose a proven stack, build the solution, clean up Git, and produce an HTML handoff.
  Reuses focused research, implementation, and review skills instead of replacing them.
  Triggers: "take this idea to production", "research and build this", "build and ship this", "idea to implementation"
  日本語: 「このアイデアを形にして」「競合調査から実装までやって」「最後まで自律的に作って」「調査して作ってpushまでして」
  NOT for a small isolated edit, research-only request, or review-only request.
user-invocable: true
---

# Idea to Ship

曖昧なアイデアを、根拠のある実装と再現可能なhandoffまで自律的に運ぶ。
調査だけ、実装だけ、reviewだけの依頼には使わず、対応するfocused skillを使う。

## Core Contract

1. 最初のアイデアを仮Goalへ変換する。
2. 調査と実装で情報が増えるたびにGoalを具体化する。
3. 安全で可逆な作業は質問待ちにせず進める。
4. 進路を変える判断と外部への不可逆な変更だけ確認する。
5. 完了条件を証拠で監査し、Gitとhandoffまで終えてから完了とする。

## Start

1. project-local instructionsと必須architecture docsを読む。
2. アイデア、対象ユーザー、期待する結果、既知の制約を抽出する。
3. 不足情報は明示的な仮定として置き、調査で検証する。
4. native Goal機能があれば仮Goalを作る。なければ作業planをGoalとして管理する。
5. 成功条件を観測可能な結果で3〜7個定義する。
6. 外部変更のauthorization envelopeを確認する。

## Authorization Envelope

skill起動時の依頼文から許可範囲を判断する。「最後まで」「pushまで」「repoも作って」が明示されていれば、その範囲は再確認しない。

| Action | Default |
| --- | --- |
| local read、Web research、test、build | 自動実行 |
| workspace内の実装と可逆な編集 | 自動実行 |
| private repo作成、push、PR作成 | 明示済みなら自動実行 |
| 課金、公開repo、production deploy、data削除 | 必ず直前確認 |
| merge、branch削除、既存remote変更 | 明示済みでなければ確認 |

判断方法と質問UIは[decision-gates.md](references/decision-gates.md)を読む。

## Research and Decide

1. [research-playbook.md](references/research-playbook.md)を読み、作るものに合うsourceを選ぶ。
2. direct competitors、adjacent solutions、OSS building blocks、do-nothing optionを比較する。
3. marketing claimではなく、公式docs、実装、pricing、利用者の不満、更新状況を集める。
4. local environmentを調べ、既存projectへ統合、OSS採用、fork、新規実装を比較する。
5. license、maintenance、security、migration cost、lock-inを確認する。
6. 採用方針とtech stackを証拠付きで決める。
7. Goal、成功条件、scope外を更新する。

調査結果で重大な前提が崩れた場合だけ質問する。回答待ちでも安全な調査とprototypeは続ける。

## Choose the Home

| 状況 | 方針 |
| --- | --- |
| 既存projectに自然なextension pointがある | 最小変更で統合 |
| 実績あるOSSが要件を満たす | 導入または薄いadapterを実装 |
| OSSは近いが差分が本質的 | forkよりupstream拡張か独立実装を比較 |
| 適切な置き場所がない | project規約に沿うprivate repoを新設 |

新規repoではlocal convention、`ghq root`、GitHub owner、命名規則を調べる。許可範囲内ならprivate remote作成、適切なghq配下への配置、初期化、pushまで実行する。

## Build Loop

1. riskyな変更ではbaseline testを先に実行する。
2. acceptance criteriaから最小の縦切り実装を選ぶ。
3. behaviorを証明するtestを先に書く。非現実的な場合は理由を記録する。
4. projectの既存patternとtoolchainで実装する。
5. unit、integration、user-facing scenarioの順に検証する。
6. failureを原因別に切り分け、実装修正とtest修正を混同しない。
7. 各milestone後にGoalとplanを更新する。

実装詳細はproject固有skillとdomain skillを必要に応じて使う。指示が競合する場合はproject-local instructionsを優先する。

## Review and Refactor Loop

1. tests、lint、typecheck、buildを実行する。
2. built-in reviewまたは`codex review`で対象diffをreviewする。
3. correctness、security、performance、maintainability、project rulesの指摘を統合する。
4. criticalとwarningを修正する。
5. verificationとreviewを最大3回繰り返す。
6. 同じ問題が再発したら局所修正を止め、設計か前提を見直す。
7. behaviorが固定されてから重複、命名、責務境界だけrefactorする。
8. refactor後に全verificationを再実行する。

可能なら`post-review`をreview loopとして再利用する。

## Git Closeout

[delivery-playbook.md](references/delivery-playbook.md)に従う。

1. unrelated user changesを除外する。
2. diffと生成物を監査する。
3. secret、大容量artifact、一時fileが含まれないことを確認する。
4. 意図単位でcommitを整理する。
5. 許可範囲内でbranchをpushし、upstreamを設定する。
6. project conventionがあればPRを作る。
7. `git status --short`が空であることを確認する。
8. mergeやbranch削除はauthorization envelopeに含まれる場合だけ実行する。

## Completion Audit

「問題が見つからない」ではなく、各成功条件を証明する。

| Requirement | Required evidence |
| --- | --- |
| 機能 | acceptance testまたは再現可能なmanual scenario |
| 品質 | test、lint、typecheck、build、review結果 |
| 配布 | remote、branch、commit、PRまたは明示した未実施理由 |
| 利用可能性 | setupと動作確認手順 |
| Goal達成 | 成功条件ごとのevidence mapping |

証拠が不足する項目は未完了として扱う。環境制約で検証不能なら、制約と最短の追試手順を残す。

## HTML Handoff

1. [handoff-schema.md](references/handoff-schema.md)に従ってJSONを作る。
2. 次のcommandで単一HTMLを生成する。

```bash
bun "$(agent-skill-path idea-to-ship)/scripts/render-handoff.ts" \
  --input /path/to/handoff.json \
  --output docs/ship-report.html
```

3. browserでHTMLを開き、desktopとmobile幅、console error、全手順を確認する。
4. 概要、意思決定、実装内容、検証証拠、使い方、注意点、Git状態を含める。
5. reportの場所を最終回答でlinkする。

## Stop Conditions

- production credential、課金、法務判断など新しい権限が必要なら止める。
- 同じblockerが3回続き、安全な代替作業も尽きた場合だけblockedとする。
- 時間やcontext都合だけでscopeを縮めない。
- 完了監査とHTML handoffとGit closeoutが終わるまでcompleteにしない。
