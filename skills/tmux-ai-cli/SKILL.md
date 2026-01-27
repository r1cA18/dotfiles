---
name: tmux-ai-cli
description: "Claude CodeからGemini CLIとCodex CLIをオーケストレーションするスキル。tmuxセッションで両CLIを並列実行し、タスクに応じて使い分ける。調査タスクはGemini（Google Search）、コードレビューはCodex（/review）が得意。トリガー: tmux, ai-cli, オーケストレーション, /tmux-ai-cli"
---

# Tmux AI CLI

Claude CodeをオーケストレーターとしてGemini CLIとCodex CLIを使い分けるスキル。

## オーケストレーション戦略

```
┌─────────────────────────────────────────────────────────────┐
│                    Claude Code (Orchestrator)                │
│         タスク分析 → 適切なCLIに振り分け → 結果統合          │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│      Gemini CLI         │     │       Codex CLI         │
│ ・調査 (Google Search)  │     │ ・コードレビュー (/review)│
│ ・最新情報リサーチ      │     │ ・リファクタリング確認   │
│ ・ドキュメント調査      │     │ ・バグ分析              │
│ ・大規模コンテキスト    │     │ ・非インタラクティブ実行  │
└─────────────────────────┘     └─────────────────────────┘
```

## 使い分けガイド

| タスク | 推奨CLI | 理由 |
|--------|---------|------|
| 最新情報の調査 | Gemini | Google Search Grounding |
| API/ドキュメント調査 | Gemini | Web検索 + 大規模コンテキスト |
| コードレビュー | Codex | /review コマンド |
| バグ分析 | Codex | コード特化モデル |
| リファクタ確認 | Codex | /review --uncommitted |
| 技術比較 | 両方 | 複数視点で比較 |

## Quick Start

```bash
# セッション起動（左右分割表示）
./scripts/start_session.sh --auto-approve

# tmuxでアタッチして確認
tmux attach -t ai-cli

# Geminiで調査
./scripts/chat.sh gemini "React 19の新機能を調べて" 30

# Codexでレビュー
./scripts/codex_review.sh --uncommitted

# 両方に送信して比較
./scripts/send_to_both.sh "このコードを説明して" --wait 25
```

## スクリプト一覧

### セッション管理
| スクリプト | 説明 |
|-----------|------|
| `start_session.sh` | tmuxセッション起動（左右分割） |
| `session.sh` | セッション管理（status/kill/attach） |

### チャット
| スクリプト | 説明 |
|-----------|------|
| `chat.sh` | 指定CLIにプロンプト送信 |
| `send_to_both.sh` | 両方に同じプロンプト送信 |
| `capture_output.sh` | 出力をキャプチャ |

### 非インタラクティブ実行
| スクリプト | 説明 |
|-----------|------|
| `gemini_exec.sh` | Gemini非インタラクティブ実行 |
| `codex_exec.sh` | Codex非インタラクティブ実行 |
| `codex_review.sh` | Codex /review ラッパー |

## Gemini CLI

Google Search Groundingを活用した調査が得意。

```bash
# 非インタラクティブ実行
./scripts/gemini_exec.sh "TypeScript 5.5の新機能を調べて"

# インタラクティブ（tmux内）
./scripts/chat.sh gemini "Next.js 15のApp Routerについて" 30
```

**主要オプション:** `-y` (自動承認), `-r` (セッション再開), `-o json` (JSON出力)

詳細: [references/gemini_commands.md](references/gemini_commands.md)

## Codex CLI

コードレビュー・分析が得意。

```bash
# 非インタラクティブ実行
./scripts/codex_exec.sh "このバグの原因を調査して"

# コードレビュー
./scripts/codex_review.sh --uncommitted      # 未コミット変更
./scripts/codex_review.sh --base main        # mainとの差分
./scripts/codex_review.sh "セキュリティ重視" # カスタム指示

# インタラクティブ（tmux内）
./scripts/chat.sh codex "このコードを説明して" 20
```

**主要コマンド:** `codex exec`, `codex review`, `codex resume`

詳細: [references/codex_commands.md](references/codex_commands.md)

## tmux操作

```
tmux attach -t ai-cli   # セッションにアタッチ
Ctrl+b d                # デタッチ
Ctrl+b ←/→              # ペイン間移動
Ctrl+b z                # ペイン最大化/復元
```

## 関連スキル

- `/gemini` - Gemini調査スキル
- `/codex` - Codex分析スキル
- `/codex-review` - コードレビュースキル
