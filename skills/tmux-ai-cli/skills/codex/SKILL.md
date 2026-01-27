---
name: codex
description: "OpenAI Codex CLIを使用したコードレビュー、分析、コードベースへの質問を実行。使用場面: (1)コードレビュー、(2)コードベース分析、(3)実装質問、(4)バグ調査、(5)リファクタリング提案。トリガー: codex, コードレビュー, 分析して, /codex"
---

# Codex

Codex CLIを使用してコード分析・バグ調査を実行するスキル。

## 強み

- **GPT-5.2-codex**: コーディング特化モデル
- **/review**: 専用コードレビュー機能
- **Image Input**: スクリーンショット入力可能
- **Session Resume**: セッション継続

## 実行コマンド

```bash
codex exec --full-auto --sandbox read-only --cd <project_directory> "<request>"
```

## パラメータ

| パラメータ | 説明 |
|-----------|------|
| `--full-auto` | 完全自動モードで実行 |
| `--sandbox read-only` | 読み取り専用サンドボックス（安全な分析用） |
| `--cd <dir>` | 対象プロジェクトのディレクトリ |
| `"<request>"` | 依頼内容（日本語可） |

## 使用例

### コードベース分析

```bash
codex exec --full-auto --sandbox read-only --cd /path/to/project "このプロジェクトの構造を説明して"
```

### バグ調査

```bash
codex exec --full-auto --sandbox read-only --cd /path/to/project "認証処理でエラーが発生する原因を調査して"
```

### リファクタリング提案

```bash
codex exec --full-auto --sandbox read-only --cd /path/to/project "このコードのリファクタリング案を提示して"
```

## 実行手順

1. ユーザーから依頼内容を受け取る
2. 対象プロジェクトのディレクトリを特定する（通常は現在のワーキングディレクトリ）
3. 上記コマンド形式でCodexを実行
4. 結果をユーザーに報告

## 追加オプション

| オプション | 説明 |
|-----------|------|
| `--search` | Web検索を有効化 |
| `-i, --image` | 画像ファイルを添付 |
| `--add-dir` | 追加ディレクトリを指定 |
| `-m MODEL` | モデル指定 |
