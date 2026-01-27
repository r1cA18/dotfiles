---
name: codex-review
description: "Codex CLIの/reviewコマンドでコードレビューを実行。使用場面: (1)PRレビュー、(2)未コミット変更レビュー、(3)ブランチ差分レビュー、(4)セキュリティ・品質チェック。トリガー: codex-review, /codex-review, cr"
---

# Codex Review

Codex CLIの`/review`コマンドを使用してコードレビューを実行するスキル。

## 強み

- **Diff分析**: 変更差分を自動解析
- **優先度付き指摘**: 重要度順にフィードバック
- **ブランチ比較**: PR前のレビューに最適
- **ワークツリー非変更**: 読み取り専用で安全

## 実行コマンド

### 未コミット変更のレビュー

```bash
codex review --uncommitted
```

### ブランチ比較レビュー

```bash
codex review --base <branch>
```

### 特定コミットのレビュー

```bash
codex review --commit <sha>
```

### カスタム指示付きレビュー

```bash
codex review "<custom_instruction>"
```

## パラメータ

| パラメータ | 説明 |
|-----------|------|
| `--uncommitted` | 未コミット変更（staged + unstaged + untracked）をレビュー |
| `--base <branch>` | 指定ブランチとの差分をレビュー |
| `--commit <sha>` | 特定コミットの変更をレビュー |
| `"<instruction>"` | カスタムレビュー指示（例: "セキュリティ重視"） |

## 使用例

### PR作成前のレビュー

```bash
codex review --base main
```

### セキュリティ重視のレビュー

```bash
codex review --uncommitted "セキュリティの脆弱性に注目してレビューして"
```

### 最新コミットのレビュー

```bash
codex review --commit HEAD
```

## 実行手順

1. ユーザーからレビュー依頼を受け取る
2. レビュー対象を特定する
   - 未コミット変更 → `--uncommitted`
   - ブランチ差分 → `--base <branch>`
   - 特定コミット → `--commit <sha>`
3. 上記コマンド形式でCodex reviewを実行
4. レビュー結果をユーザーに報告

## レビュー観点

Codex reviewは以下の観点でコードをチェック:

- **正確性**: ロジックエラー、バグ
- **パフォーマンス**: 非効率なコード
- **セキュリティ**: 脆弱性、インジェクション
- **保守性**: 可読性、複雑度
- **DX**: 開発者体験
