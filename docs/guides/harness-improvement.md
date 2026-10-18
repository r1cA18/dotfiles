# Harness improvement runtime

Coreのbounded improvement実験を既存のruntimeへ接続するopt-in adapter。
Coreが承認・group・budget・Attemptを管理しadapterが1回のstageを実行する。
Coreのreportは選ばれた候補を記録する。自動インストールは行わない。

## 配置とテスト

`dotfiles.harnessRuntime.enable = true`のHome Manager設定は
`harness-improvement-runtime`を既存の接続commandと一緒に配布する。
設定をapplyする前でもcheckout内のBun scriptをそのまま試験できる。
既存のloginとdefault modelは変更しない。

Core側の[検証ガイド](https://github.com/r1cA18/harness-core/blob/feature/62-bounded-improvement/docs/improvement-validation.md)と
[一括テストscript](https://github.com/r1cA18/harness-core/blob/feature/62-bounded-improvement/scripts/validate-improvement.py)に
両repoを一緒に確認する入口がある。Coreの承認fixture・adapter・固定dshの
合成modelと実toolを通す。providerには接続しない。

このPR単体の回帰試験は次のとおり。

```bash
bun test tests/harness-runtime.test.ts tests/harness-improvement-runtime.test.ts
```

固定dshを使う追加試験は既存の`HARNESS_TEST_DSH_BINARY`経由で
`tests/harness-runtime-native.test.ts`を実行する。read toolとcancelに加えて
改善adapterからwrite toolで構造化結果を保存する試験を含む。

## Gateway binding

portable profileと端末固有bindingは[model connections](model-connections.md)の形式を使う。
adapter用のJSONは次の形式。これらは説明用のplaceholderで実account設定ではない。

```json
{
  "kind": "gateway",
  "runtime": "dsh",
  "manifest": "/absolute/path/to/model-profiles.json",
  "bindings": "/absolute/path/to/device-bindings.json",
  "profile": "development",
  "group": "personal"
}
```

`runtime`は`dsh`か`claude`。後者をprofile resolverの`claude-code`へ対応させる。
Coreが固定したaccount・group・runtime・versionとの不一致は起動前に拒否する。
manifestとdevice bindingとnative executableもCoreの`runner.files`へpinする。
未検証のsubscription gatewayは既存resolverと同じく拒否する。

## Native subscription binding

Claude CodeかCodexのnative loginをその実行hostで使う経路。
既存の専用account homeを参照する。OAuth/tokenを取り出してdshへ渡す経路ではない。

```json
{
  "kind": "native",
  "runtime": "codex",
  "command": "/absolute/path/to/codex",
  "version": "0.163.0",
  "model": "explicit-supported-model-id",
  "config_home": "/absolute/path/to/dedicated-account-home",
  "account_ref": "operator-account-reference",
  "group": "personal"
}
```

`runtime`は`codex`か`claude`。native commandとbinding JSONをCoreへpinする。
versionとmodelはそのaccountで利用可能な値を本人が選ぶ。
専用account homeの認証と設定は既存のaccount管理側が所有する。
通常利用の全pluginやskillを含むhomeを実験へ渡すと候補以外の資産が混ざるため
pilotには専用の最小account homeを用意する。

このadapterは`account_ref`をCoreの登録情報と照合する。実際にログインしている
provider identityの検証やaccount homeの配布は既存account管理側で別途必要。
登録情報が一致したことだけで実subscription推論まで成功したとは扱わない。

Codexは`exec --ignore-user-config --ephemeral --sandbox workspace-write`を使い
最終応答をJSONとして読む。Claudeはprint modeでRead/Writeのみを指定し
user設定と任意のMCP接続を読み込まない起動引数を使う。
flagsの読み取り確認対象はCodex0.163.0とClaude Code2.1.302。
これらのversionでの実subscription推論はまだ実施していない。

## 資産とprotocol

Coreが指定する`AGENTS.md`と`tool-guidance.md`と
`skills/<name>/SKILL.md`だけを受け取る。runtimeごとの配置へ変換する。
proposalの内容を編集者自身のinstructionとして有効化しない。

| Runtime     | Instructions                                           | Skills                                                     |
| ----------- | ------------------------------------------------------ | ---------------------------------------------------------- |
| dsh         | 実験専用`DSH_HOME/AGENTS.md`                           | 同homeの`skills/`                                          |
| Claude Code | 実験cwdの`CLAUDE.md`または専用config homeのinstruction | 実験cwdの`.claude/skills/`または専用config homeの`skills/` |
| Codex       | 実験cwdの`AGENTS.md`                                   | 実験cwdの`.agents/skills/`                                 |

CoreのJSON request/response protocolを使う。手動起動のためのmodel promptや
追加native flagsをこのcommandへ渡す方式ではない。requestには編集可能なpathと
承認済みfile pinsと残り時間が含まれる。native executableや参照profileのpinが
ない場合も拒否する。modelは`native-response.json`を作りadapterが検査後に
Coreの`response.json`を作る。

process groupのdeadline・cancel・残存childの終了は既存launcherと共有する。
一時HOMEと環境変数のallowlistはOS sandboxではない。実modelのpilotは隔離workerで行う。
Gateway接続のallowlistやnative account home参照自体を強い権限分離とは扱わない。

## この変更と日常の引き継ぎ

[利用フローの認識合わせ](../research/harness-workflow-alignment-2026-10-18.md)に
local/cloud両方向とruntime/model/group変更の要件を記録した。
このPRは1stageを起動するadapterまで。端末間snapshot転送・slash command・
Console・MCP経由の引き継ぎは未実装。
