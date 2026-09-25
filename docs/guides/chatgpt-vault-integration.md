# ChatGPT Web × Local Vault (Olympus) 導入・運用ガイド

ChatGPT Web（chatgpt.com）やモバイルアプリから、ローカルホスト（またはhomelab）で稼働するOlympus Vaultへ、思考メモ・作業ログ・調査結果・ナレッジ・タスクを直接保存・追記するための導入手順書。

---

## 1. アーキテクチャと保存先

Olympus reboot（2026-08以降）では、Markdownファイルを正本（source of truth）、SQLiteをインデックス/ミラーとし、各エンティティをULIDまたは日付ベースのフラットな構造で管理している。

ChatGPTからの入力は、意図に応じて以下のディレクトリへ適切な形式で保存・追記される：

| データ種別                 | 保存先                         | フォーマット・特徴                                                          | 対応API / MCP                                      |
| -------------------------- | ------------------------------ | --------------------------------------------------------------------------- | -------------------------------------------------- |
| メモ・つぶやき・作業実況   | `vault/times/YYYY-MM-DD.md`    | `:::times{id="..." tags="..." ...} 本文 :::`（同日ファイル末尾に自動追記）  | `POST /api/chatgpt/memo`                           |
| 調査結果・気付き・一次観測 | `vault/observations/<ULID>.md` | 未分類の一次記録。機能LLM層がタスクやナレッジへ後から自動ルーティング       | `POST /api/chatgpt/observation`                    |
| 対話ログ・作業セッション   | `vault/sessions/<ULID>.md`     | `:::turn{turn="1" role="..."} :::` 形式でターンごとに記録・追記             | `POST /api/chatgpt/session` / `session/turn`       |
| 永続ナレッジノート         | `vault/knowledge/<ULID>.md`    | 出典（`sources`）とタグ付き構造化ノート。既存ノートへのセクション追記に対応 | `POST /api/chatgpt/knowledge` / `knowledge/append` |
| GTDタスク                  | `vault/tasks/<ULID>.md`        | ステータス（todo/doing/done等）、期日、進捗メモ追記に対応                   | `POST /api/chatgpt/task` / `task/update`           |

---

## 2. 事前準備（ローカルサーバーとトンネル起動）

ChatGPT Webはクラウド側からHTTP通信を行うため、ローカルのOlympus Gatewayへの外部HTTPSトンネルを用意する。

### 2.1 Olympus Gatewayの起動

Gatewayはポート `3100` で稼働する。

```bash
cd ~/Develop/github.com/r1cA18/olympus
bun run dev
# または systemd 経由（homelab/サーバー環境の場合）
# systemctl --user start olympus-gateway.service
```

### 2.2 トンネルの起動（選択肢）

#### 選択肢A: Cloudflare Tunnel（推奨・安定運用）

```bash
cloudflared tunnel --url http://localhost:3100
```

ターミナルに表示される公開URL（例: `https://xxxx.trycloudflare.com`）または自身で割り当てた独自ドメイン（例: `https://vault-api.example.com`）を使用する。

#### 選択肢B: ngrok（手軽な動作検証用）

```bash
ngrok http 3100
```

#### 選択肢C: Tailscale Funnel（Tailscale環境）

```bash
tailscale funnel 3100
```

---

## 3. Custom GPTs (Actions) の導入手順（最も推奨）

ブラウザ版およびスマートフォン（iOS/Android）のChatGPT公式アプリから最も安定して動作する方式。

### 3.1 Custom GPTの新規作成

