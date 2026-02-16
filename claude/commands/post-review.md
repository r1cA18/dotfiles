---
name: post-review
description: Codebase review and refactor loop. Runs review -> refactor -> re-review until clean.
---

# Post-Implementation Review

実装後のコードベースレビュー & リファクタループ。
問題がなくなるまで繰り返す。

## Workflow

以下のステップを繰り返し実行する。

### Step 1: Review (並列)

3つのレビューを並列で起動:

**Agent A: コードレビュー (Opus)**

- `git diff main...HEAD` または直近の変更を対象にレビュー
- バグ、ロジックエラー、セキュリティ問題、型の不整合を検出
- CLAUDE.md / プロジェクトルールへの違反をチェック
- 各問題に重要度を付与 (critical / warning / suggestion)

**Agent B: リファクタ分析 (Sonnet)**

- コードの簡素化・重複排除の機会を特定
- 不要なコメント、過剰な抽象化、AI臭いコードを検出
- 命名・構造の改善点を提案

**Agent C: Codex Review (Bash)**

- `codex review --base main` を実行（ブランチ差分がない場合は `codex review --uncommitted`）
- Codex CLI による独立した観点でのレビュー結果を取得
- 正確性、パフォーマンス、セキュリティ、保守性の観点

### Step 2: 問題の統合

3つのレビュー結果を統合し、以下の順で優先度付け:

1. critical (必ず修正)
2. warning (修正推奨)
3. suggestion (任意)

問題がゼロなら **Step 4** へスキップ。

### Step 3: 修正

検出された問題を修正する:

- critical と warning を自動修正
- suggestion はリストとして表示し、ユーザーに判断を委ねる
- 修正後、**Step 1** に戻って再レビュー

### Step 4: 完了

全ての critical / warning が解消されたら完了。
最終サマリーを表示:

- 修正した問題の一覧
- 残っている suggestion（あれば）
- レビューのイテレーション回数

## Rules

- 最大3イテレーションで打ち切り（無限ループ防止）
- 各イテレーションで修正した内容を記録
- テストが壊れる修正はしない
- 機能の変更はしない（リファクタのみ）
