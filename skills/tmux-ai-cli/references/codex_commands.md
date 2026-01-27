# Codex CLI コマンドリファレンス

## サブコマンド

| コマンド | 説明 |
|---------|------|
| `codex` | インタラクティブモードで起動 |
| `codex exec` / `codex e` | 非インタラクティブ実行 |
| `codex review` | コードレビュー実行 |
| `codex resume` | 前のセッション再開 |
| `codex apply` / `codex a` | Codex Cloudのdiffを適用 |
| `codex login` | ログイン |
| `codex logout` | ログアウト |
| `codex mcp` | MCPサーバー管理 |

## 起動オプション

| オプション | 説明 |
|-----------|------|
| `--full-auto` | 完全自動モード（`-a on-request` + `--sandbox workspace-write`） |
| `--sandbox MODE` | サンドボックスモード (`read-only`, `workspace-write`, `danger-full-access`) |
| `-a, --ask-for-approval` | 承認ポリシー (`untrusted`, `on-failure`, `on-request`, `never`) |
| `--dangerously-bypass-approvals-and-sandbox` | 全承認・サンドボックスをバイパス（危険） |
| `-m, --model MODEL` | モデル指定 |
| `-C, --cd DIR` | 作業ディレクトリ指定 |
| `--add-dir DIR` | 追加の書き込み可能ディレクトリ |
| `-i, --image FILE` | 画像ファイル添付 |
| `--search` | Web検索を有効化 |

## /review オプション

| オプション | 説明 |
|-----------|------|
| `--uncommitted` | 未コミット変更をレビュー |
| `--base BRANCH` | 指定ブランチとの差分をレビュー |
| `--commit SHA` | 特定コミットの変更をレビュー |

## インタラクティブ操作

| 操作 | 説明 |
|-----|------|
| `@` | ファイルをファジー検索 |
| `!` | シェルコマンド実行 |
| `Esc` x2 | 前のメッセージを編集 |
| `/review` | レビューモード開始 |
| `/model` | モデル切り替え |
| `/approvals` | 承認設定 |

## 使用例

```bash
# インタラクティブ起動
codex

# プロンプト付き起動
codex "このコードを説明して"

# 非インタラクティブ実行
codex exec --full-auto --sandbox read-only "バグを調査して"

# コードレビュー
codex review --uncommitted
codex review --base main
codex review "セキュリティ重視でレビュー"

# セッション再開
codex resume --last
```
