---
name: autonomous-dev
description: "自律的に実装を完了するワークフロー。要件整理→プランニング→TDD→レビュー→マージまで自動実行。トリガー: 「自律的に実装して」「autonomous devで進めて」「/autonomous-dev」"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Task
user-invocable: true
---

# Autonomous Development Workflow

自律的に実装を完了するためのワークフロースキル。

## トリガー

- 「自律的に実装して」
- 「autonomous devで進めて」
- 「実装まで全部やって」
- 「/autonomous-dev」

## 概要

要件整理からテスト・レビュー・マージまでを自律的に実行する。

## ワークフロー

### Phase 0: 要件整理

1. ユーザーの要求を分析
2. `docs/REQUIREMENTS.md` を作成
3. 不明点があれば質問

```markdown
# Requirements

## 目的
[何を達成したいか]

## 機能要件
- [ ] 要件1
- [ ] 要件2

## 非機能要件
- パフォーマンス
- セキュリティ

## 制約
- 技術スタック
- 既存コードとの整合性
```

### Phase 1: プランニング

1. 実装計画を立てる
2. フェーズに分割（各フェーズは独立してテスト可能な単位）
3. `docs/PLAN.md` を作成

```markdown
# Implementation Plan

## Phase 1: [フェーズ名]
- 目標:
- ブランチ: feature/phase-1-xxx
- タスク:
  - [ ] タスク1
  - [ ] タスク2
- 完了条件:

## Phase 2: [フェーズ名]
...
```

### Phase 2-N: 実装フェーズ（各フェーズで繰り返し）

#### Step 1: ブランチ作成
```bash
git checkout -b feature/phase-N-description
```

#### Step 2: テスト作成（TDD）
- 実装前にテストを書く
- 失敗することを確認

#### Step 3: 実装
- テストが通るように実装
- 小さなコミットを心がける

#### Step 4: セルフレビュー
```bash
codex review --uncommitted
```
- 指摘事項を修正
- 再度レビュー

#### Step 5: レビューループ
```
while (codex review に指摘がある):
    修正
    codex review
```

#### Step 6: マージ
```bash
git checkout main
git merge feature/phase-N-description
git branch -d feature/phase-N-description
```

### Final Phase: 完了処理

1. **統合テスト**: 全体が正しく動作するか確認
2. **ユーザーテスト**: 実際の使用シナリオでテスト
3. **ドキュメント作成**:
   - `docs/DEVELOPMENT_NOTES.md` - 開発中の知見
   - README更新（必要に応じて）

## コマンド

### フル実行
```
「自律的に実装して: [要件の説明]」
```

### 途中から再開
```
「Phase 2から再開して」
```

### 特定フェーズのみ
```
「Phase 1だけ実装して」
```

## 言語/フレームワーク固有のテスト

プロジェクトに応じて適切なテスト方法を選択:

| 言語/FW | テストコマンド | 備考 |
|---------|---------------|------|
| Swift/iOS | `xcodebuild test` | swift-dev-toolkitスキル参照 |
| TypeScript | `npm test` / `bun test` | |
| Python | `pytest` | |
| Rust | `cargo test` | |
| Go | `go test ./...` | |

## 中断時の対応

作業が中断された場合:
1. 現在の状態をコミット
2. `docs/PROGRESS.md` に進捗を記録
3. 次回は「続きから」で再開可能

## 注意事項

- 各フェーズは独立してテスト可能な単位にする
- 大きすぎるフェーズは分割する
- レビューで同じ指摘が3回続いたら、根本的なアプローチを見直す
- ユーザーに確認が必要な場合は必ず質問する
