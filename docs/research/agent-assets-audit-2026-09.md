---
title: "Agent skillとpluginの棚卸し"
created: 2026-09-06
type: research
tags: [agents, skills, plugins, audit]
---

# Agent skillとpluginの棚卸し

## 結論

Nixによる共有skillの配布とprofileごとのruntime分離はすでに整っている。
不足しているのは資産の置き場よりも、似たskillの選択基準と依存先の検証である。
今回の実測で、有効skillのYAML構文不正を2件修正した。監査skillの評価基準も、
強い呼び出し文言やtrigger数を加点する方式から適用範囲の明確さを評価する方式へ修正した。

skillやpluginの一括削除は行っていない。cacheに存在することと現在有効なことは別である。

## 調査範囲

2026-09-06のmacOS上のcheckoutとruntimeを調査した。
以下の件数は本セッションの`session-handoff`追加前のsnapshotである。
追加後の値はNix定義と実際の配布先で再確認する。

| 対象                         | 実測結果         | 検証内容                                                                |
| ---------------------------- | ---------------- | ----------------------------------------------------------------------- |
| `agents/skills/*/SKILL.md`   | 24件             | 全件のfrontmatter parse・行数・補助資産・descriptionを確認              |
| Swift router配下             | 6件              | 配置とrouterからの参照を確認                                            |
| `~/.codex/skills/*/SKILL.md` | 38件             | 共有の配布済みtop-level skillを確認                                     |
| Nixのskill source            | 8種              | custom・Anthropic・difit・screenshots・NotebookLM・Typst・taste・Lottie |
| Codex profile                | primaryと追加1件 | configのplugin項目とcache名を比較                                       |
| Claude profile               | primaryと追加2件 | settingsのplugin項目とinstalled一覧・cache名を比較                      |

system skillとplugin同梱skillは38件の外側にある。Swift sub-skillもtop-level件数には含めない。
全skillの全referencesや全scriptを実行した監査ではないため、7次元の総合点は付けていない。
静的な役割重複候補と実際に発生した誤起動も区別する。モデルを使ったtrigger評価は未実施である。

credential・認証ファイル・生transcriptは本資料に含めない。profile名は匿名化する。

## 管理の構造

| 資産                        | 正本                                      | 配布・実体                      | 判断                                |
| --------------------------- | ----------------------------------------- | ------------------------------- | ----------------------------------- |
| 自作共有skill               | `agents/skills/`                          | `agent-skills.nix`から両agentへ | 維持                                |
| 外部共有skill               | flake inputと`flake.lock`                 | 同上                            | forkやtransformが必要な箇所だけ管理 |
| Codex pluginの有効設定      | `codex.nix`の`enabledPlugins`             | profile共通config               | 維持                                |
| Claude pluginの有効設定     | `claude-code.nix`の`enabledPlugins`       | profile共通settings             | 維持                                |
| plugin cache・installed一覧 | 各profileのruntime                        | 製品が生成                      | 有効状態の正本にしない              |
| 共有instruction             | `agents/INSTRUCTIONS.md`と`agents/rules/` | Nixで結合                       | 常時必要な規則だけを配置            |

`agent-skills.nix`はcustom discoveryを`maxDepth = 1`にしている。
これはSwift routerをsymlinkした後で子skillを同じ場所へ生成する衝突を避ける設定であり、
単純に再帰depthを増やす変更はしない。

`video-editing`はsource内のbrew・pip導入例をNix配布時にtransformしている。
sourceだけの文字列検索で「実際の配布skillがglobal installを要求する」とは判定できない。
一方でsourceを直接読むagentには元の例が見えるため、将来sourceの説明を整理する余地はある。

## 自作skillの一覧

有効はNixの選択対象を指す。全ての依存が実機で動作済みという意味ではない。

