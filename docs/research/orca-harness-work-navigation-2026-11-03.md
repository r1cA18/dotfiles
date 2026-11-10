---
title: "個人版Orcaの仕事中心ナビゲーションとHarness Console"
created: 2026-11-03
type: research
tags: [orca, harness, navigation, sessions, architecture]
---

# 個人版Orcaの仕事中心ナビゲーションとHarness Console

## 目的と確認範囲

Projectの手動登録を開始条件にせず、普段のCLIから始めた作業をOrcaへ表示する。
初期表示は確認待ちを優先した仕事一覧とし、最近のsessionや実行machineからも同じ仕事へ到達できるようにする。
Orca内にHarness Consoleを置く。Coreの実行管理とOlympusの生活アプリの責務は維持する。

この文書は提案であり実装済みの説明ではない。個人版Orcaの基点
`9537a72a096a054e100358cc4d1f8dce38b0cb9e`のsourceとCoreの設計・API文書を確認した。
稼働中のアプリは操作していない。描画・外部terminal取り込み・remote接続の実機試験は行っていない。

## 既存コードで使えるもの

| 現状 | 根拠と限界 |
| --- | --- |
| Agentsサイドバー | `SidebarAgentsList.tsx`が既存Activity一覧を利用する |
| 状態別グループ | `agents-view-thread-filters.ts`で初期値は`status`。project・worktree・agentでも分類可能 |
| 状態の優先順 | `activity-thread-grouping.ts`はwaiting等を先に並べる。doneはworkingより後で順番は固定 |
| 最近の活動順 | `activity-thread-builder.ts`が`latestTimestamp`で整列する。独立した永続session一覧とは異なる |
| workspaceの表示設定 | 状態別・Project別・グループなしとrecent・manual・Agent Activity順がある |
| 既存folderのCLI登録 | `orca repo add --path <path> --kind git\|folder`を実装。毎回UIを通す必要はない |
| hostによる絞り込み | Agentsのselectorが`agentsVisibleHostIds`を使用する。host階層のsession一覧は追加対象 |
| Coreの実行API | Contract・Attemptの読み取りと署名付きstart/poll/stopの実装がある |

現行Agentsの行は`paneKey`を中心にしている。閉じたpaneの保持と履歴からの再開を
仕事・session単位で整理する必要がある。存在するstate表示やselectorを再利用し、別の状態判定を増やさない。

## 推奨する体験

### 起動した場所が自動で一覧に現れる

任意の既存directoryで`cx`・`cl`・DSHの共通launcherを実行すると、
選択されたaccount/runtimeと開始時のcwdを使って作業場所を登録する。
通常起動では新しいdirectoryやworktreeを作らない。隔離した作業場所の作成は明示操作にする。

Git配下では起動cwdと実際のworktree rootを分けて記録する。
Gitのないfolderも登録できる。hostと正規化された配置先を識別に使い、同じbasenameや
remote URLの一致だけで別clone・worktree・machineをまとめない。
同じ場所で2つのagentを開いた場合は作業場所を共有しsessionは区別する。

段階的な対応範囲を明記する。

| 入口 | 取り込み方 |
| --- | --- |
| 共通launcherから起動 | 起動受付から終了まで明示的なイベントを発行する最初の対応経路 |
| Orca内のnative chat/terminal | 既存のpaneとagent状態から投影 |
| wrapperを通さないCLI起動 | 対応runtimeのhookで検出する追加経路 |
| 保存済みの過去session | Historyから発見。live実行や制御可能性を推定しない |

登録のためだけにOrcaのUIを起動必須にしない。未接続なら再照合できる記録を保持する。
外部terminalの既存PTYをOrcaへそのまま移せるとは扱わない。
一覧表示・履歴参照・同一sessionのresume・live terminalへの接続は別々の能力として判定する。

自動発見は表示用の登録であり信頼付与やsetup script実行ではない。
folderやprojectを一覧から隠す操作は元directoryや実行processを削除しない。

### 日常のサイドバー

初期viewは「仕事」。既存Projectsは日常の主ナビゲーションから外し、場所の管理と検索条件へ残す。

```text
表示: 仕事 / 最近 / マシン
対象: すべての許可されたgroup・host

確認待ち
  返信が必要な作業
  承認が必要な操作
  完了・未確認の成果
  対処が必要な失敗

動作中
  タイトル / runtime / host / 作業場所

未着手
  まだ開始していない依頼

履歴
  確認済みの完了 / 停止したsession

Harness Console
```

完了と返信待ちは同じ上段に置き理由を区別する。上段内も含めてグループ順を変更できる。
各グループ内は更新順・手動順を選べる。選択中やドラッグ中の行がイベントで移動しないようにする。
確認済みの完了は履歴へ送る。新しい応答・成果のrevisionが届いたら再び未確認にする。
閲覧済みや「確認済み」はUI上の状態でありCoreの承認・成果検証完了には変換しない。

