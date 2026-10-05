---
title: 開発Harnessと生活Harnessの接続案
created: 2026-09-28
type: research
tags: [harness, life-os, integration]
---

# 開発Harnessと生活Harnessの接続案

日付: 2026-09-28
状態: 調査・提案。既存の承認済み設計を変更しない
対象: harness-core、Olympus、Orca、ccspace、dotfiles、将来の機器adapter

## 結論

開発用と生活用に二つのHarness Coreを作らない。Task Contract、権限判定、Attempt、承認、証拠、成果物参照、実行履歴は共有し、生活固有のTimes、予定、日次レビュー、知識はOlympusが所有する。人間向けの主画面はOlympus、開発中のライブ監督はOrcaとする。利用者からは一つの生活・仕事の入口に見せ、内部では所有者を分ける。

この結論は`harness-core/docs/proposals/platform-architecture.md`の方向に沿う。現行Coreはまだscaffoldであり、この文書は実装済み機能を述べるものではない。

## 既存の生活・秘書系基盤から採るもの

| 基盤 | 確認した強み | この構想への採用 | 足りない境界 |
| --- | --- | --- | --- |
| OpenClaw | 複数channel、mobile node、skill/plugin、agent routing、automationを一つのGatewayで扱う | 入力adapter、能力の段階導入、automation UIの比較対象 | Harness固有のContract、Account Group、署名承認、成果証拠は別途必要 |
| Reclaim | 頻度、長さ、許容時間、優先度から柔軟なcalendar枠を置き直す | `weekly_quota`と時間窓のUX参考 | agentの作業結果と承認の正本にはならない |
| Home Assistant | 時刻、calendar、機器状態など多様なtriggerからdevice actionを起こす | 家電・機器の状態と操作を任せる | 自由な依頼、モデル成果、Workspace ledgerの正本にはしない |
| Omi | 会話とmemoryのimport/readをアプリ連携として公開 | 将来の音声・生活入力adapterの参考 | 現在のTimes正本を移さない |
| Olympus | Times、判断、知識、振り返り、Portal、Inboxの設計と一部実装 | 人間の生活画面と知識正本 | 汎用Workerの権限・実行証拠を重複実装しない |

この比較は各製品の公開機能の確認であり、ローカルへの導入や実環境での互換性試験ではない。特にOpenClaw全体への移行は現行のOrca、ccspace、Olympusを置き換える範囲が大きい。まず必要な接続面と意味論を借り、既存資産の上で一本の通し体験を実装する。

## 日常の通し体験と受入条件

| 入力 | 人間に見える結果 | 契約・境界 | 最初の受入条件 |
| --- | --- | --- | --- |
| Timesに「思いついた」と投稿 | Timesに残り、提案がInboxへ出る | 記録はOlympus。Task化は出典IDつきで提案 | 投稿を再送しても二重Taskにならない |
| 「今夜このアイデアを調べて」 | 軽い依頼カードと成果報告 | OlympusからTaskを起票。HarnessがWorkspaceと予算を選ぶ | セッションを閉じても依頼と結果を追える |
| 「平日朝にニュースを読んで」 | カレンダーの予定と完了報告 | Schedule定義とOccurrenceを一意化。記事・出典をArtifactへ | 週・時刻・timezoneを編集でき、二重実行しない |
| 「毎週1時間で2回確認」 | 週の二つの枠と実績 | 回数目標を持つflexible window。具体時刻は別途配置 | 未配置、予定、実行、見送りを区別できる |
| 「この日時にやって」 | 予定と結果が同じ日付へ表示 | 固定時刻のone-shot。遅延・中止を明示 | 日時とtimezoneの解釈を事前に確認できる |
| 「HTMLで報告して」 | 成果物一覧から安全に閲覧 | HarnessがArtifact metadataを記録。Olympus Portalが表示 | 生成HTMLはOlympusの認証originで直接動かさない |
| 「3Dモデルを作り印刷して」 | 設計、preview、承認、機器状態、完了写真 | device adapterを追加。印刷開始は外部効果として別承認 | 機種と接続方式が確定するまで自動印刷しない |

