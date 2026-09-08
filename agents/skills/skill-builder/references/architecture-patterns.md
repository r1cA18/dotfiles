# Skill Architecture Patterns

skillの目的・必要な知識・実行動作・runtime依存を見て構成を選ぶ。ファイル数やbodyの行数を目標にしない。

## パターン選択

```text
workflowを独立した名前で振り分けるか
|-- yes -> Type 1: Router + Sub-skills
|-- no
    |-- 条件付きのdomain knowledge・helper・templateが必要か
    |   |-- yes -> Type 2: Single + References
    |   +-- no
    |-- 独立したルールを必要時に検索する知識集か
    |   |-- yes -> Type 3: Reference Library
    |   +-- no -> Type 4: Simple
```

複数の動作があるだけでrouterにしない。ユーザーが機能を個別に指定し、各機能に異なる判断や資産がある場合にだけ分割する。

## Type 1: Router + Sub-skills

複数の独立したworkflowを一つの入口から振り分けるtoolkit型。

```text
skill-name/
|-- SKILL.md              # 振り分け条件と共有方針
|-- skills/
|   |-- sub1/SKILL.md
|   |-- sub2/SKILL.md
|   +-- sub3/SKILL.md
|-- scripts/              # 複数sub-skillで共有するhelperだけ
|-- templates/            # 複数sub-skillで共有するtemplateだけ
+-- references/           # 複数sub-skillで共有する知識だけ
```

rootのSKILL.mdに次を含める。

1. sub-skillの名前・用途・呼び出し条件の表
2. 依頼の語句や成果物からのrouting条件
3. shared script・template・referenceの利用条件
4. sub-skillへ渡す入力と、重複する場合の優先順

sub-skillの説明はrootと重複させず、それぞれの判断と実行に必要な内容だけを書く。

## Type 2: Single Skill + References

目的は一つだが、条件付きのdomain knowledgeや実行helperを持つworkflow型。

```text
skill-name/
|-- SKILL.md              # 目的・判断・基本workflow
|-- references/
|   |-- domain-guide.md
|   +-- troubleshooting.md
|-- scripts/              # 繰り返す処理や決定的な検査
+-- templates/            # 生成物の再利用可能な雛形
```

SKILL.mdには最初に必要な判断と最小workflowを残す。format別・provider別・失敗時の詳細は利用条件を示してreferenceへ分ける。helperやtemplateがない場合に、見栄えのためだけに空のdirectoryを追加しない。

## Type 3: Reference Library

独立したルールやパターンを必要時に読む知識ベース型。

```text
skill-name/
|-- SKILL.md              # indexと適用条件
+-- rules/
    |-- category-rule.md
    +-- another-rule.md
```

SKILL.mdにruleのカテゴリ・適用条件・linkを載せる。「全ruleを読む」とは指示せず、依頼に関係するruleだけを読むようにする。新規ruleを追加したらindexも更新する。

## Type 4: Simple

外部domain knowledgeや複雑なroutingを必要としない単一目的型。

```text
skill-name/
+-- SKILL.md
```

本文だけで入力・実行・成果物・失敗時の判断が分かるようにする。frontmatterのdescriptionは適用範囲を明確にするために使い、固定のtrigger数や言語数を埋め込まない。

## Body workflow patterns

アーキテクチャとは別に、実行の形を選ぶ。

| 状況 | workflow pattern |
| --- | --- |
| 前段の成果物が後段の入力になる | Sequential Workflow Orchestration |
| 複数のMCPやserviceを組み合わせる | Multi-MCP Coordination |
| 品質確認と修正を繰り返す | Iterative Refinement |
| 同じ目的に複数toolがある | Context-Aware Tool Selection |
| 規制・監査・domain固有の判断が必要 | Domain-Specific Intelligence |

必要なpatternだけを採用し、一般的な手順を全skillへコピーしない。固定順序や絶対的な制約は、逸脱すると具体的な失敗が起きる場合に限定する。

## 選択時の確認

- ユーザーがどの成果物を求めているか
- 条件によって読む知識が変わるか
- 繰り返す処理をscriptにする実益があるか
- product・OS・MCP依存を共有入口で解決できるか
- 既存skillと統合または明確な境界を作れるか
- 実装後にreference・script・配布先を検証できるか
