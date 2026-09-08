# Skill Quality Checklist

作成または改善したskillを、固定の文字数・trigger数・言語数で採点せずに確認する。判定は対象skillの目的と対象agentに対する証拠で行う。

## Release gates

次のformat gateに失敗した場合はリリースせず修正する。

| 確認 | 合格条件 | 証拠 |
| --- | --- | --- |
| Frontmatter | YAMLとしてparseでき、`name`と`description`が存在する | validatorの結果 |
| Name | kebab-caseで識別でき、フォルダ名や配布IDとの対応を説明できる | pathと配布定義 |
| Description | 能力と適用条件が読み取れ、必要なら境界も分かる | description本文 |
| Portability limit | 対象runtimeが受け付けるdescriptionの上限を超えない | validatorの結果 |
| Local links | `SKILL.md`から参照するrepository内fileが存在する | validatorの結果 |
| Unfinished work | TODOや仮のplaceholderを成果物として残していない | 差分と検索結果 |

上限値はformat compatibilityのための検査であり、短いdescriptionや長いbodyを品質点へ機械的に変換しない。

## Intent and discovery

- ユーザーの目的とskillの成果物が一致している
- descriptionから、使う依頼と使わない依頼の境界を必要な範囲で判断できる
- 呼び出し例は実際の利用者の表現を補助する。英語・日本語の両方や一定個数を必須条件にしない
- 日本語または英語での呼び出し漏れ・誤起動を問題にする場合は、対象agentで実測したpromptと結果を記録する
- 類似skillのdescriptionやbodyと役割が重なる場合は、統合・境界・配布対象の判断を記録する

triggerの静的な語数や`Triggers:`という見出しの有無だけでdiscoveryを保証しない。未実施のruntime検証は未評価と記録する。

## Behavior and actionability

- bodyに、入力・判断・操作・成果物が実行可能な形で書かれている
- workflowの順序を固定する理由がある場合だけ順序を明記している
- 失敗・不足権限・未対応OS・未接続toolに遭遇したときの停止条件またはfallbackがある
- 外部toolを使う場合は、必須依存・任意依存・代替手段・副作用を区別している
- agentへ実装を指示する本文は命令形で、不要な一般論や二人称の説明を含めていない
- `SKILL.md`に必要な判断を残し、条件付きの詳細は関連referenceだけへ分離している

knowledge提供が目的のskillでは、実行scriptがないことを欠陥としない。実行workflowが目的なら、例示だけでなく実際に使える手順または検証済みhelperを用意する。

## Structure and progressive disclosure

- architectureは必要な知識・動作・依存に対して過不足がない
- `references/`・`scripts/`・`templates/`は実際のworkflowから参照され、存在だけを目的に追加されていない
- referenceを使う場合は`SKILL.md`から相対linkし、使う段階で該当fileだけ読むよう案内している
- `SKILL.md`とreferenceの重複を避け、更新時に片方だけが古くならない構成になっている
- bodyの行数はcontext効率を確認する手がかりに留め、固定の合格ラインにしない

## Cross-agent dependencies

| 項目 | 確認内容 |
| --- | --- |
| Agent | Claude・Codexなど対象agentと配布先を明記する |
| Tool | 実際に提供されるtool名・CLI・MCPを確認する |
| OS | macOS・Linuxなど実行可能な環境を区別する |
| Credential | login・secret・session stateの前提を明記し、repoへ保存しない |
| Product boundary | 製品固有の登録・UI・adapterを共有本文から分離する |
| Install policy | global installやsystem applyを既定手順にしない |

対象agentで依存を実行できない場合は、静的確認済みとruntime未検証を分けて記録する。optional frontmatterや`allowed-tools`の有無だけで合否を決めない。

## Verification record

次の表を埋め、実施していない確認は`未検証`と書く。

| 項目 | 判定 | 根拠 |
| --- | --- | --- |
| Format | `OK` / `要修正` | validatorの出力 |
| Intent | `OK` / `要修正` / `未評価` | 対象依頼と境界 |
| Behavior | `OK` / `要修正` / `未評価` | 手順・fixture・実行結果 |
| Dependencies | `OK` / `要修正` / `未検証` | tool・OS・credential |
| Structure | `OK` / `要修正` | patternとlink |
| Discovery | `OK` / `要修正` / `未検証` | agent・prompt・結果 |
| Duplication | `OK` / `要整理` / `候補` | 比較対象と根拠 |

判定は`Ready`・`Revise`・`Blocked by evidence`のいずれかでまとめる。数値scoreや総合gradeを、実際の動作確認の代わりに使わない。

## Common corrections

- descriptionが曖昧なら対象成果物と適用条件を具体化する
- 競合するskillがあるなら、descriptionの境界を狭めるか統合の要否を検討する
- referenceが未リンクなら`SKILL.md`に利用条件付きの相対linkを追加する
- script依存が対象agentにないなら、条件付きfallbackを記載するか依存を配布定義へ追加する
- 未検証のtrigger結果を`未検証`として残し、語数や言語数を増やして代用しない