カレンダーは主導線と1日単位の投影画面にする。ただしすべてを「予定」という一種類のレコードへ押し込まない。Times、Task、会議、反省、Schedule occurrence、Attempt resultは異なる状態遷移を持つ。Day viewはこれらをIDと時間で束ねるread modelであり、元データは各所有者が保持する。

## 所有者とスキーマの最小単位

| 概念 | 正本 | 最小フィールド・意味 |
| --- | --- | --- |
| Workspace | Harness operator/workspace ledger | `id`, `charter`, `account_group`, `allowed_capabilities`, `assurance_floor`, `budget`, `default_profile` |
| Task | Harness workspace ledger | `id`, `workspace_id`, `intent`, `source_ref`, `contract_revision`, `status`, `dedupe_key` |
| Attempt | Harness workspace ledger | `id`, `task_id`, `worker_ref`, `account_group`, `state`, `started_at`, `ended_at`, `evidence_refs` |
| Artifact | Harness metadata + immutable blob/URL | `id`, `task_id`, `attempt_id`, `kind`, `mime`, `digest`, `storage_ref`, `created_at`, `visibility`, `retention`, `review_state` |
| Schedule | 推奨はHarnessのTask trigger定義 | `id`, `workspace_id`, `intent`, `kind`, `timezone`, `rule`, `window`, `policy_revision`, `enabled` |
| Occurrence | Harness ledger | `id`, `schedule_id`, `due_at`, `window_end`, `state`, `task_id?`, `dedupe_key` |
| Calendar event | Google Calendar等の外部正本 | `provider`, `external_id`, `start`, `end`, `timezone`。読み取り参照 |
| Times・Review・Knowledge | Olympus | 既存のULIDと出典参照。Harnessへ原文の重複保存をしない |
| Inbox request | Olympus projection | 元の承認・質問・成果確認への参照と完了条件 |
| Capability | Harness registry | `id`, `version`, `source`, `digest`, `adapter`, `operations`, `required_grants`, `hosts`, `verification_state` |

`Artifact`はファイル一覧ではなく「何の仕事で作られ、どの確認を経て、どこで安全に開けるか」の目録である。HTML以外に文書、画像、モデル、G-code、ログ、PRも同じ参照型で表す。保存先や表示方法はkindに応じる。Orcaの成果報告とOlympusの成果物一覧は同じArtifact IDを参照できる。

## Scheduleの単一所有者を決める

設計上の衝突がある。`harness-core/docs/proposals/platform-architecture.md`はtriggerをWorkspace ledgerが所有し、Orca automationを実行backendとする。一方`olympus/docs/data-model.md`は`schedules/*.md`と`schedule-runs/*.md`を正本とし、SQLite job queueを持つ。`olympus/docs/newplan/00-decisions.md`もOlympusから予約実行する方針を確定している。両方を同時に書き込み正本にすると編集と取消、再起動後のcatch-up、権限変更時の扱いが割れる。

推奨案は次の通り。Olympusが作成・編集UIと生活上の表示を所有する。Harnessがagent作業のSchedule定義、Occurrence、権限snapshot、Task起票、実行結果を所有する。Olympusの既存schedule schemaはUI契約または移行元として扱い、移行時に正本を一つへ切り替える。Orca automation、`croner`、systemd timerは実行backend候補であり正本にはしない。Olympusだけで完結する通知・振り返り生成などの内部jobは引き続きOlympusが所有してよい。これは既存の確定文書の変更を要するため、実装前に両repoでADRが必要。

