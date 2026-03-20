---
name: post-review
description: Run a post-implementation review and cleanup loop after coding work. Use when validating recent changes, checking diffs, fixing review findings, and tightening code quality before wrapping up.
---

# Post Review

実装後にレビューと修正を回して、変更を締めるための shared skill。
`Claude Code` の command に閉じず、`Codex` でも同じ流れで使えるようにする。

## When to use

- 実装直後に diff を見直したいとき
- バグ、型の不整合、設計の粗さを潰してから終わりたいとき
- 変更を review -> fix -> verify の順で締めたいとき

## Goals

- recent diff を対象にレビューする
- critical / warning / suggestion を分ける
- critical / warning はできるだけ解消する
- 修正後に再レビューして、残課題を明示する

## Workflow

1. 対象差分を決める
   - branch diff があるなら `main...HEAD`
   - ないなら uncommitted changes
2. 複数観点でレビューする
   - correctness
   - security
   - performance
   - maintainability
   - project rule compliance
3. 指摘を統合する
   - `critical`: バグ、壊れる変更、危険な変更
   - `warning`: 直した方がいい問題
   - `suggestion`: 任意の改善
4. `critical` と `warning` を修正する
5. テストやビルドを再実行する
6. 再レビューする
7. 最終的に以下を共有する
   - 修正した問題
   - 残した suggestion
   - 未検証項目

## Review sources

- built-in review capability があるなら使う
- `codex review` が使えるなら diff review に使う
- project の tests / build / lint を verification として使う
- 必要なら subagent / parallel review を使う

## Rules

- 最大 3 イテレーションで打ち切る
- 機能変更ではなく review 起点の修正を優先する
- テストがあるなら変更前後で結果を確認する
- 検証していない項目は必ず明示する
