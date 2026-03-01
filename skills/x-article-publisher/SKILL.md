---
name: x-article-publisher
description: "Publish Markdown or blog articles to X Articles (Twitter/X long-form posts). Converts Markdown to HTML and injects it into the X Articles Draft.js editor via claude-in-chrome MCP browser automation. MUST use this skill when: (1) user wants to publish/post/push any article or blog post to X Articles or X's long-form feature, (2) user mentions 'X記事', 'X長文', 'x article', 'x articles', 'Xに記事', 'Xの記事', '記事をXに投稿', (3) user wants to cross-post a Zenn/Qiita/blog article to X, (4) user asks how to put Markdown content into the X Articles editor, (5) user mentions publishing long-form content on X/Twitter. This skill handles the full workflow: parsing Markdown, opening the editor, and injecting formatted rich text."
triggers:
  - "x article"
  - "X記事"
  - "x-article"
  - "publish to x"
  - "x articles"
  - "x記事に投稿"
  - "xに記事"
  - "x長文"
  - "記事をxに"
---

# X Article Publisher

Markdown記事をHTMLに変換し、claude-in-chrome MCP経由でX Articlesエディタ（Draft.js）に流し込む。

## Prerequisites

- claude-in-chrome MCP (Chrome拡張。agent-browserはXのbot検知でブロックされるため使用不可)
- Python 3 (parse_markdown.py用。標準ライブラリのみ)
- X Premium Plus (Articles機能に必要)
- Xにログイン済みのChromeブラウザ

## Quick Reference

```
1. Parse:   python3 ~/.claude/skills/x-article-publisher/scripts/parse_markdown.py article.md --html-only > /tmp/article.html
2. Open:    claude-in-chrome -> tabs_create_mcp -> navigate to X Articles editor
3. Title:   claude-in-chrome -> find title input -> type title
4. Inject:  claude-in-chrome -> javascript_tool -> ClipboardEvent paste (see Step 4)
5. Verify:  claude-in-chrome -> computer -> screenshot
```

## Workflow

### Step 1: Parse Markdown to HTML

```bash
python3 ~/.claude/skills/x-article-publisher/scripts/parse_markdown.py <markdown_file> --html-only > /tmp/article.html
```

JSON出力が必要な場合（画像・区切り線の位置情報付き）:

```bash
python3 ~/.claude/skills/x-article-publisher/scripts/parse_markdown.py <markdown_file>
```

parse_markdown.pyはYAML frontmatterからのtitle抽出、画像パスの自動探索（~/Downloads, ~/Desktop等）、コードブロックのblockquote変換に対応。

### Step 2: Open X Articles Editor

```
mcp__claude-in-chrome__tabs_context_mcp     # タブ一覧取得
mcp__claude-in-chrome__tabs_create_mcp      # 新規タブ作成
mcp__claude-in-chrome__navigate             # URL: https://x.com/compose/articles
```

新規記事: ドラフト一覧画面で「create」ボタンをクリック。
既存記事: `https://x.com/compose/articles/edit/<article_id>` に直接navigate。

### Step 3: Fill Title

```javascript
// javascript_tool で実行
const titleInput =
  document.querySelector(
    '[data-testid="articleTitle"] [contenteditable="true"]',
  ) ||
  document.querySelector('[placeholder*="title" i]') ||
  document.querySelector('[placeholder*="标题"]');
if (titleInput) {
  titleInput.focus();
  document.execCommand("selectAll");
  document.execCommand("insertText", false, "タイトル文字列");
}
("title set");
```

セレクタが見つからない場合: `mcp__claude-in-chrome__read_page` や `mcp__claude-in-chrome__find` でタイトル入力欄を探し、`mcp__claude-in-chrome__computer` の `type` アクションで入力。

### Step 4: Inject HTML Content (ClipboardEvent paste)

X ArticlesのエディタはDraft.js。innerHTML/insertHTML/execCommandは動作しない。
ClipboardEvent paste simulationが唯一の方法。

