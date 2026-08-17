---
name: skill-auditor
description: |
  Audit and evaluate skill quality in ~/dotfiles/agents/skills/.
  Scores skills on a 7-dimension rubric (structure, frontmatter, instructions, references, actionability, deduplication, SDK readiness).
  Detects anti-patterns: duplicates, inline bloat, missing JA triggers, vague descriptions.
  Two modes: portfolio audit (all skills) and single skill audit.
  Triggers: "audit skill", "evaluate skill", "skill quality", "skill review", "score skills"
  日本語: 「スキルを評価して」「スキル監査」「全スキルをチェック」「スキルのスコアを出して」「スキルレビュー」
---

# Skill Auditor

~/dotfiles/agents/skills/ 配下のスキル品質を定量評価し、改善提案を出す。

**作成は公式プラグイン** (`skill-creator@claude-plugins-official`, `document-skills@anthropic-agent-skills`) を使う。
このスキルは **監査に特化** している。

## モード選択

| モード          | トリガー                                     | 概要                       |
| --------------- | -------------------------------------------- | -------------------------- |
| Portfolio Audit | 「全スキルをチェック」「audit all」          | 全スキルを一括スコアリング |
| Single Audit    | 「{name} を評価して」「audit video-editing」 | 1スキルの詳細レビュー      |

引数なし or 「全スキル」 → Portfolio Audit
スキル名指定 → Single Audit

## Portfolio Audit ワークフロー

全スキルを rubric で採点し、サマリーテーブルを出力する。

### 手順

1. **発見**: `~/dotfiles/agents/skills/*/SKILL.md` を Glob で全て列挙
2. **構造確認**: 各スキルディレクトリの内容を ls で確認（references/, scripts/, templates/, skills/ の有無）
3. **読み込み**: 各 SKILL.md の frontmatter + body を Read で読む
4. **ルーブリック参照**: [references/rubric.md](references/rubric.md) を読み、7次元で各スキルを採点
5. **重複検出**: description のキーワード重複率を計算。body の内容が酷似するペアを報告
6. **Anti-Pattern 検出**: [references/anti-patterns.md](references/anti-patterns.md) と照合
7. **レポート出力**: rubric.md の「Portfolio Audit 出力フォーマット」に従ってテーブル出力

### 出力

```
## Portfolio Audit Report

| Skill                      | Str | Fmt | Ins | Ref | Act | Dup | SDK | Total | Grade      | Top Issue       |
| -------------------------- | --- | --- | --- | --- | --- | --- | --- | ----- | ---------- | --------------- |
| swift-dev-toolkit          | 5   | 5   | 5   | 5   | 5   | 5   | 4   | 33.0  | Excellent  | ...             |
| ...                        |     |     |     |     |     |     |     |       |            |                 |

## Duplicate Detection
- skill-a <-> skill-b: 95% overlap (同一内容)

## Anti-Patterns Found
- [AP-1] skill-a / skill-b: Near-Duplicate
- [AP-3] remotion-best-practices: Missing JA Triggers
- ...

## Improvement Priority (highest impact first)
1. ...
2. ...
```

### 採点の原則

- **客観的証拠** に基づいて採点する。「多分良い」ではなく「〜が存在する/しない」で判定
- **スキルタイプを考慮**: Simple スキルに Structure 5 は不要。[references/patterns.md](references/patterns.md) でタイプを判定し、そのタイプに見合った基準で採点
- **重み計算を間違えない**: Weighted Score = Raw Score x Weight。Instructions (1.5) と Actionability (1.5) は他より影響が大きい

## Single Skill Audit ワークフロー

1スキルを深掘りし、具体的な改善案を出す。

### 手順

1. **全ファイル読み込み**: 対象スキルの全ファイルを Read で読む（SKILL.md + references/ + scripts/ + templates/）
2. **タイプ判定**: [references/patterns.md](references/patterns.md) で最適なパターンを判定
3. **ルーブリック採点**: [references/rubric.md](references/rubric.md) の各次元で採点（証拠を記録）
4. **Anti-Pattern 検出**: [references/anti-patterns.md](references/anti-patterns.md) と照合
5. **改善案作成**: 各問題に対して具体的な修正方法と期待されるスコア改善を提示
6. **Smoke Test**: ユーザーが希望すれば `scripts/trigger_smoke_test.sh` でトリガー検証

### 出力

rubric.md の「Single Skill Audit 出力フォーマット」に従う。

### 改善案の書き方

- **具体的に**: 「frontmatter を改善する」ではなく「description に以下の JA triggers を追加: 「〜して」「〜を実行」」
- **期待効果を数値化**: 「(expected: +2 points on Frontmatter)」
- **優先度順**: 最もスコアが上がる改善から順に

## Trigger Smoke Test（オプション）

Single Audit 時、ユーザーが希望すれば trigger 検証を実行。

```bash
bash ~/dotfiles/agents/skills/skill-auditor/scripts/trigger_smoke_test.sh \
  "<test-prompt>" "<skill-name>"
```

結果:

- `TRIGGERED`: スキルが呼び出された
- `NOT_TRIGGERED`: スキルが呼び出されなかった
- `ERROR`: 検証に失敗（CLI バージョン差異等）

## 注意事項

- 採点は目安。スキルの「価値」はスコアだけでは測れない
- 外部プラグイン由来のスキル（remotion、vercel-react 等）は dotfiles 規約に完全に合致しなくてよい
- 本格的な eval（A/B比較、benchmark）が必要な場合は公式プラグイン `skill-creator@claude-plugins-official` を使う
