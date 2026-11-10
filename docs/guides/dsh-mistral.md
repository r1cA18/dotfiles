---
title: DSHで個人Mistral Proを接続する
created: 2026-11-06
type: guide
tags: [dsh, mistral, harness]
---

# DSHで個人Mistral Proを接続する

## 現在の状態

DSH 0.2.1-rc.2の標準`llm-pi-ai`adapterでMistral接続を追加した。
個人用DSH homeのWebとTUIに適用済み。登録されたキーによる推論とファイル読取と履歴保存を確認した。
Mistral管理画面での利用枠の消費先は未確認。
Subscriptions plugin 0.9.12にはMistral実装がないため利用しない。

設定の正本は[追加用patch](../../agents/dsh/mistral.patch.json)。
`llm-pi-ai.config.providers.mistral`を既存profileの同名entryにmergeする。
既存の`agent-default-model`と他providerは維持する。
WebとTUIは同一のDSH homeを使用する必要がある。

| 項目 | 設定 |
| --- | --- |
| 表示名 | Mistral (personal Vibe) |
| Provider | `mistral` |
| Models | 下表の5モデル |
| Reasoning | 接続の既定は共通で利用できる`high`。選択肢はモデルごとに表示 |
| Credential reference | `HARNESS_MISTRAL_PERSONAL_VIBE_KEY` |
| Adapter | 組み込みの`llm-pi-ai` |
| Protocol | 組み込みcatalogの`mistral-conversations` |
| Endpoint | 組み込みcatalogの`https://api.mistral.ai` |

モデルは公式資料とインストール済みcatalogの両方で確認した。
Large 4はPublic Preview。登録されたキーによる実通信にも成功した。
このモデルは`reasoning_effort: none`を拒否するため選択肢と既定値を明示する。
失敗時の別アカウントや別providerへのfallbackは追加していない。
この設定はローカルDSH向け。Core dispatchと統合launcherの新transport実装ではない。
headless profileは既定で対話用credential storeを無効にする。
追加用patchは`credentials`も有効にしてWebで登録したキーを解決する。

## モデルの切り替え

TUIでは`/model`を入力してMistral配下のモデルを選ぶ。
Webでは入力欄のモデル選択を開く。
Webの実際の選択メニューに5モデルが表示されることを確認済み。
既に開いているTUIに追加候補が出ない場合は実行中の処理が終わってから再起動する。
新しい候補を追加しても選択中のモデルを自動では切り替えない。

| 表示名 | Model ID | 確認状態 |
| --- | --- | --- |
| Mistral Large 4 | `mistral-large-4` | 推論・ファイル読取・保存確認済み |
| GLM 5.3 | `zai-glm-5-3` | 推論・ファイル読取・保存確認済み |
| GLM 5.3 Flash | `zai-glm-5-3-flash` | 推論・ファイル読取・保存確認済み |
| DeepSeek V4.1 Flash 1017 | `deepseek-v4-1-flash-1017` | 推論・ファイル読取・保存確認済み |
| Mistral Small 4 | `mistral-small-2603` | 推論・ファイル読取・保存確認済み |

すべて登録済みMistralキーとMistralのendpointを使う。
Z.aiやDeepSeekの別アカウントへの接続ではない。
GLM 5.2はモデル一覧APIには残っていたが公式changelogでは2026-10-31終了とされているため追加していない。
一覧APIへの掲載だけでサブスクの対象枠や無制限利用を判定しない。

追加4モデルの実行は各1回。GLM 5.3とFlashとDeepSeekは確認用ファイルと完全一致する返答を返した。
Small 4はファイル内容の前に読取結果の行番号を付けたため厳密な出力一致は不成立。
全モデルでtool call/resultの成功と正常終了と保存履歴の21イベント連続性を確認した。
これは接続とtool実行の確認であり一般的なコーディング品質の比較ではない。

## キー登録

1. 個人Proのアカウントで[Vibe CLI設定](https://chat.mistral.ai/code/extensions)を開く
2. Vibe用のキーを発行する
3. [Subscription](https://admin.mistral.ai/subscription)で対象Organizationの利用枠とPAYG設定を確認する
4. DSHのWeb画面で左下メニューからSettings → Modelsを開く
5. Mistral (personal Vibe)を編集してAPI key欄に貼り付けApplyを押す
6. 新しいセッションでMistralの`mistral-large-4`を明示選択する

キーはチャットやGitへ貼らない。DSHのcredential serviceがprivate homeの
`.credentials.yaml`へowner-onlyで保存する。設定patchは参照名だけを持つ。
今回の作業では課金設定を変更していない。

Mistralの公式説明ではプランに含まれる利用枠を先に消費し
PAYG有効時は枠外の利用にprepaid creditsを使用する。
API keyにはStudioとVibeの種類がある。
API経由で成功したことだけでVibe枠から消費されたと判定せず
初回の短い推論後に管理画面の利用量を確認する。

## 検証

- 隔離したWeb・TUI・headlessの3profileでpatchの構成解決に成功
- WebとTUIの既定providerが変わらないことを確認
- 隔離したheadlessをMistralに固定して起動
- キー未登録時に`MISSING_CREDENTIAL`で終了することを確認
- 修正後の検証ではpluginのactivation warningなし
- 本番用Web設定画面の起動を確認
- ブラウザでMistralの表示とAPI key欄とApplyボタンを確認
- 登録されたキーで`mistral-large-4`と`low`に固定した実行が5.89秒で正常終了
- promptに内容を含めない確認用ファイルを`read`で読み取り完全一致する返答を確認
- 終了後の圧縮履歴を全frame復号して21イベントの連続性を確認
- 保存履歴のproviderとmodelとtool call/resultの対応と完了状態を確認

未確認はMistral管理画面での利用枠の消費先。
現在の通常版Orcaへの履歴取込も未確認。新Orcaへの移行は延期中。

## 参照

- [Mistral subscriptions](https://docs.mistral.ai/admin/billing-usage/subscriptions)
- [Mistral API key types](https://docs.mistral.ai/admin/identity-access/api-keys)
- [Vibe CLI setup](https://docs.mistral.ai/vibe/code/cli/install-setup)
- [Mistral Large 4](https://docs.mistral.ai/models/mistral-large-4-0)
- [GLM 5.3](https://docs.mistral.ai/models/zai-glm-5-3)
- [GLM 5.3 Flash](https://docs.mistral.ai/models/zai-glm-5-3-flash)
- [DeepSeek V4.1 Flash 1017](https://docs.mistral.ai/models/deepseek-v4-flash-1017)
- [Mistral changelog](https://docs.mistral.ai/resources/changelogs)