Scheduleの`kind`は`at`、`interval`、`calendar_rule`、`weekly_quota`を先に想定する。`calendar_rule`はIANA timezoneとRRULE相当の繰返し表現、除外日を保持する。`weekly_quota`は「週2回、各1時間、許容曜日と時間帯」のような目標であり、時刻固定のcronへ無理に変換しない。各Occurrenceには発火予定時刻、実際の開始・終了、遅延理由を分けて記録する。重複防止キーは`(schedule_id, due_at, policy_revision)`を基本に、再実行は新Attemptへつなぐ。未実行時の`skip`/`catch_up`、同時実行の`skip`/`queue`、期限と予算はScheduleごとに明示する。作成時の承認が将来の全実行へ無制限に広がらないよう、許可される操作、Workspace、予算、終了日を固定し、権限を実行時にも再評価する。

## Agent・Workspaceを増やしすぎない運用

Workspaceは常設の責任と権限の境界であり、依頼ごとに作らない。初期は`development`と`personal`を推奨し、会社用は既存Account Groupに従う独立Workspaceを必要時に作る。ニュース収集、予定確認、印刷はまずpersonal内のTask profileまたはcapabilityとして扱う。新Workspaceは別のaccount group、長期の担当責任、別ledgerの共有・削除要件、異なる権限境界がある時だけ作る。

Taskは本人の「マイタスク」とagentの作業を分ける。本人が行うべき行動、agentへの依頼、人間の承認待ち、結果の閲覧待ちは別の`actor`/`intent`/`completion_condition`を持つ。Inboxに出すのは人間の行動が必要なものだけで、agentの細かなsubtaskを大量に並べない。報告はTask単位にまとめ、Attempt履歴へ掘り下げられるようにする。

ccspaceはアカウントやquotaの実行手段とし、どのAccount Groupで実行してよいかはHarness policyで先に決める。quota切れ時は同じgroup内でhandoffし、出典と契約を保持する。groupをまたぐ移動は既存のA3承認条件に従う。

## 新しい能力の発見から利用まで

必要な時にagentが能力候補を調べ、導入を提案し、検証後に登録できる仕組みは追加する価値がある。最初から自己変更可能なtool searchだけを置くと、MCP serverの自己申告と実際の権限が一致する保証がない。発見、導入、実行を別の操作にする。

1. `discover`: 既存capabilityを検索し、足りなければ公式仕様、MCP Registry、device vendorのAPIを調査。候補の出典と代替案を記録
2. `propose`: operations、入力/出力schema、必要な秘密、network先、host、Account Group、外部効果、確認条件をmanifestに記載
3. `stage`: versionとdigestを固定し、隔離環境でread-only probeとfixture evalを行う。未検証状態では本番Taskへ割り当てない
4. `grant`: ownerがWorkspaceと操作単位で許可する。新しいsecret accessや物理動作には既存assurance policyを適用
5. `operate`: Task Contractにcapability versionをpinし、実行時にpolicyとdevice状態を確認。結果をAttemptとArtifactへ戻す
6. `revoke`: grant停止後の新Attemptを拒否し、既存Taskの影響を表示。監査履歴は保持

MCPはtool接続と発見の候補であり、Capabilityの権限正本にはしない。MCP Registryは公開serverを発見する目録であり、安全性の認証機関ではない。`readOnlyHint`等のannotationも自己申告として検証する。device adapterがMCPを提供する場合もHarness側でoperationごとのeffect classを定義する。

3D印刷なら`model.generate`→`model.preview`→`slice`→`gcode.inspect`→`printer.upload`→`printer.start`→`printer.monitor`→`artifact.report`を別operationとする。機種、造形方式、slicer、材料、機器API、設置場所、カメラの有無が分かるまで特定製品を選ばない。外部サービスへのモデル送信と加熱・可動を伴う`printer.start`は承認対象にする。OctoPrintにはファイル選択と印刷開始のAPIがあるが、利用中機器が対応するという意味ではない。

## UIと認証

Olympusの今日画面は`予定`、`自分がやる`、`agentに任せた`、`判断待ち`、`成果`を同じ日付に投影する。上部はTimesの短い入力欄、中央は時間軸、下部は完了した成果と振り返りを想定する。情報がない区画は表示しない。週画面は予約枠とweekly quotaの残数を示す。Orcaはライブ実行、worktree、terminal、handoffを詳しく見る画面として残す。

