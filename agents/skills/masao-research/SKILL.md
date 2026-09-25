---
name: masao-research
description: >-
  まさおAIじっくり解説chの最新情報を YouTube / note / Zenn / X から調査する。
  トリガー: 「まさおAIじっくり解説ch」「まさお 最新」「まさお ハーネス」「まさお 調査」「masao research」「まさおの記事を調べて」「まさおの動画を調べて」「AI駆動開発研究部」。
  最新情報があれば優先的に読み、自分の環境（dotfiles）への適用を検討する。
user-invocable: true
---

# まさおAIじっくり解説ch リサーチ

まさお氏の公開情報を YouTube・note・Zenn・X から効率よく調査し、必要に応じて dotfiles や自分のハーネスに取り込む。

## 情報源

| 媒体 | URL / feed | 備考 |
| ---- | ---------- | ---- |
| YouTube | https://www.youtube.com/@ai_masaou | RSS: `https://www.youtube.com/feeds/videos.xml?channel_id=UCvHpETRVi1tXeRJoYiXHJqw` |
| note | https://note.com/masa_wunder | RSS: `https://note.com/masa_wunder/rss` |
| Zenn | https://zenn.dev/aimasaou | RSS: `https://zenn.dev/aimasaou/feed` |
| X | https://x.com/ai_masaou | Grok x_search or 公式サイト経由で概要を把握 |
| 公式サイト | https://masao-ai.web.app/ | チャンネル・SNS・メンバーシップ案内 |

## 使い方

### 1. 最新フィード一覧

```bash
masao-feeds
masao-feeds --limit 5
masao-feeds --source youtube
masao-feeds --since 2026-09-15
masao-feeds --json
```

`--source` は `youtube`, `note`, `zenn`, `all` から選択。

### 2. YouTube 動画の字幕取得

```bash
yt-sub <URL>        # 手動/自動字幕を SRT で取得
yt-auto-sub <URL>   # 自動字幕のみ取得
yt-transcribe <URL> # 字幕がない場合は whisper-ctranslate2 で文字起こし
```

### 3. X（Twitter）の検索

x-research スキルで Grok x_search を使う:

```bash
agent-skill-path x-research scripts/grok_context_research.ts --help
```

まさお氏の X ハンドルは `@ai_masaou`。

### 4. Web 記事の全文取得

note / Zenn / 公式サイトの記事は `webfetch` または `curl` で全文を取得できる。
有料・メンバーシップ限定記事は取得できない。

## 環境への取り込みフロー

1. 最新の投稿を `masao-feeds` で把握
2. 興味あるものは `yt-sub` / `webfetch` で本文を取得
3. 内容を自分の環境に活かせるか判定:
   - CLI ツール・パッケージ → `nix/home-manager/programs/packages.nix`
   - エイリアス・調査スクリプト → `nix/home-manager/programs/zsh.nix`
   - エージェントの振る舞いルール → `agents/rules/` または `agents/skills/`
   - Claude/Codex 固有設定 → `nix/home-manager/programs/claude-code.nix` / `codex.nix`
4. 学びは `vault/40_AI/` または `agents/skills/` にナレッジとして残す

## 制約

- X のタイムライン/Following をリアルタイムに追う公式 API は有料・制限厳しい。告知レベルの把握なら RSS + x-research で十分。
- note メンバーシップ限定記事は読めない。
- YouTube 動画は字幕または音声文字起こしで LLM に渡す。字幕がない動画は `yt-transcribe` を使うが、時間がかかる。
