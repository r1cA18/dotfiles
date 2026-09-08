---
name: skill-builder
description: |
  Create or improve reusable Agent Skills under ~/dotfiles/agents/skills/.
  Use when a request needs a new shared skill or a substantial rewrite; choose a fitting architecture, write SKILL.md and only necessary resources, and validate references and dependencies.
  Keep shared behavior portable across Claude and Codex. Use the system skill-creator for skills outside this repository and skill-auditor for an independent review.
  Example requests: "create a skill", "improve this skill", "rewrite the skill"; 日本語:「スキルを作って」「スキルを改善して」「書き直して」
---

# Skill Builder

`~/dotfiles/agents/skills/`に共有skillを作成または改善する。作成・改善の判断と実装を扱い、独立した品質監査は`skill-auditor`へ分ける。

## モード

| 依頼 | モード | 主な成果物 |
| --- | --- | --- |
| 新しいskillを作る | Create | 新しいディレクトリと必要な資産 |
| 既存skillを改善する | Improve | 目的を保った限定的な修正 |
| 既存skillを書き直す | Rewrite | ユースケースに合わせた再設計 |

対象がこのrepository外のCodex skillなら`.system/skill-creator`を使う。監査だけを求められた場合は`skill-auditor`を使う。

## 進め方

### 1. 依頼と適用範囲を確定する

- ユーザーが示した目的・成果物・対象agentを要件として抽出する
- 既存の依頼例がある場合はそれを優先し、例が足りない場合だけ判断に必要な質問をする
- ユースケース数や言語数を固定条件にしない。実装の境界が曖昧なときだけ、代表的な依頼と非該当の依頼を確認する
- `agents/skills/`内の関連skillと配布定義を読み、重複・製品固有依存・runtimeで使えるtoolを確認する
- 結果を変える重要な選択が未確定なら選択肢を確認する。依頼が明確な場合に形式的な承認段階を追加しない

### 2. 構成を選ぶ

[architecture-patterns.md](references/architecture-patterns.md)を読み、必要な知識・動作・依存に合う構成を選ぶ。

| 状況 | 構成 |
| --- | --- |
| 独立したworkflowを名前で振り分ける | Type 1: Router + Sub-skills |
| 目的は一つで詳細知識やhelperが必要 | Type 2: Single + References |
| 必要時に個別ルールを読む知識集 | Type 3: Reference Library |
| 小さく自己完結した目的 | Type 4: Simple |

ディレクトリの大きさや補助ファイル数を品質目標にしない。実際に参照・実行される資産だけを追加する。

### 3. 実装する

frontmatterの書式が必要なら[frontmatter-templates.md](references/frontmatter-templates.md)を参照する。

1. `agents/skills/{name}/`に作業対象を置く。新規作成では必要な`references/`・`scripts/`・`templates/`だけを先に用意する
2. `SKILL.md`のfrontmatterをYAMLとして記述し、`name`と`description`を必ず含める
3. descriptionには能力と適用条件を短く書く。関連skillとの境界が必要な場合だけ除外条件を加える
4. 呼び出し例は実際の利用者が使う言語と表現から選ぶ。英語・日本語や個数を必須化せず、曖昧な依頼を減らす情報を残す
5. bodyには目的・判断基準・実行手順・失敗時の扱いを命令形で書く。詳細なdomain knowledgeは必要なreferenceへ移す
6. 依存するMCP・CLI・OS・credentialを明記し、対象agentで利用できない場合の条件付きfallbackを用意する
7. `agents/`やproduct固有のtool名を共有本文へ固定しない。adapterが必要なら対象product側で解決する
8. global installやsystem変更をskillの既定手順にしない。repositoryのpackage管理とユーザーの承認範囲に従う

### 4. 検証する

次のvalidatorで構文とローカル参照を確認する。

```bash
bash ~/dotfiles/agents/skills/skill-builder/scripts/validate-skill.sh \
  ~/dotfiles/agents/skills/{name}
```

- validatorのerrorを修正する。warningはnameと配布IDの対応など事実を確認して判断する
- 追加したscriptは実行可能性を依存が利用できる環境で確認する。利用できない依存は未検証として記録する
- 参照linkの解決・placeholder・対象agentのtool依存を確認する
- triggerを評価する場合は対象agentで該当依頼と非該当依頼を実行し、prompt・agent・結果・未検証事項を記録する。descriptionの語数だけで呼び出し品質を保証しない

### 5. 自己レビューする

[quality-checklist.md](references/quality-checklist.md)を使い、数値gradeではなく証拠付きの判定を残す。

| 観点 | 記録する内容 |
| --- | --- |
| Format | frontmatter・name・参照先の検証結果 |
| Intent | 目的・適用範囲・非該当範囲の根拠 |
| Behavior | agentが実行できる手順と失敗時の扱い |
| Dependencies | tool・OS・credential・fallbackの確認状況 |
| Maintenance | 構成の妥当性と重複の有無 |
| Discovery | 実測したprompt・対象agent・結果。未実施は未評価 |

必須形式が壊れている場合は修正してから結果を返す。意図や権限が変わる修正は勝手に広げず、必要な確認を求める。

## Progressive disclosure

- Level 1: frontmatterには選択に必要な能力と適用条件だけを書く
- Level 2: `SKILL.md`には共有workflowと判断基準を書く
- Level 3: 条件付きの知識は`references/`へ分け、使う段階で該当ファイルだけ読む

各referenceは`SKILL.md`から相対linkで参照する。単純なskillに不要なreferenceやrouterを追加しない。

## dotfilesへの反映

共有skillの正本は`agents/skills/`であり、`agent-skills.nix`の有効化対象を確認する。ClaudeとCodexへのruntime同期はNixの配布機構が担当する。

`dr`やsystem applyはこのworkflowから自動実行しない。必要な反映コマンドと、runtime同期・実agent発火をまだ確認していない場合はその事実を報告する。
