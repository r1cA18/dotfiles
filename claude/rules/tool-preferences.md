# Claude Tool Integration

Web検索・page取得・browser操作の選択は共有`agents/rules/tool-preferences.md`に従う。

## Claude in Chrome fallback

`claude-in-chrome` MCP tools (`mcp__claude-in-chrome__*`) を直接呼ばない。
以下の場合のみフォールバックとして許可:

- `agent-browser` コマンドが使えない環境
- ユーザーが明示的に `claude-in-chrome` の使用を指示した場合
- GIF 録画 (`gif_creator`) など agent-browser に対応する機能がない場合
- スキルが手順として `claude-in-chrome` を明示的に要求する場合（`x-article-publisher` / `codex-app-screenshots` 等）

## Local Dev Server (portless)

- dev server の URL を推測しない。`portless list` で確認する
- `localhost:3000` 等のハードコードは禁止。`<name>.localhost:1355` 形式を使う
- dev server 起動時は `portless run <cmd>` 経由で起動する
- 既にプロセスが起動している場合は `portless list` で URL を取得する
