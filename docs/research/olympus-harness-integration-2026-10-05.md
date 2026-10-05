---
title: OlympusとHarnessの接続とUI改修調査
created: 2026-10-05
type: research
tags: [olympus, harness, integration, ui]
---

# 調査範囲

Olympus main `acf0bc8`とHarness Core main `4dd4beb`の実装を確認した。Olympusのローカルcheckoutには別作業の未commit変更があるためGitHub mainのコードを調査の基準にした。画面のブラウザ確認や実Core接続や本番データ操作は行っていない。以下のUI評価はコードからの推論であり表示品質の実測ではない。

# 現在の接続

- gatewayのHarnessMonitorはCoreのoperator event streamを購読する
- replay終了markerのhead一致を確認しcursorから再接続する
- `/api/harness/status`と`/harness`は閲覧専用
- 承認待ちはoperationとrequest IDと期限のみを保持する
- viewはin-memoryで再構築できる。実行状態の正本ではない
- 致命的な購読失敗からの復帰はgateway再起動に依存する
- 実CoreとTailscale経由の接続は未検証

参照: [Harness status仕様](https://github.com/r1cA18/olympus/blob/acf0bc8/docs/harness-status.md)と[monitor](https://github.com/r1cA18/olympus/blob/acf0bc8/apps/gateway/src/harness/monitor.ts)と[view](https://github.com/r1cA18/olympus/blob/acf0bc8/apps/gateway/src/harness/view.ts)。

# 接続候補と不足

| 接続先                    | 再利用できる実装                             | 追加するもの                                                       |
| ------------------------- | -------------------------------------------- | ------------------------------------------------------------------ |
| Timesから仕事を依頼       | 投稿IDとTask候補と承認receipt                | source IDからCore Contractへの参照と冪等な受付                     |
| Inboxに人間の判断を集める | candidate承認とsnoozeとWeb Push              | request IDで一意化したCore承認投影と完了条件                       |
| Todayに進行状況を表示     | DashboardのTaskとCalendarとInbox             | 実行中・判断待ち・結果不明・予算待ち・成果確認待ちのTask単位カード |
| Calendar/Week             | Taskの週表示と予定参照                       | Schedule occurrenceと実績の投影。会議とagent実行を区別             |
| Portalで成果を開く        | 公開ページcatalog                            | Artifact IDとdigestとsource Task。生成HTMLの別origin表示           |
| Knowledgeへ経験を返す     | 知識の検索と保存                             | Evidence/findingから出典付きobservationへ変換するadapter           |
| Workspaceを選択           | CoreのWorkspace/group/environment/budget API | Olympusには必要な境界情報だけ表示。管理操作は別画面                |

CoreのOpenAPIにはTask/Attempt操作が載っているがHTTP transportは未実装の項目が多い。`x-harness-service-status: implemented`だけで呼び出し可能と判定しない。`x-harness-transport-status`を必ず確認する。Contract一覧とAttempt取得はservice実装済みでもHTTPはplannedである。OlympusからTaskの一覧・詳細を表示する前にCoreの読み取りHTTP projectionを追加する必要がある。

参照: [Core OpenAPI](https://github.com/r1cA18/harness-core/blob/4dd4beb/openapi/harness.v1.yaml)。

# 先に解決する設計差分

## 完了駆動Inbox

`listInboxNotifications`は一般通知を`!read`で選びTask候補だけfeedback未確定なら既読でも残す。文書の一般化されたintent_status駆動とは一致していない。Core承認通知を既読にしただけで消してはいけない。

提案はreadを閲覧状態として維持しcompletionを別に持つこと。Coreが承認を消費した時点を目的完了の根拠にする。単なる署名提出と実際の操作完了は区別する。却下・期限切れ・dismissも独立した理由を残す。同期処理は通知とPushをrequest IDで重複防止する。署名は当面CLIへ引き継ぐ。

参照: [notification route](https://github.com/r1cA18/olympus/blob/acf0bc8/apps/gateway/src/routes/notifications.ts)。

## Scheduleの正本

Olympus Schedule CRUDは存在するが`driver_available: false`を返す。既存画面の次回日時は実行保証ではない。Coreのtrigger計画とOlympusのschedule vaultを同時に書き込み正本にしない。

agent作業のscheduleとoccurrenceはCore所有とする案を両repoのADRで確定してから接続する。Olympus内部の通知や振り返りjobはOlympus所有を維持する。実行不可のUIでは「停止中」と「実行機能未接続」を分ける。

参照: [Schedule route](https://github.com/r1cA18/olympus/blob/acf0bc8/apps/gateway/src/routes/schedules.ts)。

## Knowledge入力

GitHub mainには`olympus_post_observation`がない。ローカル未commitのtoolsとvaultには追加途中の実装がある。mainに利用可能な機能として扱わない。別作業のschema変更を整理してから既存scopeとatomic mutationに適合させる。解決後に検証が通った事実だけで変更が解決原因だったと断定せずcandidate observationとして残す。

## 方針文書

ローカルAGENTSのpassive/task-first記述とCLAUDEのLLM/session driver記述には方向の差が残る。Core接続の所有境界を正本にまとめて重複記述を更新する。driverを再実装してCoreと二重のsession ownerにしない。

# UI改修案

1. Todayの上段に「判断が必要」「進行中」「確認できる成果」を配置。イベント件数は管理画面に下げる
2. Inboxは「承認」「確認」「自分の行動」に分類。各cardに次の操作と期限と未完了理由を表示
3. Task drawerにCore Task参照と最新Attempt状態と検証対象commitと成果リンクを追加。unknownは成功扱いしない
4. `/harness`を詳細な運用画面として維持。イベント名中心の表示をWorkspaceとTaskの説明に変える
5. 主navigationはToday・Times・Tasks・Inbox・Knowledgeを中心にする。環境とaccountと予算はSettings/運用へまとめる
6. 固定のRecentsと未接続のheatmapを実データへ接続するか非表示にする。未実装phase名を日常UIの説明に出さない
7. Portalは学習ページと作業成果の種別を分ける。成果の公開状態とreview状態を表示する
8. mobileでは入力と判断を少ない操作で完了できる導線を優先。既存drawerとsafe-area対応を再利用する

参照: [Dashboard](https://github.com/r1cA18/olympus/blob/acf0bc8/apps/web/src/routes/dashboard.tsx)と[Sidebar](https://github.com/r1cA18/olympus/blob/acf0bc8/apps/web/src/components/sidebar.tsx)と[Harness UI](https://github.com/r1cA18/olympus/blob/acf0bc8/apps/web/src/routes/harness.tsx)。

# 実装順と受入条件

| 順  | 成果                        | 受入条件                                                              |
| --- | --------------------------- | --------------------------------------------------------------------- |
| 1   | Core接続の実機確認          | Mac停止中もhomelabの購読が継続し再接続で欠落を検知できる              |
| 2   | Core読み取りHTTP projection | planned metadataをimplementedへ変更し最新契約をclientへ取り込む       |
| 3   | Inbox承認投影               | 既読でもpendingを保持。消費・却下・期限切れを区別。再送で二重通知なし |
| 4   | TodayとTask詳細             | Task単位で結果と次の人間行動を表示。stale/unknownを明示               |
| 5   | 成果とKnowledge             | source IDとdigestを追跡可能。HTMLを認証originで直接実行しない         |
| 6   | Schedule統合                | 単一正本とtimezoneと取消とcatch-upをADRで確定してから実行を接続       |

既存[Olympus #2](https://github.com/r1cA18/olympus/issues/2)と[Core #27](https://github.com/r1cA18/harness-core/issues/27)を全体の追跡先として利用する。今回UIコードと本番設定は変更しない。
