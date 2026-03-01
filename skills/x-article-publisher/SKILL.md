---
name: x-article-publisher
description: "Markdown -> X Articles publisher via claude-in-chrome MCP. Parse article to HTML, inject into Draft.js editor via ClipboardEvent paste simulation."
triggers:
  - "x article"
  - "X記事"
  - "x-article"
  - "publish to x"
  - "x articles"
  - "x記事に投稿"
---

# X Article Publisher

Markdown記事をHTMLに変換し、claude-in-chrome MCP経由でX Articlesエディタに流し込む。

## Prerequisites

- claude-in-chrome MCP (Chrome拡張)
- Python 3 (parse_markdown.py用。標準ライブラリのみ)
- X Premium Plus (Articles機能に必要)
- Xにログイン済みのChromeブラウザ

## Why claude-in-chrome (not agent-browser)

agent-browser (Playwright) はXのbot検知でログインがブロックされる。
claude-in-chromeはユーザーの実Chromeブラウザを使うためbot検知を回避できる。

## Workflow

**戦略: テキスト先、画像後、区切り線最後**

### Step 1: Parse Markdown

```bash
python3 ~/.claude/skills/x-article-publisher/scripts/parse_markdown.py <markdown_file>
```

JSON出力:

```json
{
  "title": "Article Title",
  "cover_image": "/path/to/cover.jpg",
  "content_images": [
    { "path": "/path/to/img.jpg", "block_index": 5, "after_text": "context..." }
  ],
  "dividers": [{ "block_index": 7, "after_text": "context..." }],
  "html": "<p>Content...</p><h2>Section</h2>...",
  "total_blocks": 45
}
```

HTML単体出力:

```bash
python3 ~/.claude/skills/x-article-publisher/scripts/parse_markdown.py <markdown_file> --html-only > /tmp/article.html
```

### Step 2: Open X Articles Editor

claude-in-chromeでタブを作成し、X Articlesエディタを開く。

```
# タブコンテキスト取得
mcp__claude-in-chrome__tabs_context_mcp

# 新規タブ作成
mcp__claude-in-chrome__tabs_create_mcp -> https://x.com/compose/articles

# 既存記事編集
mcp__claude-in-chrome__navigate -> https://x.com/compose/articles/edit/<article_id>
```

新規記事の場合、ドラフト一覧から「create」ボタンをクリック。

### Step 3: Fill Title

javascript_toolでタイトルを設定:

```javascript
// タイトル入力欄を見つけてフォーカス → type で入力
```

またはread_page/findでタイトル欄を特定してから入力。

### Step 4: Inject HTML Content (ClipboardEvent paste)

X ArticlesはDraft.jsエディタを使用。innerHTML や insertHTML は動作しない。
ClipboardEvent の paste イベントシミュレーションが唯一の動作する方法。

```javascript
const articleHtml = "<h2>Section</h2><p>Content with <strong>bold</strong></p>";
const editor = document.querySelector(".public-DraftEditor-content");
editor.focus();
const clipboardData = new DataTransfer();
clipboardData.setData("text/html", articleHtml);
clipboardData.setData("text/plain", "");
const pasteEvent = new ClipboardEvent("paste", {
  bubbles: true,
  cancelable: true,
  clipboardData: clipboardData,
});
editor.dispatchEvent(pasteEvent);
```

HTMLが長い場合、Unicode escapeした文字列をJavaScript内に直接埋め込む:

```bash
# HTML生成
python3 ~/.claude/skills/x-article-publisher/scripts/parse_markdown.py article.md --html-only > /tmp/article.html

# JSON escape (JavaScript文字列リテラル用)
python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" < /tmp/article.html > /tmp/article-escaped.txt
```

### Step 5: Upload Cover Image (画像がある場合)

カバー画像は手動アップロード、またはclaude-in-chromeのcomputer toolでファイル選択ダイアログを操作。

### Step 6: Insert Content Images (reverse order)

`content_images` の block_index が大きい順に挿入する。
画像はエディタ内の該当位置にカーソルを置いてからアップロード。

### Step 7: Insert Dividers (reverse order)

区切り線は X Articles の Insert > Divider メニューから手動挿入。HTML `<hr>` は無視される。

### Step 8: Verify & Save

```
mcp__claude-in-chrome__computer -> screenshot
```

ドラフトは自動保存される。公開は手動で行う (NEVER auto-publish)。

## Technical Notes

- X Articles エディタは Draft.js (`public-DraftEditor-content` class)
- Draft.js は innerHTML/insertHTML/execCommand に反応しない
- ClipboardEvent('paste') + DataTransfer.setData('text/html', html) が唯一の方法
- NSPasteboard (macOS clipboard) 経由のペーストも HTML がプレーンテキスト化される
- agent-browser (Playwright) は X の bot 検知でブロックされる

## Supported Formatting

| Element           | Support       | Notes                       |
| ----------------- | ------------- | --------------------------- |
| H2 (`##`)         | Native        | Section headers             |
| H3 (`###`)        | Native        | Sub-headers                 |
| Bold (`**`)       | Native        | Strong emphasis             |
| Italic (`*`)      | Native        | Emphasis                    |
| Links (`[](url)`) | Native        | Hyperlinks                  |
| Ordered lists     | Native        | 1. 2. 3.                    |
| Unordered lists   | Native        | - bullets                   |
| Blockquotes (`>`) | Native        | Quoted text                 |
| Code blocks       | Converted     | -> Blockquotes              |
| Tables            | Not supported | -> PNG image or list format |
| Dividers (`---`)  | Menu insert   | -> Insert > Divider         |

## Files

- `scripts/parse_markdown.py` - Markdown parser (frontmatter title対応済み)