| Skill                         | 配布 | 棚卸し上の論点                                                           |
| ----------------------------- | ---- | ------------------------------------------------------------------------ |
| `agent-browser`               | 有効 | YAML構文を修正。Browser UI専用の境界あり                                 |
| `baseline-ui`                 | 有効 | YAML構文を修正。Tailwind・motion等の固定条件が他design skillと競合し得る |
| `codex-app-screenshots`       | 有効 | Chrome MCP名への依存。生成bitmapとHTML screenshotの役割分けが必要        |
| `design-capture`              | 有効 | URL共有とデザイン評価を広く強制triggerに含む                             |
| `find-skills`                 | 有効 | unmanaged global installを避ける運用が明記済み                           |
| `forms-archive`               | 有効 | Forms保存に限定したtrigger。ログイン済みbrowserが必要                    |
| `idea-to-ship`                | 有効 | 大きなworkflow。既に得た承認を扱う条件と固定確認手順の整理候補           |
| `ios-device-build`            | 有効 | macOS・Xcode・実機が必要                                                 |
| `knowledge-extract`           | 有効 | vaultへの知識保存。session-documentationとの保存目的を区別               |
| `post-review`                 | 有効 | 共有review workflow。difitの明示opt-inとは役割が異なる                   |
| `project-init`                | 有効 | project flakeとagent runtime設定を分離する方針あり                       |
| `remotion-best-practices`     | 有効 | React動画のreference library。英語descriptionだけを理由に減点しない      |
| `session-documentation`       | 有効 | repo内の文書化。frontmatter・保存先が定義済み                            |
| `shipswift-add-component`     | 無効 | MCP未設定。YAML構文不正も残存                                            |
| `shipswift-build-feature`     | 無効 | MCP未設定。YAML構文不正も残存                                            |
| `shipswift-explore-recipes`   | 無効 | MCP未設定。YAML構文不正も残存                                            |
| `skill-auditor`               | 有効 | 今回discovery評価を修正                                                  |
| `skill-builder`               | 有効 | system skill-creatorと役割が重複。日英trigger必須など旧基準が残る        |
| `swift-dev-toolkit`           | 有効 | 6つのsub-skillへrouting。Xcode操作はmacOS依存                            |
| `vercel-react-best-practices` | 有効 | performance review。見た目のdesign skillと役割を区別                     |
| `video-editing`               | 有効 | Nix transformあり。sourceと配布後の差に注意                              |
| `web-design-guidelines`       | 有効 | 明示的UI review。外部guidelineの現行版を取得する設計                     |
| `x-article-publisher`         | 有効 | Claude専用Chrome MCP名への依存。下書きと公開の境界あり                   |
| `x-research`                  | 有効 | xAIの検索APIとcredentialが必要。今回API実行は未検証                      |

## 外部共有skillの一覧

17件を選択している。配布IDとfrontmatterの`name`が異なるものは対応を示す。

| Source                | 配布ID                                              | 主な境界                                       |
| --------------------- | --------------------------------------------------- | ---------------------------------------------- |
| Anthropic             | `pdf`・`xlsx`・`frontend-design`                    | Codexのdocument pluginや他design skillとの重複 |
| difit                 | `difit`・`difit-review`                             | viewerを開く明示依頼専用                       |
| App Store screenshots | `app-store-screenshots`                             | HTMLからexport可能なscreenshotを作る           |
| NotebookLM            | `notebooklm-skill` → `notebooklm`                   | ログイン済みNotebookLMへの問い合わせ           |
| Typst                 | `typst-author`・`touying-author`                    | 文書全般とTouying slide                        |
| Lottie                | `text-to-lottie`                                    | animation JSONとSkottie                        |
| taste                 | `taste-skill` → `design-taste-frontend`             | frontend全般のdesign方針                       |
| taste                 | `redesign-skill` → `redesign-existing-projects`     | 既存UIの改善                                   |
| taste                 | `output-skill` → `full-output-enforcement`          | 省略しないコード出力                           |
| taste                 | `image-to-code-skill` → `image-to-code`             | 先に画像を生成して実装するworkflow             |
| taste                 | `brandkit`                                          | brand board生成                                |
| taste                 | `imagegen-frontend-web`・`imagegen-frontend-mobile` | Web・mobileの画像concept生成                   |

