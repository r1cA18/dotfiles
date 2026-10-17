# 共有agent資産の分類catalog

`agents/catalog/assets.json`は共有資産を種類と分野から探すための小さな索引である。正本の本文は既存の`agents/rules/`と`agents/skills/`とproject docsに置く。分類追加のためにSKILL.mdを移動しない。

catalogへの登録はassetの有効化や承認を意味しない。Nixの配布対象とnative runtimeの発見設定も変えない。初期catalogは自作資産の一部だけを対象にする。外部plugin cacheと個人vault全体の索引ではない。

## 種類と責務

| kind | 内容 | 正本または実行境界 |
| --- | --- | --- |
| `rule` | 常に守る制約と方針 | 共有instructionと製品固有のenforcement |
| `skill` | 必要なときに読む作業手順 | Agent Skills形式のSKILL.mdと同梱resource |
| `knowledge` | 出典付きの知識と決定と調査 | project docsまたは認可されたknowledge service |
| `tool` | 実行できる操作の契約 | MCP/API/CLIとserver側の認可 |
| `plugin` | skillやtoolやhookの配布bundle | 製品ごとのmanifestと固定source revision |
| `stack-pack` | 実行可能な構築と検証の定義 | Harness Packと対象snapshotに結ぶEvidence |

Git命名とPR書式の常時制約はruleへ置く。PR作成と検証証拠の添付手順はskillへ置く。実際のlintとtest commandはstack packへ置き証拠をAttemptへ結ぶ。スクリーンショット撮影はUI変更の検証手順に含める。全作業に撮影を強制しない。

税の申告を支援する場合は`life/tax/jp/filing`のような分野を登録できる。手順skillと税年度ごとの知識を分ける。税年度と地域と有効期間と公式出典の検証はknowledge契約の責務である。分類名やskillを読める事実から税資料の閲覧権限や本人としての送信権限を導かない。

## 分類と検索

`taxonomy`はslashで階層を表す。子を登録するときは各親も登録する。assetの`categories`は複数指定できる。UI検証は`engineering/ui/web`と`engineering/quality`の両方に属せる。

```json
{
  "id": "skill:baseline-ui",
  "kind": "skill",
  "title": "UI baseline",
  "summary": "Apply interface constraints to frontend implementation and review.",
  "path": "agents/skills/baseline-ui/SKILL.md",
  "categories": ["engineering/ui/web", "engineering/quality"]
}
```

IDはcatalog内の参照である。native skill名とplugin namespaceとCoreの実行IDを兼ねない。pathはrepo内の実在fileを指す。absolute pathと親directory移動とrepo外へのsymlinkを拒否する。同じ実体を別IDで重複登録できない。

```bash
bun agents/scripts/asset-catalog.ts validate
bun agents/scripts/asset-catalog.ts select --domain engineering/ui --kind skill --query review --limit 5
```

`select`は分野配下と種類と全文字列条件をANDで絞る。query内の空白区切り語をすべて検索する。検索対象はcatalog metadataだけで本文は読まない。結果はID順で最大5件を返す。`--limit`は1〜50件。`has_more`がtrueなら分野やqueryを狭める。意味検索と自然言語による自動振り分けは行わない。

```bash
bun test agents/scripts/asset-catalog.test.ts
```

検査は未知の分類と重複と参照切れとpath逸脱とselectorの誤りを拒否する。`schema.json`はeditor向けの構造定義である。validatorは参照fileと分類の親子関係も検査する。

通常の`bash scripts/test.sh unit`とCIもcatalogの回帰testを実行する。

## Native harnessとの接続

各harnessには引き続き通常のSKILL.mdを渡す。Agent Skills標準はnameとdescriptionから本文を段階的に読む形式を定義する。標準のmetadataはstringからstringのmapなので配列を持つ分類catalogはsidecarに置く。[Agent Skills specification](https://agentskills.io/specification)

Claude Codeはskillを個別またはplugin経由で配布できる。CodexもSKILL.mdと製品固有metadataを使いpluginとしてまとめられる。dshはskill providerのlist/getとflatなlocal skill rootを持つ。物理directoryの探索方式と同名解決規則は製品ごとに違う。taxonomyはその違いを隠さず上に重ねる。[Claude skills](https://code.claude.com/docs/en/skills)・[OpenAI Build skills](https://learn.chatgpt.com/docs/build-skills)・[dsh skill provider](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/skill/skill-filesystem/README.md)

このselectorを追加するだけではnative runtimeが起動時に読むmetadata量は減らない。次の段階でtaskに必要な少数のskillを選びruntime固有の可視性設定へ接続する。常時ruleは選択対象から脱落させずCoreで使ったcatalog revisionとskill digestを記録する。dshのscopeはregistryの可視性でありOS sandboxや外部serviceの認可を代替しない。

## 正本の置き場所

当面は汎用ruleとskillとcatalogをdotfilesの`agents/`へ置く。Nixは配置adapterの責務を持つ。個人の税資料と会話とcredentialをここへ置かない。

複数projectが独立したversionで共有資産を使う必要が生じたときは独立repo化を判断する。その場合もcatalogとSKILL.mdの形式を保ちdotfilesが固定revisionを取得する。独立repo作成と既存knowledge移行は別の方針決定として扱う。
