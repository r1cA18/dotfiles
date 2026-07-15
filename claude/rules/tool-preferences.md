# Tool Preferences

## Web Search / ページ取得

Web 検索・ページ内容取得は組み込みの Web ツールを使う。

| タスク                               | ツール              |
| ------------------------------------ | ------------------- |
| Web 検索                             | `WebSearch`         |
| URL のコンテンツ取得（静的）         | `WebFetch`          |
| サイト全体のクロール                 | `WebFetch`          |
| サイトの URL 一覧取得                | `WebSearch`         |
| 構造化データ抽出                     | `WebFetch`          |
| ページ操作（クリック・フォーム入力） | `/agent-browser`    |
| JS描画・ログイン・動的サイト         | `/agent-browser`    |

判断フロー:

1. ページを読む / 検索する -> 組み込みの Web ツールを使う
2. ページを操作する（クリック・入力・スクロール・スクリーンショット） -> `/agent-browser` を使う

## Browser Automation

URL を開く・Web ページを見る・ページ内容を読む・フォーム操作・スクリーンショット等、
ブラウザ操作が必要な場合は **必ず `/agent-browser` スキルを使う**。

`claude-in-chrome` MCP tools (`mcp__claude-in-chrome__*`) を直接呼ばない。
以下の場合のみフォールバックとして許可:

- `agent-browser` コマンドが使えない環境
- ユーザーが明示的に `claude-in-chrome` の使用を指示した場合
- GIF 録画 (`gif_creator`) など agent-browser に対応する機能がない場合
- スキルが手順として `claude-in-chrome` を明示的に要求する場合（`x-article-publisher` / `codex-app-screenshots` 等）

判断フロー:

1. ブラウザ操作が必要 -> `/agent-browser` を使う
2. agent-browser で対応不可 -> `claude-in-chrome` MCP tools にフォールバック

## Local Dev Server (portless)

- dev server の URL を推測しない。`portless list` で確認する
- `localhost:3000` 等のハードコードは禁止。`<name>.localhost:1355` 形式を使う
- dev server 起動時は `portless run <cmd>` 経由で起動する
- 既にプロセスが起動している場合は `portless list` で URL を取得する