HTML成果物はOlympusのPortal方針を再利用する。`sandbox`を使う場合はsame-originを許さないiframe、生成siteは別originで配信する。登録時にArtifact ID、タイトル、Task、生成者、digest、公開範囲、期限、表示URLを受け取り、手動`catalog.json`編集とbuildを不要にする。UIの追加・削除は「artifact viewの追加」と「製品機能のdeploy」を分ける。前者は安全な登録操作、後者は通常のコード変更・検証・承認・deploy Taskで扱う。

スマホ/Webの承認は既存提案のPresence Consoleへ集約し、Olympus Inboxからdeep linkする。1Passwordに保存したpasskeyでConsoleのWebAuthn challengeに署名し、Contractや効果のdigestと結びつける。これは1Passwordのvaultを遠隔unlockしたり`op` CLI操作を代理承認したりする仕組みではない。サービス秘密は1Passwordを正本とし、必要な操作だけService Gatewayから短命grantで扱う。対話的なWebサイトのpasskey loginはそのサイトの認証flowで本人が行い、agentは完了後に継続する。CLIで代行可能と仮定しない。

## 導入順

1. Harness Coreの既定P1/MVPを進め、Task、Attempt、approval、artifact参照の基礎を実装
2. OlympusのTimesから軽い依頼をTaskへ起票し、完了報告をInboxとPortalへ戻す一本の縦断flowを作る
3. 予定のread modelとone-shot Scheduleを作る。既存Olympus schedule設計とのADRと移行方針を先に決める
4. `calendar_rule`と`weekly_quota`、権限期限、重複・遅延の意味論を追加
5. Capability registryと最初の実機adapterを一種類だけ検証する。印刷機種が決まれば3D印刷を候補にする
6. Presence ConsoleとService Gatewayを既存のHarness計画に合わせて接続する

最初の縦断flowの受入条件: Timesから依頼→Workspace決定→実行→HTML成果物登録→Olympusで閲覧→日次レビューに出典つき反映、を一つのTask IDで辿れること。失敗と承認待ちも同じ画面で追えること。ここでは自動Workspace生成や汎用plugin storeを作らない。

## 決める必要があること

- 最初の縦断flowを「調査レポート」または「ニュース定期要約」のどちらにするか
- 「週1で1時間2回」は週2回の計2時間か、週1回を1時間単位で2回確認する意味か
- 3Dプリンターの機種、接続方式、物理的な安全確認の方法
- 成果物の既定保持期間と会社Workspaceからpersonal画面へ出してよいmetadataの範囲
- Google Calendarを読み取りだけに保つか、将来agentの予定を同Calendarへ書き戻すか
- OlympusのscheduleをHarnessへ移すADRの承認

## 2026-09-29の追加要件: Jev、週次予算、Playground

RDPはOvershellからの実接続成功を本人が確認した。生活Harnessには、バイトのシフト、Timesに記録したその日の意図、会議、週次の残作業を合わせて「今日は何を実行し、何を待つか」を判断する機能を加える。

Jevは意図・緊急度・所要時間帯・実行profileの候補を`choice`、`score`、`noul`で分類する。Jevの出力は提案とconfidenceとして記録し、ScheduleやWorkspace policyを直接変更する権限にはしない。確定済みのシフトなどはルールで処理し、曖昧なTimesだけ分類する。Jev自身のAPI responseが返すtoken usageはJev呼び出しの計測であり、CodexやClaudeなど全runtimeの消費量を表さない。後者は各runtimeとccspaceの観測値を別に集める。

