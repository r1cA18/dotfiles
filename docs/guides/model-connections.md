# ハーネスとモデル接続の選択

dsh・Claude Code・Codexのruntimeとモデル接続を明示選択するopt-in設定。
既存の`claude`・`clgpt`・account設定を変更しない。

## 共通設定

`agents/model-connections/example.json`を参考に別fileへ設定する。
旧catalogの例はsubscription接続の宣言を示す。利用可能性の保証ではなく現在のlauncherはこのsubscription gatewayを拒否する。
起動試験には明示したAPI接続か後述のsynthetic testを使う。
設定にtokenやcredentialを保存しない。account_refは外部gatewayの認証設定を指す名前。

```bash
bun agents/scripts/model-connection.ts list --config /path/to/connections.json --group personal
bun agents/scripts/model-connection.ts resolve --config /path/to/connections.json --group personal --profile development
bun agents/scripts/model-connection.ts resolve --config /path/to/connections.json --group personal --profile development --runtime claude-code
```

CLIはJSONを返す。共通処理は同じscriptのloadCatalogとresolveConnectionから利用可能。
明示groupに属さないprofileと未知の設定と未対応runtimeは拒否する。
profile未指定の自動実行は行わない。default_runtimeはdsh。

| 要素        | 管理対象                                                   |
| ----------- | ---------------------------------------------------------- |
| runtime     | 実行commandと正確なversion                                 |
| connection  | provider・account_ref・group・billingとtransport固有の参照 |
| models      | mainと任意のsmallのIDと容量                                |
| profile     | runtimeとconnectionの選択                                  |
| fingerprint | 解決した選択全体のSHA-256                                  |

gateway transportはloopbackのAnthropic Messagesへ限定する。
native transportは後述の既存login参照を使用する。
API形式を揃えるだけでtool呼び出しとreasoningとusageが互換になるとは扱わない。
同じgateway originへ異なるaccount scopeを宣言する設定は拒否する。

## 保証の境界

これは認証済みのpolicy authorityではなく信頼する設定のresolver。
呼び出し側が指定するgroup自体を人間の認証と見なさない。
`resolve-core`はCoreの現在のaccount割当とhost登録を照合する。
実行の認可はCore dispatchの署名済みContractとpolicyが担う。

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

起動ごとにstate配下へprivate directoryを作りHOMEとXDGを分離する。
version probeではDSH_HOMEとCLAUDE_CONFIG_DIRとCODEX_HOMEも分離する。
gateway起動はこのprivate設定を使用する。native起動はprobe後に選択したconfig-homeを参照する。
既存のnative設定とcredentialを複製しない。
共有instructionと選択済skillsは後述の明示したasset接続で渡す。
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

共通の`nix/home-manager/home.nix`はmoduleをimportし
`dotfiles.harnessRuntime.enable = true`と`dsh.enable = true`を宣言している。
次回の明示applyでCLIとpin済みruntimeと共有assetが配布される。
module単体の初期値は無効。enableだけならCLIを追加する。
runtimeやgatewayの自動起動は行わない。

```bash
bun test tests/model-connection.test.ts tests/harness-runtime.test.ts
```

通常のintegration fixtureはfake native executableを使う。
実binaryとsynthetic endpointの試験は後述のnative testで分ける。
実providerとのtool往復・subscription quota・native resumeは未検証。

## Device間で共有するprofile

新しい設定はportable manifestとdevice bindingへ分ける。
`portable.example.json`は宣言例でありsubscription gatewayの起動例ではない。
model IDと容量は利用前に確認する。

| 文書                 | 内容                                                                 | 配布                  |
| -------------------- | -------------------------------------------------------------------- | --------------------- |
| portable manifest    | runtime version・model・group・account_ref・profile                  | 秘密を含めずGitで共有 |
| device binding       | executable・gateway originまたはnative config-home・Core account参照 | 各deviceのprivate設定 |
| native account state | OAuth token・refresh token・session・plugin cache                    | 各製品のloginで管理   |

