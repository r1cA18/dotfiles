---
title: dshを主runtimeにするための認証とセッション境界
created: 2026-10-15
type: research
tags: [harness, dsh, runtime, session, authentication]
---

# 判定と確認範囲

dshはDeepSeek Harnessと解釈した。主runtimeとして採用する方向は既存の製品非依存Coreと整合する。ただしモデルへの接続とcoding agentの実行を別契約にする。認証sessionと作業sessionも分ける。dshへ全製品の内部履歴を変換して集約する構成にはしない。

2026-10-15に一次資料とsourceを確認。dsh mainは571902028a75c64c1d767f4ae5fd099485f0ddf0。root packageは0.2.1-alpha.3。第三者のdsh-plugin-subscriptionsは9930c5ee5e3fa239db9031f47a0f6f30f7ffc443でpackage versionは0.9.9。Core mainは4dd4beb。ローカルPATHにdshはなかった。installやloginやnative agent起動や課金を伴う推論はしていない。動作とquota消費は未検証。

# 2種類の接続

| 構成 | 実装とtool実行のloop | 会話の正本 | 現在の根拠と制限 |
| --- | --- | --- | --- |
| dsh → LLM adapter → model | dsh | dsh Session | providerとtoolsをpluginで交換可能 |
| dsh → native Codex / Claude Code | 各native agent | native側。親dshは委譲結果を保持 | 公式subagent bundleはfresh processで1回のみ。resumeなし |
| Core → native agent | 各native agent | native側 | dshを経由せず同じ外側の実行契約へ接続する代替 |

第三者subscription pluginは1行目にあたる。Codexの実装loopを借りるものではない。Codex adapterはCodex CLIのclient IDとChatGPT backend Responses endpointを使い独自にstreamを変換する。Claude adapterはnative credentialのimportまたはOAuthから直接Messagesを呼ぶ。ネイティブ製品を起動する公式subagent bundleとは独立した実装。

公式native Codex bundleはapp-serverでephemeral threadを1つ開始する。Claude Code bundleは公式SDK queryで非永続のproduct sessionを1つ開始する。両者ともfollow-upとresumeとpoolingを提供せず最終回答か安全な失敗診断を返す。native tool trafficとdiffは親の会話へそのまま取り込まれない。これは機能調査でありCodexの単一agent方針を変更する提案ではない。