今回の配布済み本文は`imagegen-frontend-mobile`が1465行、`image-to-code`が1228行、
`design-taste-frontend`が1206行、`imagegen-frontend-web`が987行、`brandkit`が798行だった。
本文は選択後に読むため、これらの総行数が常時contextに入るという意味ではない。
適用範囲が重なるskillを同時に選ぶと読む量が増えるため、まず入口の境界を整える。

## 優先課題

### 1. Frontmatterの構文不正

修正前は自作24件中5件で`Bun.YAML.parse`が失敗した。
plain scalarのdescription中に`Triggers: `や`日本語: `が含まれるためである。
有効な`agent-browser`と`baseline-ui`を`>-` block scalarへ変更し、parse成功と
修正前のdescription文字列の完全一致を確認した。

残りのShipSwift3件は無効なので今回変更していない。再有効化前に構文修正とMCP設定の両方が必要になる。
catalog上に見えることだけではYAMLとして正しいと判断できない。

### 2. 監査と作成workflowの基準

旧rubricはpushy description・日英trigger・任意metadataを上位点の条件にしていた。
これは能力と適用条件を短く明確にする現在のsystem `skill-creator`と衝突する。
今回Frontmatter次元と関連anti-patternを修正した。

- AP-3を日本語の有無から実測した呼び出し漏れ・誤起動の評価へ変更
- AP-4から文字数による機械的な曖昧判定を除去
- AP-5をallowed-toolsの一律必須から対象runtimeのtool依存確認へ変更
- 未実施のtrigger検証をSDK得点として推測しない規則を追加
- 未導入Claude pluginを必須にする監査skillの参照を修正

`skill-builder`の本文とvalidation scriptには日英triggerの必須扱いが残る。
次の変更ではdotfiles固有の配布知識を残し、system skill-creatorと重なる汎用手順や
固定の承認段階を減らす。今回の狭い修正でこの作成workflow全体を変更したとは扱わない。

rubricのStructure・Referencesには補助資産の数を重視する面も残る。
短いskillを不利にしない評価への見直しは次の独立した変更にする。

### 3. 同じ依頼に適用される候補が多い

| 依頼              | 重なる候補                                                      | 推奨する役割分け                                                    |
| ----------------- | --------------------------------------------------------------- | ------------------------------------------------------------------- |
| 新しいUIを作る    | frontend-design・taste・baseline-ui・image-to-code              | 通常のdesign方針と画像生成を伴うworkflowを区別                      |
| 既存UIを直す      | redesign・taste・web-design-guidelines・baseline-ui             | design変更とreview基準を区別                                        |
| PDFを作る・読む   | 共有pdf・Codex `pdf:pdf`                                        | Codexではpluginのartifact手順を基本候補にし共有版の利用条件を明確化 |
| 表計算fileを作る  | 共有xlsx・Codex spreadsheets                                    | file生成とlive Excel操作を区別                                      |
| Browserを操作する | agent-browser・Codex browser・chrome                            | UI操作の種類と利用中のsessionで選択                                 |
| screenshotを作る  | app-store-screenshots・codex-app-screenshots・画像concept skill | export可能なHTMLと生成bitmapを区別                                  |

これはdescriptionと一部本文の静的比較である。モデルの誤起動率やbodyの類似率は測っていない。
外部skillを全部forkする前に、実際の依頼で不要な同時適用が起きる組み合わせを確認する。
Codexだけにあるpluginを理由に共有pdf・xlsxを両agentから削除するとClaude側の能力も失う。

### 4. 共有配置と実行可能性の違い

`codex-app-screenshots`と`x-article-publisher`は本文中に`mcp__claude-in-chrome__*`を固定記載する。
現在の共有Browser方針は`agent-browser`優先であり、CodexのChrome pluginともtool名が一致しない。
browserの操作目的とDOM操作を共有し、製品ごとの呼び出し名だけをadapterとして分ける方針が適する。