内部予算はAccount Groupごとに`BudgetPolicy`を持ち、`provider`、`window`、`limit`、`reserve`、`reset_at`、`source`、`freshness`、`workspace_shares`を記録する。`window`はsessionとweeklyを少なくとも区別する。残量の判定と停止は決定的なpolicy engineで行い、Jevには「実行候補の優先度」「待てるか」の分類だけを任せる。未知または古いusage値なら新しい高消費Attemptは保留し、推測した残量で起動しない。hard limitに達したTaskは`waiting_budget`としてQueueに残し、最も早い信頼できる`reset_at`または次の観測時刻に再評価する。待機中も期限・優先度・人間の判断待ちを表示する。別Account Groupへ自動越境しない。weekly quotaと内部予算の両方を満たすOccurrenceだけ起票する。

Life OSのメインUIは今日の予定、次の判断、進行中の仕事、成果だけを表示する。常設の機能別ボタンを増やす前に、生成されたページやwidgetを隔離された`Playground`に置く。`pin`はメインからそのページへの短い導線であり、ページそのものをメインUIへ組み込む操作ではない。今日のイベントに関係するページはagentが一時pinでき、期限で自動解除する。本人が選んだpinは明示的に解除するまで残す。一時イベント用のページは有効期限を持ち、期限後は成果物として閲覧可能な状態に下げる。利用頻度、再訪、滞在、完了率、手動pin、誤操作、生成・維持コストなどを使って昇格候補を提案する。使用率だけで自動昇格させると偶然のイベントやbot自身のアクセスで画面が増えるため、本人の利用とagent内部アクセスを分離する。十分な継続利用と本人の確認があったものだけメインUIへ追加する。不要になれば降格案を出し、履歴と成果物は保持する。