- [dsh architecture](https://github.com/deepseek-ai/deepseek-harness/blob/571902028a75c64c1d767f4ae5fd099485f0ddf0/docs/architecture.md)
- [公式Codex bundle](https://github.com/deepseek-ai/deepseek-harness/blob/571902028a75c64c1d767f4ae5fd099485f0ddf0/packages/subagent/subagent-codex/README.md)
- [公式Claude Code bundle](https://github.com/deepseek-ai/deepseek-harness/blob/571902028a75c64c1d767f4ae5fd099485f0ddf0/packages/subagent/subagent-claude-code/README.md)
- [第三者subscription plugin](https://github.com/V1ki/dsh-plugin-subscriptions/tree/9930c5ee5e3fa239db9031f47a0f6f30f7ffc443)

# サブスク認証の扱い

OpenAIはSign in with ChatGPTのChatGPT plan usageを公開している。OSSとlocally hosted app向けに認可されたOAuth tokenでeligible Responses requestsを利用できる。self-hosted VMとlaptopのhost IDは区別し共有clientでも利用枠は独立に増えない。paid/remotely hosted appは別の案内対象。preview制約があり通常のAPI key routeと完全互換ではない。

公式app-server接続例はアプリ自身のOAuth tokenをResponses providerへ渡す。token更新後の再起動とthread/resumeも説明されている。モデル一覧の表示はentitlementの証明ではなく完了した推論で確認する。既存Codex tokenの抽出を前提にせず公式flowとの適合をadapterごとに確認する。調査した第三者pluginがこの公式OSS flowと同じとは判定しない。

AnthropicのHelp Centerは10月7日更新としてAgent SDKとclaude -pとthird-party appのsubscription limits利用継続を案内する。一方Claude Codeのlegal docsはthird-party app自身によるClaude.ai loginとcredential/session tokenの収集・中継を制限し利用者自身のunmodified Claude Codeへのloginを区別する。したがってSDK利用の案内を独自OAuth adapter全般の許可と読み替えない。dshからClaude Codeを公式SDK経由で利用する経路とcredential importで直接推論する経路を別に評価する。公式文書の適用条件には確認が必要な部分が残る。

共通で記録するのはaccount refと認可方式と実際のbilling mode。subscriptionとAPI従量と付属API creditを分ける。API keyが環境にある場合の優先順位も検証する。quota切れで無断のAPI課金へfallbackしない。unknown usageは0円としない。

- [OpenAI plan usage overview](https://developers.openai.com/siwc/token-sharing-open-source)
- [OpenAI app-server接続](https://developers.openai.com/siwc/token-sharing-open-source/codex-app-server)
- [OpenAI preview制約](https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations)
- [AnthropicのSDKとplan](https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan)
- [Anthropic認証条件](https://code.claude.com/docs/en/legal-and-compliance#authentication-and-credential-use)

# 推奨する責務

| 境界 | 責務 |
| --- | --- |
| Core | Contract / Attempt / policy / account group / 予算 / 検証 / 承認 / 担当権 / 公開 |
| Agent runtime | dshまたはnative coding agent。promptとtool loopとnative履歴 |
| Model connection | provider / model / reasoning / billing mode / auth ref |
| Credential管理 | 製品が対応するloginとrefreshの所有者。secret本体をledgerへ渡さない |
| Environment | Mac / homelab / ephemeral host。配置とprocessとOS制約 |
| UI | Orcaとdsh UIとCLI。提供される操作を利用する |

論理境界として実装する。6つのdaemonや新しい万能frameworkは不要。Coreの既存ExecutionBackendとcapability manifestを拡張しdsh adapterを追加する。Coreはplugin内部型へ依存せずACPまたはSDKの公開protocolを翻訳する。

dsh ACPはsession/newとlistとresumeとcloseとpromptとcancelを提供する。automation用でDSH固有UIとterminalとforkとtranscript replayを提供しない。authenticateは即成功するtrusted stdio controllerなのでそのままネットワーク公開しない。SDKも永続session/resumeに対応し失敗時に新sessionへ黙って置換しない。Core adapterはまず1つのprotocolで開始する。標準automationを優先するならACPが候補。必要なeventやapprovalに不足がある場合だけSDKを選ぶ。

Orcaはworktreeとterminalとhost操作を引き続き担当できる。dsh固有の会話UIをOrcaがそのままrenderできるとは確認していない。Orcaから起動したdshとdsh UIが同じruntimeへ接続するかもPoC対象。同じ履歴storeを2processが同時に開く方式では代替しない。

- [dsh ACP契約](https://github.com/deepseek-ai/deepseek-harness/blob/571902028a75c64c1d767f4ae5fd099485f0ddf0/packages/acp/acp/README.md)
- [dsh SDK server契約](https://github.com/deepseek-ai/deepseek-harness/blob/571902028a75c64c1d767f4ae5fd099485f0ddf0/packages/sdk/server/README.md)
- [Coreの現行port](https://github.com/r1cA18/harness-core/blob/4dd4beb/src/ports.rs)

# セッションと差し替え

Core Attempt IDからruntime種別とversionとenvironment IDとruntime instanceとnative session refとaccount refを参照する。Orca terminal handleはさらに別の参照。認証tokenやOS固有pathを共通session IDにしない。

runtime profileはengine versionとplugin lock digestとpresetとinstruction digestとsandbox policyとmodel bindingを固定する。現在のglobal defaultを変えて過去Attemptの意味が変わらないようにする。dsh profileとCore profileは名前が同じでも同一の概念にはしない。

- Reconnect: 同じruntimeへ接続する。二重起動しない
- Native resume: 対応engineとstore formatで既存会話を再開する
- Handoff: workspace snapshotと作業記録を渡しsuccessor Attemptを開始する
- Fork: 分離したcheckoutとbranchで並行実行する

同一dshでモデルを変えることとdshから別harnessへ移ることは別。tool call schemaやcompactionやreasoning表現が違うためraw履歴の無変換共有は保証しない。共通化するのは目的と決定と未解決事項とファイル/asset snapshotとEvidenceと次の操作。元のnative logはversion付きで保存し必要な範囲を文脈化する。

dsh persistenceにはwriter ownershipとflush barrierとformat migrationがある。ただし起動直後のsessionが未materializeのまま落ちる場合もある。UIで見えたこととdurable保存を区別する。exportやhost移動の前はflush完了を確認する。live storeをSyncthingで複製しない。

- [dsh persistence](https://github.com/deepseek-ai/deepseek-harness/blob/571902028a75c64c1d767f4ae5fd099485f0ddf0/packages/session/session-persistence/README.md)

# 現行設計との衝突

第三者subscription pluginはauto poolingとquota failoverと長いretry待ちを持つ。account管理の制限はLLM routeに限られ画像や動画や検索のaccount policyは別。アカウントを選んだだけでsession全体のgroup分離が成立しないことを作者自身も明示している。

Coreの許可したaccount集合だけをruntimeへ渡す。初期はpoolを無効化し明示的なaccountに固定する。toolとchildの別routeも制限する。ccspaceとpluginが同じrefresh credentialを別々に更新する構成を避けrefresh ownerを1つに決める。ccspaceが今のまま任意のdsh auth providerになるとは扱わない。

retryの最大待機や回数はCoreの時間・予算制約内に収める。待ち状態とreset予定と実際のaccountを観測できないadapterは無人failoverを有効にしない。モデルへの送信後に結果不明となった要求の再送は重複利用も考慮する。permissionの自動判定はCoreの正式な人間承認の代わりにしない。

dsh 0.2.1-alpha.3とsubscription plugin 0.9.9のpeer rangeは一致していない。pluginは0.2.0-rc.2を明示対応するが0.2.1-alpha.3を含めていない。最新版同士の互換性は未検証。Nixでruntimeとpluginを組み合わせてpinしupgrade時にprotocolとresumeとauthの回帰を確認する。

- [plugin account管理の範囲](https://github.com/V1ki/dsh-plugin-subscriptions/blob/9930c5ee5e3fa239db9031f47a0f6f30f7ffc443/docs/account-management.md)
- [plugin対応version](https://github.com/V1ki/dsh-plugin-subscriptions/blob/9930c5ee5e3fa239db9031f47a0f6f30f7ffc443/package.json)

# 最小の導入順

1. dshと接続方式とaccount scopeを1組だけ固定。独立したHarness homeで試験する
2. Coreのdsh adapterをACPまたはSDKで1つ実装。startとobserveとcancelとnative resumeの対応表を作る
3. 1つの小さいrepoで編集と検証とevent記録と停止とprocess再起動後のresumeを確認する
4. quota切れと認証切れと通信断を試す。無断課金と別group fallbackと二重起動を拒否する
5. dshからnative agentへのhandoffを同じTaskで確認。完全な会話移植は完了条件にしない
6. 通過後にMacとhomelabの往復試験へ進む。評価は成功率と修正回数と時間と利用枠消費で比較する

これは調査提案。runtime選択は既存#22へ接続し継続契約は#9と#60に接続する。今回の記録追加だけではdsh採用や本番稼働やsubscription接続の動作確認は完了しない。

# 補足: dshとClaude Codeでモデル接続を共通化する

所有者の意図はnative agent委譲ではなくdshとClaude Codeそれぞれのloopへ同じモデル接続を選べること。dotfilesには既にraine/claude-code-proxy v0.1.35をpinする構成とclgpt wrapperがある。wrapperはClaude CodeのANTHROPIC_BASE_URLをloopback proxyへ向ける。設定の存在を確認したもので現行マシンへの適用や推論成功は今回検証していない。

共通化する設定はruntimeとmodel connectionを直交させる。runtime=dshまたはclaude-codeを選びconnectionからproviderとmodelとreasoningとbilling modeとaccount refを解決する。各runtime adapterが必要なenvまたはdsh provider設定を生成する。Claude Code用のmainとsmall/fastなど役割ごとのrouteも宣言する。account pickerがClaudeのconfig homeを変えてもproxyのCodex accountまで切り替わったとは扱わない。

第一段階は共通の宣言とcapability検査だけでよい。既存proxyとdsh adapterの実装をすべて書き直さない。次の段階で同一hostの共通gatewayを使う場合はClaude CodeにAnthropic Messagesを提供しdshに対応するMessagesまたはResponsesを提供する。dshのpi-ai adapterはcustom gatewayのapiとbaseURLを指定できる。現行proxy docsにも両protocolがある。ただしpinしたproxyとdshの組み合わせでtool call往復とstreamとreasoningとcancelとusageの互換確認が必要。特にCodexのChat Completions routeは現行docsでfunction tools非対応なので単にOpenAI互換として接続しない。

gatewayはモデル推論と認証とroutingを持ちcoding toolを実行しない。session履歴は各runtimeに残す。Coreの正式承認とpolicyをgatewayの推論判断へ移さない。各hostのloopbackに配置すればhomelab切断中もローカルruntimeを利用できる。現在のproxyはclient authを検証しないためprofile名や偽のbearer tokenだけでgroup隔離を作らずprocessと実行境界を分離するか認証・認可を持つ入口を用意する。

所有者が決めるのは主runtimeと最初のmodel routeとサブスク上限時の動作と非公式接続の採用範囲。会話の切替保証は同一runtimeのmodel切替と別runtimeへのhandoffを分ける案を推奨する。protocol選択や共通設定形式や段階的実装は技術判断として進められる。

- [既存proxy v0.1.35](https://github.com/raine/claude-code-proxy/blob/v0.1.35/README.md)
- [proxyの現行HTTP契約](https://claude-code-proxy.raine.dev/reference/http-api/)
- [dsh custom gateway adapter](https://github.com/deepseek-ai/deepseek-harness/blob/571902028a75c64c1d767f4ae5fd099485f0ddf0/packages/llm/llm-pi-ai/README.md)