1. [ChatGPT](https://chatgpt.com) を開き、左サイドバーの「Explore GPTs」→「+ Create」をクリック
2. 「Name」に `Vault Secretary`、「Description」に `Local Olympus Vault Integration` と入力

### 3.2 Instructions（指示プロンプト）の登録

「Configure」タブの「Instructions」欄に以下をそのままコピー＆ペーストする：

```markdown
You are the user's personal Vault Secretary.
Your job is to assist the user in managing their knowledge base, capturing daily thoughts, recording research findings, archiving conversations, and tracking tasks in their local Olympus vault.

When the user asks you to:

1. "メモして" / "記録して" / quick status updates:
   Call `saveMemo` to append it to today's Times stream.
2. "調査結果を保存して" / raw research findings / unclassified insights:
   Call `saveObservation` to record an observation in vault.
3. "この作業ログを保存して" / "会話全体を残して":
   Call `saveSession` with a descriptive title and initial turns.
4. "会話を続けて保存して" / append turn to existing session:
   Call `appendSessionTurn` with the target `session_id`.
5. "ナレッジにして" / permanent structured note:
   Call `createKnowledge` with title, body, and tags.
6. "ナレッジに追記して":
   First call `searchKnowledge` if you don't know the note ID, then call `appendKnowledge` with `knowledge_id` and markdown `append`.
7. "タスクを追加して" / actionable todos:
   Call `createTask` with title, status ("todo"), and optional deadline.
8. "タスク完了にして" / "タスク更新して":
   Call `updateTask` with `task_id` and updated status ("done") or notes.
9. "ナレッジ探して" / "過去のメモ検索して":
   Call `searchKnowledge` with query keyword `q`.
10. "今の状況は？" / "タスク一覧見せて":
    Call `getContext` to fetch active tasks and recent Times.

Always confirm briefly in polite Japanese after saving, explicitly mentioning the saved destination (Times / Observation / Session / Knowledge / Task).
```

### 3.3 Actionsの登録

1. 「Configure」タブ下部の「Actions」→「Create new action」をクリック
2. **Schemaの登録**:
   - トンネルURLが `https://xxxx.trycloudflare.com` の場合、`Import from URL` に `https://xxxx.trycloudflare.com/api/chatgpt/openapi.json` を指定してインポートする
   - または、ブラウザで `https://xxxx.trycloudflare.com/api/chatgpt/openapi.json` にアクセスして表示されたJSON文字列をそのままエディタに貼り付ける
3. **Authenticationの設定**:
   - `Authentication Type`: `API Key` を選択
   - `Auth Type`: `Bearer` を選択
   - `API Key`: Olympusの認証トークン（`.env` の `OLYMPUS_TOKEN` または `OLYMPUS_AUTH_TOKEN`）を入力
4. 画面右上の「Save」または「Update」をクリックして保存（「Only me」で非公開保存を推奨）

---

## 4. Developer Mode (MCP SSE) の導入手順（代替方式）

ChatGPTのDeveloper Modeを使ってMCPサーバーとして直接登録する場合の手順。

1. **MCP SSE サーバーの起動**:
   ```bash
   cd ~/Develop/github.com/r1cA18/olympus
   bun run --filter @olympus/mcp sse
   # ポート 3101 で起動
   ```
2. **トンネルの起動**:
   ```bash
   cloudflared tunnel --url http://localhost:3101
   ```
3. **ChatGPT Webでの登録**:
   - `Settings` → `Apps & Connectors` → `Advanced settings` → `Developer mode` を有効化する
   - `Apps & Connectors` の `Create` から、URLに `https://<tunnel-domain>/sse` を登録する

---

## 5. 日常の利用シーンと挙動例

### シーン1: 思考のメモ・分報（Timesへの追記）

- ユーザー: `「今日調べたCloudflare Tunnelの仕様、無料枠でも固定ホスト名使えるらしいってメモしといて」`
- ChatGPT: `saveMemo` を呼び出し、`vault/times/2026-09-18.md` にディレクティブ形式で自動追記。

### シーン2: 会話セッションの継続保存（Sessionsへの追記）

- ユーザー: `「今のディスカッション内容を作業ログとして残して」`
- ChatGPT: `saveSession` を呼び出し、`vault/sessions/<ULID>.md` を作成してセッションIDを返却。
- ユーザー: `「さっきのセッションに、この追加エラーの対処法も追記して」`
- ChatGPT: `appendSessionTurn` を呼び出し、同じセッションファイルにターンを追加。

### シーン3: ナレッジの作成と追記（Knowledge）

- ユーザー: `「FastAPIの認証ベストプラクティスをナレッジとして保存して」`
- ChatGPT: `createKnowledge` で `vault/knowledge/<ULID>.md` を作成。
- ユーザー: `「さっきのFastAPIナレッジに、JWTの失効処理について追記して」`
- ChatGPT: `searchKnowledge(q="FastAPI")` でIDを特定後、`appendKnowledge` で対象ノートにセクションを追記。

### シーン4: タスクの登録と完了更新（Tasks）

- ユーザー: `「明日までにMCPの動作確認するタスク作って」`
- ChatGPT: `createTask` で期日付きタスクを作成。
- ユーザー: `「さっきのMCP確認タスク完了にしといて」`
- ChatGPT: `updateTask(status="done")` でステータスを更新。

---

## 6. 実装コードの関連リファレンス

- Gateway ルーター: [chatgpt.ts](file:///Users/r1ca18/Develop/github.com/r1cA18/olympus/apps/gateway/src/routes/chatgpt.ts)
- MCP SSE サーバー: [sse.ts](file:///Users/r1ca18/Develop/github.com/r1cA18/olympus/apps/mcp/src/sse.ts)
- Session vault処理: [sessions.ts](file:///Users/r1ca18/Develop/github.com/r1cA18/olympus/packages/core/src/vault/sessions.ts)
- Observation vault処理: [observations.ts](file:///Users/r1ca18/Develop/github.com/r1cA18/olympus/packages/core/src/vault/observations.ts)
- Olympus内連携ガイド: [chatgpt-integration.md](file:///Users/r1ca18/Develop/github.com/r1cA18/olympus/docs/chatgpt-integration.md)
