---
name: op-api-keys
description: >-
  1Password CLI (op) 経由で API キーを安全に読み出し、エージェントやスクリプトから使えるようにする。
  トリガー: "api key 管理", "1password api key", "API キー 安全に置く", "op run", "TYPESAFE_API_KEY".
user-invocable: true
---

# 1Password API Key Management

API キーはリポジトリや .env ファイル、シェル履歴に置かない。
1Password CLI (`op`) を使って実行時に環境変数として注入する。

## 必要なもの

- 1Password CLI (`op`) は dotfiles で入っている
- 1Password 本体で対象の API key を保存済み
- 保存先を `op://<vault>/<item>/<field>` の形式で参照する

## 設定手順

1. 1Password に API key を保存する
   - Vault 例: `AI`
   - Item 例: `TypeSafe`
   - Field 例: `api-key`
   - 完全参照: `op://AI/TypeSafe/api-key`

2. `~/.config/op/env/typesafe.env` を作成し、以下を書く:

```bash
TYPESAFE_API_KEY=op://AI/TypeSafe/api-key
```

3. コマンドを `op run` 経由で実行する:

```bash
op run --env-file ~/.config/op/env/typesafe.env -- jev models
op run --env-file ~/.config/op/env/typesafe.env -- jev ask "..." --noul urgent:"..."
```

4. 面倒なら `jev` エイリアスを使う:

```bash
jev models
jev ask "The customer wants a refund" --noul wants_refund:"Is the customer asking for money back?" --choice department:"Which team?" billing technical other
```

## 対応サービス

| サービス | env ファイル | コマンド/用途 |
| -------- | ------------ | ------------- |
| TypeSafe / Jev | `~/.config/op/env/typesafe.env` | `jev` |
| Grok / xAI | `~/.config/op/env/grok.env` | `x-research` スキル |
| OpenAI | `~/.config/op/env/openai.env` | Codex, ChatGPT API 等 |
| Anthropic | `~/.config/op/env/anthropic.env` | Claude Code 別 API key 等 |
| Google AI | `~/.config/op/env/google.env` | Gemini API 等 |

## 新しい API key を追加するとき

1. 1Password に保存
2. `~/.config/op/env/<service>.env` を作成
3. 対象スクリプト/エイリアスを追加 or `op run --env-file ... -- <cmd>` で直接使う

## Jev CLI

`jev` は TypeSafe System One API を叩く最小 CLI ラッパー。

```bash
jev models
jev ask "The customer is angry about a duplicate charge." \
  --noul wants_refund:"Is the customer asking for a refund?" \
  --choice department:"Which team should handle this?" billing technical sales \
  --score urgency:"How urgent is this?" "Can wait" "This week" "Today"
```

出力は JSON。各質問の答えは `result.answers.<id>` に入る:

```bash
jev ask "..." ... | jq '.answers.wants_refund.noul'
```

## セキュリティ

- `~/.config/op/env/*.env` には `op://` 参照のみを書く。実際の値は入れない。
- API key はプロセス一覧に `op run` によって注入される。直接 `export` しない。
- この skill 内のスクリプトは API key を一切ハードコードしない。
