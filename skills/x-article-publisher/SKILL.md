---
name: x-article-publisher
description: "Markdown -> X Articles publisher via agent-browser. Parse article, open editor, inject HTML via paste or JS eval."
triggers:
  - "x article"
  - "X記事"
  - "x-article"
  - "publish to x"
  - "x articles"
  - "x記事に投稿"
---

# X Article Publisher

Markdown記事をHTMLに変換し、agent-browser経由でX Articlesエディタに流し込む。

## Prerequisites

- agent-browser (Playwright CLI)
- Python 3 (parse_markdown.py用。標準ライブラリのみ)
- X Premium Plus (Articles機能に必要)

## Login (初回のみ)

永続プロファイルを使い、初回だけ手動ログインする。

```bash
# 初回: headed + profile でログイン
agent-browser --headed --profile ~/.agent-browser/x-profile open "https://x.com/login"
# ユーザーが手動でログイン → プロファイルに保存される

# 2回目以降: 同じprofileを使えばログイン済み
agent-browser --headed --profile ~/.agent-browser/x-profile open "https://x.com/compose/articles"
```

全コマンドに `--headed --profile ~/.agent-browser/x-profile` を付けること。以降のコマンド例では省略する。

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

```bash
# 新規記事
agent-browser open "https://x.com/compose/articles"
# ドラフト一覧が表示される → "create" ボタンをクリック

# 既存記事編集
agent-browser open "https://x.com/compose/articles/edit/<article_id>"
```

```bash
agent-browser snapshot -i
# create ボタンの ref を見つけてクリック
agent-browser click @<create_ref>
```

### Step 3: Upload Cover Image (画像がある場合)

```bash
agent-browser snapshot -i
# "添加照片或视频" / "Add photo or video" ボタンを見つける
agent-browser click @<upload_ref>
agent-browser upload @<file_input_ref> /path/to/cover.jpg
```

### Step 4: Fill Title

```bash
agent-browser snapshot -i
# タイトル入力欄を見つける (placeholder: "添加标题" / "Add a title")
agent-browser fill @<title_ref> "Article Title"
```

### Step 5: Paste HTML Content

**方法A: JavaScript insertHTML (推奨)**

HTMLをJavaScript経由でエディタに直接挿入する。長いHTMLはファイルから読み込む。

```bash
# HTMLファイルを生成
python3 ~/.claude/skills/x-article-publisher/scripts/parse_markdown.py article.md --html-only > /tmp/article.html

# エディタ本文をクリック
agent-browser click @<body_ref>

# JavaScript でHTMLを挿入
agent-browser eval "
  const resp = await fetch('file:///tmp/article.html');
  const html = await resp.text();
  const editor = document.querySelector('[contenteditable=\"true\"]');
  if (editor) {
    editor.focus();
    document.execCommand('insertHTML', false, html);
  }
"
```

`file://` が使えない場合:

```bash
# HTMLをインラインで渡す (シングルクォート内にダブルクォートを使う)
HTML_CONTENT=$(cat /tmp/article.html | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
agent-browser eval "
  const html = ${HTML_CONTENT};
  const editor = document.querySelector('[contenteditable=\"true\"]');
  if (editor) { editor.focus(); document.execCommand('insertHTML', false, html); }
"
```

**方法B: innerHTML 直接設定**

```bash
agent-browser eval "
  const editor = document.querySelector('[contenteditable=\"true\"]');
  if (editor) {
    editor.innerHTML = '<h2>Section</h2><p>Content</p>';
    editor.dispatchEvent(new Event('input', { bubbles: true }));
  }
"
```

**方法C: Clipboard API + Paste**

```bash
agent-browser eval "
  const html = '<h2>Section</h2><p>Content</p>';
  const blob = new Blob([html], { type: 'text/html' });
  const item = new ClipboardItem({ 'text/html': blob });
  await navigator.clipboard.write([item]);
"
agent-browser click @<body_ref>
agent-browser press Meta+v
```

### Step 6: Insert Content Images (reverse order)

`content_images` の block_index が大きい順に挿入する。

```bash
# 1. snapshot で after_text を含む段落の ref を探す
agent-browser snapshot -i

# 2. 段落をクリックして End キーで行末へ
agent-browser click @<paragraph_ref>
agent-browser press End

# 3. 画像をアップロード (ドラッグ&ドロップまたはファイルアップロードメニュー)
# agent-browser upload で直接ファイル指定は状況依存
```

### Step 7: Insert Dividers (reverse order)

区切り線は X Articles の Insert > Divider メニューから手動挿入。HTML `<hr>` は無視される。

### Step 8: Verify & Save

```bash
agent-browser screenshot /tmp/x-article-preview.png
```

ドラフトは自動保存される。公開は手動で行う (NEVER auto-publish)。

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