manifestは既存connection catalogと同じ契約を再利用する。
実行pathやportやcredential homeを共有profileへ入れない。
`account_ref`は論理名であり認証結果の証明にはならない。

```bash
harness-profile list --manifest /path/to/portable.json --group personal
harness-profile doctor --manifest /path/to/portable.json --bindings /path/to/device-bindings.json --group personal
harness-runtime plan --manifest /path/to/portable.json --bindings /path/to/device-bindings.json --group personal --profile development
```

doctorは不足command・不足account binding・group不一致・gatewayのscope競合・未対応transportをJSONで返す。
blockedはexit 1でschema不備はexit 2。file作成もversion probeもcredential読取も推論もしない。
`ready`は構成の整合性を表し認証・binary存在・model entitlement・通信成功は未確認。
manifest fingerprintはdevice間で同じであり解決したselection fingerprintはpathやportに応じて変わる。
実行履歴・承認・budget reservation・task所有者・native sessionの移動はこの文書では扱わない。

### Subscriptionの対応境界

2026-10-18確認時点で次の違いがある。

- Claude subscriptionは未変更のnative Claude Codeから本人がloginして利用する
- dshへのClaude subscription token移植やthird-party login pluginは有効化しない
- ChatGPT planにはOSS client向け公式sign-in flowがある
- 公式ChatGPT flowはapp専用のclient IDとhost IDと本人のconsentを必要とする
- このlauncherには公式ChatGPT sign-inとResponses adapterをまだ実装していない
- 既存Codex credentialを読み出してgatewayへ転用しない

