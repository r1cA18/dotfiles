---
name: skill-builder
description: |
  Create new skills, improve existing skills, and validate skill quality for ~/dotfiles/skills/.
  Interactive workflow: use-case discovery, architecture selection, SKILL.md generation, self-review, iteration.
  Generates dotfiles-native skills with Nix-aware paths, JA/EN triggers, progressive disclosure, and rubric-based self-scoring.
  Triggers: "create a skill", "new skill", "build a skill", "make a skill", "skill for X", "improve skill", "rewrite skill"
  日本語: 「スキルを作って」「新しいスキル作成」「スキルを改善して」「このスキルを書き直して」「スキル生成」
---

# Skill Creator

~/dotfiles/skills/ 配下に高品質なスキルを作成する対話的ワークフロー。

**監査は skill-auditor を使う。** このスキルは **作成と改善** に特化している。

## モード選択

| モード  | トリガー                               | 概要                              |
| ------- | -------------------------------------- | --------------------------------- |
| Create  | 「スキルを作って」「new skill」        | ゼロから新規スキルを作成          |
| Improve | 「スキルを改善して」「improve {name}」 | 既存スキルの description/構造改善 |
| Rewrite | 「書き直して」「rewrite {name}」       | 既存スキルの全面再設計            |

引数なし → Create モード（対話的にユースケースをヒアリング）
スキル名指定 → そのスキルの Improve/Rewrite

## Create ワークフロー

### Phase 1: Use-Case Discovery

ユーザーから具体的なユースケースを引き出す。最低2つのユースケースが必要。

質問の進め方（一度に2問まで）:

1. 「このスキルで何を実現したい？具体的なシナリオを1つ教えて」
2. 「他にどんな場面で使う？もう1つ例を」
3. 「ユーザーがこのスキルを呼び出すとき、どんな言葉で頼む？（日本語・英語両方）」

**必須情報の収集**:

- スキルの目的（何を自動化/支援するか）
- 具体的なユースケース 2-3 個
- トリガーフレーズ候補（JA/EN）
- 必要な外部ツール（MCP、CLI、API）
- 出力の形式（ファイル生成、コマンド実行、ドキュメント作成等）

Phase 1 完了条件: ユースケースが2つ以上明確になった。

### Phase 2: Architecture Selection

[references/architecture-patterns.md](references/architecture-patterns.md) を参照し、最適なアーキテクチャを提案する。

判断基準:

| 条件                          | パターン                    |
| ----------------------------- | --------------------------- |
| 独立した機能が3つ以上         | Type 1: Router + Sub-skills |
| 目的は1つ、ドメイン知識が必要 | Type 2: Single + References |
| ルール/パターンが10個以上     | Type 3: Reference Library   |
| 100行以下で書ける単純なスキル | Type 4: Simple              |

提案内容:

- 選択したパターンとその理由
- ディレクトリ構成案
- SKILL.md に入れる内容と references/ に分離する内容の仕分け
- 必要なスクリプト・テンプレートの一覧

ユーザーの承認を得てから次へ進む。

### Phase 3: Skill Generation

以下の順序でファイルを生成する:

1. **ディレクトリ作成**: `~/dotfiles/skills/{name}/`
2. **references/ と scripts/** を先に作成（これらを SKILL.md から参照するため）
3. **SKILL.md** を生成

#### SKILL.md 生成ルール

**Frontmatter**:

```yaml
---
name: { kebab-case, フォルダ名と一致 }
description: |
  {何をするか 1-2文}
  {主要な機能の列挙}
  Triggers: "{EN trigger 1}", "{EN trigger 2}", "{EN trigger 3}"
  日本語: 「{JA trigger 1}」「{JA trigger 2}」「{JA trigger 3}」
---
```

description のルール:

- 1024文字以内
- WHAT（何をするか）+ WHEN（いつ使うか）+ HOW（主要機能）を含む
- EN triggers と JA triggers の両方を含む
- XML タグ (< >) 禁止
- 曖昧な表現禁止（「helps with projects」のような）
- negative trigger を必要に応じて含める（「NOT for X」）

**Body の書き方**:

- 命令形（imperative form）で書く。「〜する」「〜を実行」
- 「あなたは」「you should」のような二人称は使わない
- SKILL.md body は 200行以下を目標（理想は 150行）
- 判断基準は表で整理する
- 重要な情報を先頭に配置する
- references/ へのリンクは `[file.md](references/file.md)` 形式
- 各セクションは ## で区切り、スキャンしやすくする

**Progressive Disclosure 3レベル**:

- Level 1: frontmatter (name + description) -- 常にコンテキストに存在
- Level 2: SKILL.md body -- スキル発動時に読み込み
- Level 3: references/, scripts/ -- 必要時のみ Read で参照

### Phase 4: Self-Review

生成したスキルを [references/quality-checklist.md](references/quality-checklist.md) で自己採点する。

採点結果をユーザーに提示:

```
## Self-Review: {skill-name}

| Check                    | Status | Note          |
| ------------------------ | ------ | ------------- |
| Frontmatter valid        | OK/NG  | ...           |
| JA triggers present      | OK/NG  | ...           |
| EN triggers present      | OK/NG  | ...           |
| WHAT + WHEN in desc      | OK/NG  | ...           |
| Body < 200 lines         | OK/NG  | {actual}行    |
| Imperative form          | OK/NG  | ...           |
| Progressive disclosure   | OK/NG  | ...           |
| No inline bloat          | OK/NG  | ...           |
| References linked        | OK/NG  | ...           |
| No duplicate with others | OK/NG  | ...           |

Estimated Grade: {Excellent/Good/Needs Work/Weak}
```

NG がある場合は自動修正してから提示する。

### Phase 5: Nix Integration

スキルが `~/dotfiles/skills/` に作成されたことを確認。
Nix (agent-skills-nix) 経由で Claude / Codex の両方に同期されるため、
`dr` の実行を促す。

ただし、symlink 構造上 `rules/` `agents/` `hooks/` と同様に即反映される可能性がある。
`agent-skill-path {name}` で反映を確認。

## Improve ワークフロー

1. 対象スキルの全ファイルを Read で読む
2. [references/quality-checklist.md](references/quality-checklist.md) で採点
3. 問題点を特定し、具体的な改善案を提示
4. ユーザーの承認後に修正を実行
5. 修正後に再採点

## Rewrite ワークフロー

1. 対象スキルの全ファイルを Read で読む
2. Phase 1 (Use-Case Discovery) からやり直す
3. 既存の良い部分は引き継ぐ
4. Create ワークフローの Phase 2-5 を実行

## 環境固有の注意事項

- スキルパス: `~/dotfiles/skills/{name}/SKILL.md`
- 言語: 日本語で記述（技術用語は英語）
- body の指示は命令形
- frontmatter の description は JA/EN 両方のトリガーを含む
- `allowed-tools` は最小権限で指定（不要なら省略可、ただしリスクを認識）
- 既存スキルとの重複を ~/dotfiles/skills/ 内で確認してから作成
