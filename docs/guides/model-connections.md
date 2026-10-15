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

| 要素 | 管理対象 |
| --- | --- |
| runtime | 実行commandと正確なversion |
| connection | providerとaccount_refとgroupとbillingとgateway origin |
| models | mainと任意のsmallのIDと容量 |
| profile | runtimeとconnectionの選択 |
| fingerprint | 解決した選択全体のSHA-256 |

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
