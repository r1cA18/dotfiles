---
name: gemini
description: "Google Gemini CLIを使用した調査、Web検索、コードベース分析を実行。使用場面: (1)最新情報調査、(2)Web検索リサーチ、(3)ドキュメント・API調査、(4)大規模コンテキスト分析。トリガー: gemini, 調査して, 検索して, リサーチ, /gemini"
---

# Gemini

Gemini CLIを使用して調査・リサーチを実行するスキル。

## 強み

- **Google Search Grounding**: リアルタイムWeb検索が組み込み
- **1Mトークンコンテキスト**: 大規模コードベース分析に最適
- **無料tier**: 1日1000リクエストまで無料

## 実行コマンド

```bash
gemini -y "<request>"
```

## パラメータ

| パラメータ | 説明 |
|-----------|------|
| `-y` | 自動承認モード（YOLO） |
| `"<request>"` | 依頼内容（日本語可） |

## 使用例

### 最新情報の調査

```bash
gemini -y "TypeScript 5.5の新機能を調べて"
```

### ドキュメント調査

```bash
gemini -y "Next.js 15のApp Routerの使い方を調べて"
```

### 技術比較

```bash
gemini -y "GraphQL vs REST APIの違いを2025年の観点から比較して"
```

## 実行手順

1. ユーザーから調査依頼を受け取る
2. 上記コマンド形式でGeminiを実行
3. 結果をユーザーに報告

## 追加オプション

| オプション | 説明 |
|-----------|------|
| `-r, --resume` | 前のセッションを再開 |
| `-m MODEL` | モデル指定 |
| `-s, --sandbox` | サンドボックスモード |
| `-o, --output-format` | 出力形式 (text/json/stream-json) |