Xcodeを使うskillをLinuxへ配布してもXcodeが実行可能になるわけではない。
Macへのdelegationやstatic reviewとして使うかを明記し、全OS共通の配布と実行対象OSを分けて扱う。

## Pluginとprofileの比較

### Codex

両profileのconfigは以下の10件をenabledとして宣言しており一致した。

`claude-code-advisor`・`google-calendar`・`github`・`browser-use`・`documents`・`pdf`・
`spreadsheets`・`presentations`・`browser`・`chrome`

cacheにはprimaryで24種、追加profileで20種のpluginとmarketplaceの組み合わせがあった。
追加profileには`figma`・`slack`、primaryには`gmail`等の差がある。
これはdownload済み資産の比較であり、現在の接続・有効状態の確定ではない。
`browser-use@openai-bundled`は宣言されているが、調査した両profileに同名cacheがなかった。
古いIDか未取得かはこの実測だけでは判別できないため、製品のplugin一覧で確認する項目として残す。

### Claude Code

3つのprofile全てで`antigravity@antigravity-for-claude-code`と`codex@openai-codex`の2件がenabledだった。
installed manifestはprimaryで33件、追加profileで2件と33件だった。
過去のfrontend・review・document plugin等が含まれるが、これを33件の有効pluginとは数えない。

profile間でcacheを丸ごと共有・同期する変更は行っていない。
認証やsessionを分離しながら宣言設定を共有する既存方針と整合している。

## 検証と次の手順

今回の変更では以下を確認した。

- `agent-browser`と`baseline-ui`の修正前parse失敗を再現
- 両skillの修正後parse成功とdescriptionの完全一致
- system `skill-creator/scripts/quick_validate.py`でskill-auditorの構造検証成功
- 変更した文書間のAP名とFrontmatter基準の整合
- `git diff --check`成功

Claude専用`trigger_smoke_test.sh`は今回実行していない。
このscriptはCLI失敗を無視してNOT_TRIGGEREDへ進むため、利用前にエラーと未発火を分離する必要がある。
file全体へのgrepでtool呼び出しを判定する点もstructured eventの判定へ直す候補である。

次はasset一覧の件数を減らすこと自体を目的にせず、以下の順で改善する。

1. skill-builderの作成基準を今回の監査基準に揃える
2. Browser依存の2つの共有workflowで製品固有tool名を分離する
3. design・PDF・表計算の代表的な依頼で選択結果を検証する
4. 実測した誤起動に応じてdescriptionか配布対象を狭める
5. plugin一覧からbrowser-useの宣言と実際の提供状況を照合する

## 同日の追加整理

上記の残課題のうち作成・監査の基準差とbrowser依存を整理した。

- skill-builderの本文・checklist・templateから固定trigger数と日英必須条件を除去
- 構成分類と監査基準から補助file数による加点・Simple skillの得点上限を除去
- validatorをBunのYAML parserへ変更し参照検査を追加
- コード例のlinkを参照fileとして扱わない回帰テストを追加
- Claude trigger adapterでstructured eventを読み成功・未発火・検証失敗を分離
- trigger adapterのテストはmockのみで実agentは起動していない
- browser依存の2skillから固定MCP名を除去し利用可能な操作と未対応時の手順を明示
- draft作成から無断で公開へ進まない境界を維持

共有PDF・xlsxはClaude側の入口でもあるためCodex側pluginとの類似だけを理由に削除しない。design系は通常実装・既存改善・review・画像基準の制作という用途を区別する。実際の選択率と外部browser UIの操作は未検証であり、全skillのruntime品質を保証する監査ではない。

参照: [Agent Platform運用ガイド](../agent-platforms.md)・
[既存Claude plugin棚卸し](../claude-plugin-audit.md)・
[skill配布定義](../../nix/home-manager/programs/agent-skills.nix)・
[監査rubric](../../agents/skills/skill-auditor/references/rubric.md)
