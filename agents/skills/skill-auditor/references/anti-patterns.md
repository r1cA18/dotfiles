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

**例**: 旧版と新版のskillを両方有効化し、同じruleが重複している。

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

## AP-3: Discovery Mismatch

descriptionの適用範囲と実際の呼び出しが一致しない。

**症状**: 該当する依頼で呼ばれない。または非該当の依頼にも適用される。
**リスク**: 必要なworkflowの欠落や無関係な指示の混入。
**検出**: 対象agentで該当・非該当の依頼を検証する。未実施の場合は候補として記録する。
**修正**: 能力と適用条件を簡潔にし、誤起動を招く条件を絞る。

英語のみという理由では問題扱いしない。日本語の呼び出し漏れを実測した場合に、
意味の曖昧さを解消する日本語の用例を検討する。強制文言やtriggerの数を増やすことを目的にしない。

---

## AP-4: Vague Description

description が「何をするか」だけで「いつ使うか」を説明しない。

**症状**: "Security check skill" のような1行 description。
**リスク**: エージェントがスキルを使うべき場面を判断できない。
**検出**: descriptionから能力または適用条件を判断できない。文字数や特定語句の有無だけで判定しない。
**修正**: 対象とする依頼や成果物を明記する。

**悪い例**: `description: Security check skill`
**良い例**: `description: Review a codebase for vulnerabilities when the user requests a security audit.`

---

## AP-5: Unsupported Tool Assumptions

対象agentが提供しないtoolやmetadataの効果を前提にしている。

**症状**: 共有skillが特定製品のtool名に固定され、利用可能性を確認しない。
**リスク**: 他agentで実行できない。metadataだけで権限が制御されると誤認する。
**検出**: 必須toolと対象環境の対応を照合する。
**修正**: 必須依存を明記し、利用可能な代替手段を条件付きで示す。

allowed-tools等の任意fieldは対応する製品でのみ評価する。省略を一律の欠陥とせず、
実際の権限は対象runtimeの設定と承認範囲で判断する。

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
3. **AP-3** Discovery Mismatch（呼び出し漏れ・誤起動）
4. **AP-2** Inline Bloat（context window 効率に影響）
5. **AP-6** No Progressive Disclosure（context 効率）
6. **AP-5** Unsupported Tool Assumptions（実行可能性）
7. **AP-7** Demo Quality（ノイズ削減）
8. **AP-8** Stale External References（安定性）