```javascript
// javascript_tool で実行。articleHtml にHTMLコンテンツを埋め込む
const articleHtml = "<h2>...</h2><p>...</p>"; // ここに全HTMLを埋め込む
const editor = document.querySelector(".public-DraftEditor-content");
if (!editor) throw new Error("Draft.js editor not found");
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
"Injected: " + articleHtml.length + " chars";
```

HTMLが長い場合のescapeは:

```bash
python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" < /tmp/article.html > /tmp/article-escaped.txt
```

escape済みの文字列をJavaScriptの `const articleHtml = ...;` に直接埋め込む。

**注入失敗時のフォールバック:**

`.public-DraftEditor-content` が見つからない場合:

1. `mcp__claude-in-chrome__read_page` でエディタのDOM構造を確認
2. `[contenteditable="true"]` や `[role="textbox"]` で代替セレクタを試す
3. `mcp__claude-in-chrome__computer` のscreenshotで目視確認

paste後にテキストが反映されない場合:

1. エディタ本文を一度クリック (`computer` -> `left_click`) してフォーカスを確実にしてからリトライ
2. 少量のHTMLで先にテスト（`<p>test</p>` 等）して動作確認

### Step 5: Upload Cover Image

自動化の制限: ファイル選択ダイアログはブラウザセキュリティにより完全自動化が難しい。

手動ステップ: ユーザーにカバー画像のアップロードを依頼する。
「カバー画像をアップロードしたい場合は、エディタ上部の画像追加ボタンをクリックしてファイルを選択してください。」

### Step 6: Insert Content Images

parse_markdown.pyの `content_images` 出力で画像の挿入位置を確認できるが、X Articles内での画像アップロードは手動が安全。

block_indexが大きい順（後ろから前へ）に挿入すると位置がずれない。

### Step 7: Insert Dividers

X Articlesは `<hr>` タグを無視するため、区切り線はエディタのメニュー（Insert > Divider）から手動挿入。
parse_markdown.pyの `dividers` 出力で挿入位置を確認。

### Step 8: Verify & Save

```
mcp__claude-in-chrome__computer -> screenshot  # 目視確認
```

ドラフトは自動保存される。公開は必ず手動で行う（自動公開は禁止）。

## Technical Notes

- X Articles エディタは Draft.js (`public-DraftEditor-content` class)
- Draft.js は独自の内部状態管理を持ち、DOM直接操作を無視する
- ClipboardEvent('paste') + DataTransfer.setData('text/html', html) が唯一の外部入力経路
- NSPasteboard (macOS clipboard) 経由の手動ペーストではHTMLがプレーンテキスト化される
- agent-browser (Playwright) は `navigator.webdriver = true` 等のfingerprintでXにブロックされる
- claude-in-chromeはユーザーの実Chromeを操作するためbot検知を回避できる

## Supported Formatting

| Markdown       | X Articles   | 変換方法                   |
| -------------- | ------------ | -------------------------- |
| `##` H2        | 小見出し     | `<h2>` Native              |
| `###` H3       | 小見出し(小) | `<h3>` Native              |
| `**bold**`     | 太字         | `<strong>` Native          |
| `*italic*`     | 斜体         | `<em>` Native              |
| `[text](url)`  | リンク       | `<a>` Native               |
| `1. 2. 3.`     | 番号リスト   | `<li>` Native              |
| `- bullet`     | 箇条書き     | `<li>` Native              |
| `> quote`      | 引用         | `<blockquote>` Native      |
| ` ```code``` ` | 引用に変換   | `<blockquote>` (代替)      |
| Tables         | 非対応       | テキスト形式 or 画像で代替 |
| `---` divider  | メニューから | Insert > Divider (手動)    |

## Files

- `scripts/parse_markdown.py` - Markdown parser (frontmatter title, 画像探索, コードブロック変換対応)
