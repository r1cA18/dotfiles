# ハーネスとモデル接続の選択

同じモデル接続をdshとClaude Codeから選ぶためのopt-in設定。
既存の`claude`・`clgpt`・account設定を変更しない。

## 共通設定

`agents/model-connections/example.json`を参考に別fileへ設定する。
例のversionとmodel IDは互換試験前の値。利用可能性の保証ではない。
設定にtokenやcredentialを保存しない。account_refは外部gatewayの認証設定を指す名前。

```bash
bun agents/scripts/model-connection.ts list --config /path/to/connections.json --group personal
bun agents/scripts/model-connection.ts resolve --config /path/to/connections.json --group personal --profile development
bun agents/scripts/model-connection.ts resolve --config /path/to/connections.json --group personal --profile development --runtime claude-code
```

CLIはJSONを返す。共通処理は同じscriptのloadCatalogとresolveConnectionから利用可能。
明示groupに属さないprofileと未知の設定と未対応runtimeは拒否する。
profile未指定の自動実行は行わない。default_runtimeはdsh。

| 要素        | 管理対象                                              |
| ----------- | ----------------------------------------------------- |
| runtime     | 実行commandと正確なversion                            |
| connection  | providerとaccount_refとgroupとbillingとgateway origin |
| models      | mainと任意のsmallのIDと容量                           |
| profile     | runtimeとconnectionの選択                             |
| fingerprint | 解決した選択全体のSHA-256                             |

接続はloopbackのAnthropic Messages gatewayに限定する。
API形式を揃えるだけでtool呼び出しとreasoningとusageが互換になるとは扱わない。
同じgateway originへ異なるaccount scopeを宣言する設定は拒否する。

## 保証の境界

これは認証済みのpolicy authorityではなく信頼する設定のresolver。
呼び出し側が指定するgroup自体を人間の認証と見なさない。
Coreの認可済みgroupを渡す接続は別工程。

現在のclaude-code-proxyはclient authを検証せずproxy側のcredentialを使う。
account_refが実際のupstream accountと一致することは別途確認が必要。
Claudeのconfig homeを変更してもproxyのCodex accountは切り替わらない。
複数groupでは別のgateway instanceと実行境界を用意する。
portの分離だけでは同一OS user間の秘密保護を保証しない。

resolverはfallbackを生成しない。実際のgatewayにもpoolとAPI課金fallbackがないことを確認する。
quota到達時は停止を初期実装とする。resetまでの永続待機と同一groupでのaccount切替は
usageとaccountの観測契約が整ってから追加する。
会話履歴は各runtimeが管理し別runtimeへの完全移植は扱わない。

## 検証

```bash
bun test tests/model-connection.test.ts
```

fixtureのみを使用する。loginと推論とservice起動とHome Manager適用を行わない。

## 設定生成と明示起動

```bash
bun agents/scripts/harness-runtime.ts plan --config /path/to/connections.json --group personal --profile development
bun agents/scripts/harness-runtime.ts plan --config /path/to/connections.json --group personal --profile development --runtime claude-code
```

planはfile作成とversion probeとservice起動を行わない。
Claude Code向けのprocess-local環境変数またはdsh向けのCordis patchをJSONで返す。
dshではbase-backed headless profileのpi-ai adapterを利用する。
Anthropic Messagesで接続するためCodex Chat Completionsのtool非対応経路を使用しない。

将来の明示的な試験実行は以下。現在の設定へ自動適用されるコマンドではない。
事前にpinしたruntimeとaccount専用gatewayが利用可能である必要がある。
このlauncherはruntimeのinstallとgatewayのloginとservice起動を行わない。

```bash
bun agents/scripts/harness-runtime.ts run --execute true --config /path/to/connections.json --group personal --profile development --cwd /path/to/repo --state /path/to/private-state --task-file /path/to/task.txt
```

起動ごとにstate配下へprivate directoryを作りnative HOMEとXDGとDSH_HOMEと
CLAUDE_CONFIG_DIRを分離する。既存のnative設定とglobal skillsは複製しない。
repo内のinstructionはruntime自身が読み込む。credentialも引き継がない。
実行planのfingerprintとcwdをbinding.jsonへ保存する。
stdoutはnative出力のまま保持し終了時のnative codeとstate directoryをstderrへJSONで返す。

version不一致ならtaskを起動しない。taskをshellとして展開しない。
初期実装は新しいsessionでの1回実行。resumeとOrcaの操作とCoreへの結果登録は未接続。
10分の上限とSIGINT/SIGTERMでprocess groupを停止し終了後に子processを回収する。
終了コード3はcancelまたはsignalによる結果不明。設定不備は2。
それ以外のnative終了コードはそのまま返す。
exit 0だけではCoreの検証成功や承認や正式完了を記録しない。

この分離はOS sandboxではない。同じuserで動くtoolは他のfileも読めるため
信頼できないrepoは別の隔離実行環境が必要。gatewayの推論やtoken更新も停止対象ではない。
state内には会話や作業記録が入り得るためcacheとして自動削除しない。

Home Manager配布を希望する環境では
`nix/home-manager/programs/harness-runtime.nix`をimportし
`dotfiles.harnessRuntime.enable = true`を指定する。
既存のhome構成にはimportしておらず初期値は無効。
有効化してもCLIの追加だけでruntimeやgatewayを起動しない。

```bash
bun test tests/model-connection.test.ts tests/harness-runtime.test.ts
```

integration fixtureはfake native executableのみ起動する。
実際のdshとpi-aiとproxyのtool往復・subscription quota・native resumeは未検証。
