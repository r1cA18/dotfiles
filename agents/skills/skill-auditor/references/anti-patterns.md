# Skill Anti-Patterns

既存スキルの分析から抽出した問題パターン。
audit 時にこのリストと照合して問題を検出する。

---

## AP-1: Near-Duplicate Skills

同一または酷似した内容の複数スキルが存在する。

**症状**: 2つのスキルの SKILL.md body がほぼ同じ内容。
**リスク**: トリガーの競合、メンテナンスコスト倍増。
**検出**: description + body のキーワード重複率が 70% 以上。
**修正**: 片方を削除、または統合して1つにする。

**実例**: `baseline-ui` と `ui-skills` が同一の 45 ルールを持つ。

---

## AP-2: Inline Bloat

SKILL.md に本来 references/ に分離すべき詳細情報が全てインラインで書かれている。

**症状**: SKILL.md が 300行以上。コマンドリファレンスやルール一覧がインライン展開。
**リスク**: context window の浪費。progressive disclosure が効かない。
**検出**: SKILL.md の行数が 300行超、かつ references/ ディレクトリが存在しない。
**修正**: 詳細部分を references/ に分離し、SKILL.md からリンクする。

**目安**:

- SKILL.md body: 500行以下（理想は 200行以下）
- 各 reference ファイル: 300行以下（超える場合は TOC 必須）

---

## AP-3: Missing JA Triggers

description に日本語トリガーフレーズがない。

**症状**: description が英語のみ。日本語で指示しても skill が呼ばれない。
**リスク**: 日本語ユーザーがスキルを活用できない。
**検出**: description 内に日本語文字列がない。
**修正**: 「〜して」「〜を実行」形式の日本語トリガーを追加。

**影響が大きいケース**: 外部から導入したスキル（remotion、vercel-react 等）。

---

## AP-4: Vague Description

description が「何をするか」だけで「いつ使うか」を説明しない。

**症状**: "Security check skill" のような1行 description。
**リスク**: エージェントがスキルを使うべき場面を判断できない。
**検出**: description が 50文字未満、または "when" の文脈がない。
**修正**: "Use when..." / "Triggers:" を追加。具体的なユーザーフレーズを含める。

**悪い例**: `description: Security check skill`
**良い例**: `description: |`
`Security analysis for codebases. Scans for vulnerabilities, secrets, and common security issues.`
`Triggers: "security check", "vulnerability scan", "find secrets"`
`日本語: 「セキュリティチェック」「脆弱性を確認」「秘密鍵が漏れてないか確認」`

---

## AP-5: Missing allowed-tools

allowed-tools が未指定で、不要なツールにアクセスできる状態。

**症状**: frontmatter に allowed-tools がない。
**リスク**: スキルが意図しないツール（Write、Bash 等）を使用する可能性。
**検出**: frontmatter に allowed-tools フィールドがない。
**修正**: 最小権限の原則で必要なツールのみ指定。

**注意**: 全ツールが必要な場合は意図的な省略として許容。
ただし、参照のみのスキル（reference-library）は Read, Glob, Grep に制限すべき。

---

## AP-6: No Progressive Disclosure

全ての情報を SKILL.md に一度に詰め込み、段階的な情報開示がない。

**症状**: SKILL.md が長大。references/ があっても SKILL.md から参照されていない。
**リスク**: スキル呼び出し時に不要な情報で context を消費。
**検出**: SKILL.md 内に references/ へのリンクがない。または references/ が空。
**修正**: 3レベルの progressive disclosure を実装:

- Level 1: frontmatter（name + description）-- 常にコンテキストに存在
- Level 2: SKILL.md body -- スキル発動時に読み込み
- Level 3: references/ -- 必要時のみ Read で参照

---

## AP-7: Demo Quality

プロダクション用ではなく、概念実証/デモ目的のスキルが残っている。

**症状**: 実装が最小限。実用シナリオが想定されていない。
**リスク**: スキル一覧のノイズになる。トリガー競合の可能性。
**検出**: SKILL.md の instructions が 20行未満、かつ具体的なワークフローがない。
**修正**: 本格実装するか、削除する。

---

## AP-8: Stale External References

外部 URL やリソースに依存しており、変更/消失のリスクがある。

**症状**: SKILL.md 内で WebFetch で外部 URL から最新情報を取得する設計。
**リスク**: URL 変更で機能停止。ネットワーク依存。レイテンシ増加。
**検出**: SKILL.md 内に外部 URL への WebFetch 指示がある。
**修正**: 重要な内容は references/ にスナップショットとして保存。
定期的に更新する仕組み（バージョン管理）を検討。

---

## 検出優先度

audit 時の検出優先度（影響の大きさ順）:

1. **AP-1** Near-Duplicate（即座に修正可能、メンテコスト削減）
2. **AP-4** Vague Description（トリガー精度に直結）
3. **AP-3** Missing JA Triggers（日本語環境での利用に直結）
4. **AP-2** Inline Bloat（context window 効率に影響）
5. **AP-6** No Progressive Disclosure（context 効率）
6. **AP-5** Missing allowed-tools（セキュリティ）
7. **AP-7** Demo Quality（ノイズ削減）
8. **AP-8** Stale External References（安定性）