「未着手」は受理済みでまだ起動していない依頼に限る。
idleなterminalや止まったagentを未着手と判定しない。
切断中は接続状態と最終観測時刻を表示する。停止確認不能や結果不明を完了へ落とさない。
成果の状態と通信状態を別に保持し、判断が必要な不明状態は上段に残す。

### 仕事とsessionと場所

| 対象 | 使い方 |
| --- | --- |
| Core Task | Core管理の仕事の安定したID。複数Attemptを同じ仕事の下に表示 |
| native session | Core外で開始した会話。Task登録を強制せず一覧へ表示 |
| 作業場所 | repo・worktree・folder。Gitなしや複数repoにも対応できる参照 |
| host/environment | どこで実行しているか。Profileやaccountとは別 |
| pane/tab | 現在表示するための参照。仕事の永続IDにしない |

一覧用の投影はCoreとOrca/runtimeから作る。独立した実行state machineは作らない。
Core管理の行はCoreのlifecycleと検証結果を使う。native sessionだけの行は
「応答が完了」など実際に観測した範囲を表示し、Task全体の検証済みを意味させない。
Core Taskとsessionの対応が明示的に判明したときだけ同じ仕事へ関連付ける。

「最近」は最近開いたsessionから再開するview。
「マシン」はlocal・homelab・cloud hostの下に実在するVM/container等のenvironmentと
作業場所・sessionを表示するview。存在しない階層は作らない。
どのviewから開いても同じ仕事/sessionに到達し、複製して実行しない。
表示scopeの変更で実行中のaccountや配置先を変更しない。

## Harness Consoleの責務

サイドバーを日常の一覧として使い、Consoleは詳細の確認と操作をする固定tabにする。

| 面 | 担当する情報・操作 |
| --- | --- |
| Overview | 確認待ち・実行中・未着手と直近の成果 |
| 仕事の詳細 | 依頼・Attempt・session・差分・検証・使用量・引き継ぎ記録への参照 |
| 実行環境 | 接続状態と実行中の仕事。実装済みの停止・再接続能力を表示 |
| 接続 | group・account・model・runtimeと利用可能な経路 |
| Skills/Plugins | catalogと今回の選択と固定した版とservice connection |

ConsoleはCoreとruntimeを使うclientにする。providerの認証処理や実行authorityをOrca内へ増やさない。
実行・停止・承認は既存の認可と署名を通し、未対応操作は利用可能なボタンとして表示しない。
現行Coreのwriteはtrusted Unix ingressを要求するため、最初のOrca統合は
main processの限定したIPC bridgeを候補とする。rendererへ署名鍵や任意shell実行を渡さない。

表示modelとAPI clientをOrca固有処理から分け、将来Olympusや独立browserでも再利用できる構成を目指す。
独立browserからの操作には認証・caller scope・配信方式の追加設計が必要。
単純なWebページ埋め込みだけで既存のUnix ingressへ接続できるとは扱わない。
最初から別deploy必須のWebアプリを作る必要はない。

## 上流更新と実装順

内部のProject/Repo/worktree保存形式は当面維持する。
変更を起動時登録adapter・既存一覧の投影と表示設定・Console clientへ分ける。
DB schemaやterminal engineを広く書き換えるより上流差分を抑えられるが、無競合を保証するものではない。

| 段階 | 変更 | 完了条件 |
| --- | --- | --- |
| 1 | Agents一覧を日常の入口にして状態順と確認済み表示を調整 | 完了・返信待ちが上。確認後は履歴。順番の保存と既存表示への復帰が可能 |
| 2 | 共通launcherから既存folderを自動登録 | GUI登録とmkdirなしで開始可能。同時起動や再送でも重複登録しない |
| 3 | Task/session参照と最近・host viewを接続 | paneを閉じても履歴を識別。同名folderや複数hostを混同しない |
| 4 | ConsoleにCoreの読み取りを接続 | 仕事の状態・承認待ち・検証結果を根拠付きで表示 |
| 5 | 既存の署名付き操作とassets選択を接続 | 同じ承認・停止確認・再送契約をUIから利用できる |

初回の改修は段階1と2を優先する。DSHの通常起動環境の恒久化も同じ日常利用の改善として扱う。
稼働中のOrcaや他のagentを終了する必要はない。実装と隔離試験は別checkout/profileで行い、
署名した更新版への切り替えだけを既存作業の完了後に行う。

## 関連記録

- [このMacでの切り替え](../guides/personal-harness-migration.md)
- [DSHと個人版Orcaの進捗](dsh-orca-integration-progress-2026-11-03.md)
- [HarnessとOlympusのコンセプト監査](harness-lifeos-audit-2026-11-02.md)
- [Coreの後続実装記録](harness-implementation-progress-2026-10-02.md)
