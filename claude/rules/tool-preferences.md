# Tool Preferences

## Browser Automation

- ブラウザ操作が必要な場合、`/agent-browser` スキルを最優先で使う
- `claude-in-chrome` MCP tools は `/agent-browser` が使えない・不適切な場合のフォールバック

## Local Dev Server (portless)

- dev server の URL を推測しない。`portless list` で確認する
- `localhost:3000` 等のハードコードは禁止。`<name>.localhost:1355` 形式を使う
- dev server 起動時は `portless run <cmd>` 経由で起動する
- 既にプロセスが起動している場合は `portless list` で URL を取得する
