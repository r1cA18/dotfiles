---
title: Harness workflow and device handoff alignment
created: 2026-10-18
type: research
tags: [harness, runtime, handoff, accounts]
---

# 日常の操作と責務

所有者が2026-10-18に示した使い方を今後の受け入れ条件とする。
この文書の操作例は設計案。現在使えるcommandは実装ガイドに区別して記載する。

普段はクライアントPCのdshから作業する。重い並列作業や移動中も続けたい作業は既存のクラウドworkerへ渡す。Mac固有の作業はMacで実行する。実行先としてMacをhomelabの下位に固定しない。

| 層                  | 所有するもの                                                      |
| ------------------- | ----------------------------------------------------------------- |
| Core                | Task・Attempt・担当・権限・予算・停止確認・引き継ぎ記録・完了判定 |
| Runtime adapter     | dsh・Claude Code・Codexの起動と再接続能力の申告                   |
| Model profile       | modelの選択とconnection・billingへの参照                          |
| Account Group       | 使用可能なaccountとデータ利用の境界                               |
| Environment adapter | hostの能力と作業配置・起動・停止・復元                            |
| Orca                | hostごとの開発terminalとsessionへの接続・表示                     |
| Console             | 共通APIを使う一覧・編集・移動先の選択                             |
| dsh plugin / MCP    | 同じCore操作を呼ぶ入口                                            |

OSとarchitectureは実行先の制約。Xcode・実機・GPU・localhost確認・空き資源も判定材料にする。負荷の測定値には取得時刻と有効期間が必要。最初は利用者による明示選択を通し自動routingはその試験後に追加する。

# 操作を分ける

| 操作     | 意味                                  | TaskとAttempt              |
| -------- | ------------------------------------- | -------------------------- |
| 再接続   | 同じhostで動く同じ実行へ戻る          | 同じAttempt                |
| 引き継ぎ | 作業を保存して別hostや別runtimeで継続 | 同じTaskに後続Attempt      |
| 分岐     | 元の作業を維持して並行する仕事を作る  | 元Taskへの参照を持つ別Task |

ローカル→クラウド・クラウド→ローカル・ローカル→ローカルに同じ引き継ぎ手順を使う。物理hostが同じでもruntimeやgroupを替える場合は引き継ぎになる。分岐したworkerに同じ公開権限を暗黙で渡さない。

指定を省略した場合はruntime・model profile・groupを維持する。指定先が未対応なら停止し別modelや別groupへ黙ってfallbackしない。`runtime`と`model profile`は別の指定とする。profile変更時もそのgroupで利用できるconnectionだけを解決する。

想定する文法は例えば`/harness handoff --host <host> --runtime <runtime> --profile <profile> --group <group>`。現在このslash commandは未実装。すべて省略可能という意味ではなく移動先と現在のbindingを表示してから実行する。groupの変更はaccountだけでなくデータの送信先も変えるため既存の権限との照合が必要。

# 引き継ぎの成立条件

1. 移動先のcapability・account・group・予算を検証
2. 元の実行の新規副作用を止めて停止結果を記録
3. 未commit差分と必要な未追跡ファイルと入力assetを含むsnapshotを保存
4. 移動先で復元してhashと構築条件を照合
5. 担当の世代を進めて後続Attemptを開始
6. Orcaから移動先のterminalを開く

複数repoとrepoなし作業も保存形式の対象。会話の要約・決定・未解決事項・成果物への参照をruntime内部session IDと分けて保存する。native resumeは同じruntimeの対応能力がある場合に使う。別runtimeではそのままの内部session再現を約束しない。

停止確認ができない場合はOutcomeUnknownとして扱う。旧workerが復帰しても古い担当世代でpushや外部送信を許可しない仕組みが必要。credentialを持つworkerへ直接公開を任せたままではこの保証は成立しない。

現在のCoreではexecution plan変更はContractのdigest変更になる。将来の引き継ぎで再承認をどこまで省略できるかは承認済みの許可範囲として別途設計する。今回の改善ループはこの制約を緩和しない。

# Accountをメインサーバーで管理する意味

accountの登録情報・group・profile・利用可能なmodel・budgetを中央で管理する。各端末は秘密を含まないprofileと端末固有のbindingを分ける。

| 利用経路   | 端末が使うもの                               | 現在の制約                                        |
| ---------- | -------------------------------------------- | ------------------------------------------------- |
| Gateway    | 許可されたmodel APIへの接続                  | 接続契約とbillingと対応protocolの検証が必要       |
| Native CLI | 実行hostの専用account home                   | 中央catalogへの登録だけではログイン済みにならない |
| Remote実行 | サーバー上のnative accountと実行結果への接続 | クライアントへのcredential複製を要しない          |

ClaudeやCodexのsubscriptionをdshから任意に利用できるとは扱わない。検証済みgateway経路がないprofileはresolverで拒否する。native login情報の自動コピーは今回実装しない。中央管理の配備はsecretを公開dotfilesへ含めず既存のprivate運用層へ置く。

サーバーを失っても復旧できるようoperator ledger・承認・budget hold・復元に必要なsecret参照も保護する。Gitの設定ファイルだけでは実行状態の復旧には足りない。

# 確認できた拡張点

- Orca1.4.219の`terminal create --help`に`--environment`と`--pairing-code`がある
- 同CLIはremote runtimeへ接続してterminalを作る操作を持つ
- これだけでは任意のSSH processがOrcaへ自動登録されるとは確認できない
- dsh固定sourceのHuman Commandsにはplugin所有のcommand registryと生の引数とcancel signalがある
- command handlerはmodelへのmessageを挟まず直接呼ばれる

dsh調査対象は配置PRの固定source。参照は[Human Commands](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/docs/subsystems/commands.md)。Orcaでremote terminalを実際に作る操作と端末間引き継ぎは未検証。今回の調査で新規terminalやagentは起動していない。

# 実装順と受け入れ試験

1. 単一hostでContract→group/account→budget→intent→実行→結果を接続
2. 未commit作業のsnapshotと復元と停止確認を接続
3. dsh command・MCP・Consoleを同じserviceへ接続
4. local/cloud両方向と同一hostのruntime変更を試験
5. 切断中の旧worker復帰と二重公開拒否と別hostへの災害復旧を試験
6. 測定したcapabilityと負荷による自動割り振りを追加

Consoleの一覧・編集要件は維持する。UI libraryの選定とConsole実装はこのruntime PRの範囲外。今回の改善ループは最初の単一hostの実験機能であり上記すべての完成を意味しない。