Claudeの境界は[Anthropic公式のcredential利用条件](https://code.claude.com/docs/en/legal-and-compliance)に基づく。
ChatGPTの経路は[公式Sign in with ChatGPT](https://developers.openai.com/siwc/token-sharing-open-source)で確認できる。
この公式経路には[Responsesのpreview制約](https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations)があり単にAPI URLを変えただけでは互換にならない。

subscription gatewayは旧catalogを直接指定した場合もlauncherで拒否する。
API課金・別account・native runtimeへの自動fallbackは生成しない。
CodexはAnthropic Messages gatewayを受け付けない。
native CodexとClaude Codeは次のnative transportを明示選択する。ccspaceで管理するhomeも参照できる。

## Native loginのdevice binding

`native.portable.example.json`と`native.bindings.example.json`を別fileへコピーして使用する。
modelとversionは実際に利用可能なものへ置き換える。例の容量はnative CLIへ上限として適用しない。
manifestは中央catalogとして共有する。各hostのbindingはprivateに保存してGitへ入れない。
各hostでは対象製品の正式なloginを別途済ませておく。
このlauncherはloginとtoken配布とaccount自動作成を行わない。

- `openai`のnative接続は`codex`を使用する
- `anthropic`のnative接続は`claude-code`を使用する
- `config_home`は既存の専用homeの絶対pathを指定する
- `core_account.host`はCore環境登録の`spec.name`を指定する
- `core_account.id`はそのhost上の検証済みaccountの`sha256:`IDを指定する
- Core参照は通常のplan/runでは任意。`resolve-core`では必須
- native接続のmodel指定は`main`のみ。small modelの暗黙置換は行わない

同じmanifestをMacとLinuxへ置き各deviceのbindingだけを変更する。
profileとgroupとmodelは共通のままexecutableとlogin参照とCoreのhost/accountだけを切り替えられる。
同一pathの正規化で検出できる異なるscopeの共有は拒否する。symlinkの同一性はdoctorで検査しない。

まず`doctor`と`plan`で選択を確認する。
これらはcredentialの内容とlogin状態とmodel entitlementを検査しない。

```bash
harness-profile doctor --manifest /path/to/native.json --bindings /path/to/private-bindings.json --group personal
harness-runtime plan --manifest /path/to/native.json --bindings /path/to/private-bindings.json --group personal --profile development-chatgpt
harness-profile resolve-core --manifest /path/to/native.json --bindings /path/to/private-bindings.json --group personal --profile development-chatgpt --core /path/to/harness-core --operator-ledger /path/to/operator-ledger
```

`resolve-core`はCoreのaccount showとenvironment listだけを呼ぶ。
検証済みidentity・provider・group・hostが一致しhostがactiveであることを要求する。
失効とquarantineと未登録hostは拒否する。ledgerの更新とruntimeの起動は行わない。
返却する`dispatch`は署名前の入力候補であり署名済みDispatchPlan全体ではない。
CLIは機微な表示情報を除き必要な参照だけを返す。
config-homeとaccountの対応はoperatorの明示宣言でありlogin照合の証拠ではない。
Core dispatchは実行直前に最新policyを再検査する。

明示的なtask実行では既存の`harness-runtime run --execute true`を使用する。
launcherはpinしたversionをprivate homeで確認してから選択したnative homeを渡す。
Codexは`exec --json --model`を使用する。Claude Codeは`--print --model`を使用する。
wrapperは既存homeへ書き込まないがnative製品自体は認証更新やsession保存を行い得る。
native設定内のhookとprovider設定は信頼するoperator管理設定として扱う。
外部から渡す共有assetはnative接続では拒否する。既存homeへ配布済みのinstructionとskillsを利用する。
packaged launcherのdsh向け共有asset既定値はnative接続には適用しない。

実loginによる推論とnative resumeは未検証。config-homeの存在だけではlogin成功と見なさない。
このresolverはhost割振りと停止・転送・復元・後続Attempt作成を自動化しない。

## DeepSeek Harnessの固定導入

共通home構成では下記を宣言済み。別のHome Manager構成で利用する場合も
importと明示enableの両方を指定する。

```nix
{
  imports = [ ./programs/harness-runtime.nix ];
  dotfiles.harnessRuntime = {
    enable = true;
    dsh.enable = true;
  };
}
```

`dsh.enable`は公式npm package `@deepseek-ai/dsh@0.2.1-rc.2`と依存lockを固定する。
upstreamは[developer preview](https://github.com/deepseek-ai/deepseek-harness)であり互換性変更があり得る。
更新はversionとtarball hashとlockとnative smoke結果を一緒にreviewする。

native loaderはNode内部へのアクセスを使う。
Nix-built Node22と24のApple Silicon binaryでrealm getterの互換失敗を確認したため
公式Node24.20.0 binaryをpackage専用に固定して呼ぶ。
global NodeとBunの選択は変わらない。Linuxでは同じ公式NodeをNixのloaderへpatchする。

共有instructionは既存`agent-instructions.nix`から`.dsh/AGENTS.md`へ生成する。
`agent-skills-nix`の同じ選択済skillを`.dsh/skills`へ配布する。
Nixが管理する配布先はdefault homeに固定しactivation環境のDSH_HOMEでは変更しない。
別のDSH_HOMEを手動指定するnative起動ではそのhomeへのasset接続も明示する。
同moduleを使わない検証環境では`dsh.shareSkills = false`を明示する。
dshはflatなskill bundleだけを発見するのでcatalogの分野階層をnative directoryへそのまま反映しない。

packaged `harness-runtime`は共有instructionと選択済skillsをprivate native homeへ接続する。
直接scriptを呼ぶ場合は`--instructions-file`と`--skills-directory`を明示できる。
instruction本文のhashはrun bindingに保存する。skillは参照先へのsymlinkでありsnapshotではない。
plugin本体とcredentialとnative cacheは複製しない。

## Native runtimeの隔離検証

```bash
nix build .#deepseek-harness
HARNESS_TEST_DSH_BINARY="$PWD/result/bin/dsh" bun test tests/harness-runtime-native.test.ts
```

native testはpin済みの実dshを使いprivate HOMEとprivate DSH_HOMEを作る。
loopbackのsynthetic Messages endpointに対してread toolの往復とinstruction/skill読込とdeadline cancelを検証する。
外部providerもloginもsubscriptionも使用しない。
通常suiteでは明示binaryがないnative testをskipする。
Linux CIのregression jobはpin済みpackageをbuildしてnative testを明示的に実行する。
