# Gemini CLI コマンドリファレンス

## 起動オプション

| オプション | 説明 |
|-----------|------|
| `-y, --yolo` | 自動承認モード（全アクションを自動承認） |
| `-s, --sandbox` | サンドボックスモードで実行 |
| `-m, --model MODEL` | 使用するモデルを指定 |
| `-r, --resume` | 前のセッションを再開（`latest` or インデックス番号） |
| `-o, --output-format` | 出力形式 (`text`, `json`, `stream-json`) |
| `-i, --prompt-interactive` | プロンプト実行後も対話モード継続 |
| `--include-directories` | 追加ディレクトリをワークスペースに含める |
| `--approval-mode` | 承認モード (`default`, `auto_edit`, `yolo`) |

## スラッシュコマンド

| コマンド | 説明 |
|---------|------|
| `/help`, `/?` | ヘルプ表示 |
| `/tools` | 利用可能ツール一覧 |
| `/stats` | トークン使用状況 |
| `/compress` | コンテキストを要約してトークン削減 |
| `/memory` | GEMINI.mdメモリ管理 |
| `/settings` | 設定エディタを開く |
| `/theme` | テーマ変更 |
| `/vim` | Vimモード切り替え |
| `/chat` | セッション保存・再開 |
| `/restore` | ファイル編集を元に戻す |
| `/clear` | 画面クリア |
| `/quit`, `/exit` | 終了 |

## 組み込みツール

| ツール | 説明 |
|-------|------|
| `google_web_search` | Google検索（Grounding） |
| `web_fetch` | URLからコンテンツ取得 |
| `read_file` | ファイル読み取り |
| `write_file` | ファイル書き込み |
| `run_shell_command` | シェルコマンド実行 |
| `save_memory` | メモリ保存 |

## 使用例

```bash
# 基本的な起動
gemini

# 自動承認モード
gemini -y

# プロンプト付き起動
gemini "TypeScriptの新機能を教えて"

# JSON出力
gemini -o json "ファイル一覧"

# セッション再開
gemini -r latest
```