[Grok Botの設計記事](https://x.ai/news/designing-grok-bot)ではBot、Chat、Prompt、Tool、Artifactに表面概念を絞り、状態と詳細を段階表示し、Routineと成果を会話に混ぜている。参考になるのはこの情報階層と、Bot数を増やすより委任と結果を見せる判断。Playgroundの自動昇格や予算管理の仕様まで同記事が保証するわけではない。

## 2026-10-02の追加要件: Orca実行host間のaccount profile同期

agentの実行とsession管理は各hostのOrcaが担当する。homelabのOrca managed accountとAccount Groupを正本とし、MacやOrca管理のCloud workerに同じaccountを事前配置する。Orcaのterminalで`cx`/`cl`を起動する場合は、その起動前に同期を確認する。homelabへ接続できない時は前回同期済みのaccountを使う。新規accountがまだないhostでは利用不可とする。Orcaのworktree、session DB、terminalを複製する要件ではない。

起動方法で必要条件が変わる。Orca terminal内の`cx`/`cl`で実行する場合はccspaceのspace/launcherとその認証homeがlocalにあればよく、Orcaはterminalとsessionを管理できる。一方、Orcaのagent pickerや`orchestration worker-start --agent codex`でaccountを選ぶ場合は、Orcaが認識するmanaged account登録も必要。`ccspace-sync-orca`は現在macOSのlocal Orca一覧からccspace launcherを作るだけで、macOSでしか導入されない。`ccspace sync`もlocal shimを再生成するだけ。`ccspace-pick`はlocal Orca一覧を優先する。したがってまずOrca terminalからの`cx`/`cl`経路でprofile同期を検証し、native pickerと自動worker経路は別に接続する。

Orca公開CLIで確認できるmanaged account操作は`account list`と`account add`のみ。`account add`は対象hostで`claude login`または`codex login`を実行してから登録する。別hostのOrca managed accountを非対話でimportする公開操作は確認できない。Orcaの内部DBや認証directoryを稼働中に直接コピーして登録済みと見なす実装にはしない。native pickerと`--agent`経路まで同期するにはOrca側に検証可能なimport APIを追加・確認するか、現行Orcaが認識する安全な登録経路を実機で特定する。認証fileだけについてはCodex公式にheadless hostへのコピー手順があるが、それはOrcaへのmanaged account登録を意味しない。ClaudeはmacOS Keychainと`.credentials.json`の差もある。

最初の実装境界は`sync inventory → ensure local ccspace profile → verify identity/group → launch cx/cl in Orca terminal`。Cloud workerではworkspace作成後、agent起動前に同じpreflightを行う。対象groupのprofileがなければ同期を試み、成功とaccount identity確認ができるまでAttemptを開始しない。Orcaの`worker-start --agent`は既知のagent IDしか取らないため、ccspace profileを選んで起動できるかは別途検証が必要。既存terminal handleを渡す`--terminal`経路も候補。Cloudでのprofile保存とhomelabへの到達性はrecipe/hostごとに検証する。

homelabとの接続断でも、local Orcaに配置済みの認証が有効でmodel providerへ通信できれば直接のagent実行は可能。Harness管理の新Attemptは現行設計ではControl Host不在時に止まるため、これも継続するなら別途offline委任と予算予約を設計する。完全な圏外ではcloud modelを呼べない。

参照: [Orca CLI account操作](https://www.onorca.dev/docs/cli/reference)、[Orca managed account](https://www.onorca.dev/docs/agents/codex)、[Orca Cloud VM](https://www.onorca.dev/docs/ways-to-run)、[OpenAI Docs: Codex authentication](https://learn.chatgpt.com/docs/auth)、[Claude Code authentication](https://code.claude.com/docs/en/authentication)。2026-10-02に公式文書とlocal CLI helpを確認。Orca managed accountのhost間importは未実装・未検証。

## 根拠

ローカル: `harness-core/docs/architecture.md`、`harness-core/docs/proposals/platform-architecture.md`、`harness-core/docs/progress.md`、`olympus/docs/newplan/00-decisions.md`、`olympus/docs/data-model.md`、`olympus/docs/portal.md`、`dotfiles/docs/research/life-os-architecture-2026-09-09.md`。2026-09-28に文書を確認。実装・実稼働は別途検証が必要。

公開一次資料:

- [OpenClaw Automation schedules](https://docs.openclaw.ai/automation/cron-jobs/schedules)、[Manage automations](https://docs.openclaw.ai/automation/cron-jobs/managing-jobs): 時刻指定、間隔、cron、timezone、未実行時の扱いの比較
- [OpenClaw features](https://docs.openclaw.ai/concepts/features)、[skills](https://docs.openclaw.ai/skills): 多入口、mobile node、skillとpluginの役割
- [Reclaim scheduling](https://help.reclaim.ai/en/articles/6207587-how-reclaim-manages-your-schedule-automatically): 頻度、長さ、時間窓を使う柔軟な配置
- [Home Assistant automation triggers](https://www.home-assistant.io/docs/automation/trigger)、[calendar integration](https://www.home-assistant.io/integrations/calendar): 機器と予定を起点とする動作
- [Omi Import Apps](https://docs.omi.me/docs/developer/apps/Import): 会話とmemoryの連携境界
- [Google Calendar recurrence](https://developers.google.com/workspace/calendar/api/concepts/events-calendars)、[extended properties](https://developers.google.com/workspace/calendar/api/guides/extended-properties): 外部予定の表現とmetadata境界
- [Official MCP Registry](https://registry.modelcontextprotocol.io/docs)、[MCP tool annotations](https://blog.modelcontextprotocol.io/posts/2026-03-16-tool-annotations/): 発見と権限検証の区別
- [OctoPrint job operations](https://docs.octoprint.org/en/main/api/job.html): 物理印刷の開始と監視に必要な操作例
- [1Password passkeys](https://support.1password.com/save-use-passkeys/)、[1Password CLI secrets](https://developer.1password.com/docs/cli/secrets-scripts): 人間のWebAuthn認証とservice secret利用の区別
- [System One API](https://docs.system-one.dev/en/docs/api): Jevの型付き判断とJev自身のusage field
- [Grok Bot design](https://x.ai/news/designing-grok-bot): 永続Bot、Routine、Artifact、段階表示のUI判断
