---
name: x-article-publisher
description: "Markdown -> X Articles publisher via agent-browser. Parse article, open editor, inject HTML into contenteditable."
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
- Python 3 (parse_markdown.py用。nix不要、標準ライブラリのみ使用)

## Workflow

### Step 1: Parse Markdown

```bash
python3 ~/.claude/skills/x-article-publisher/scripts/parse_markdown.py <markdown_file>
```

JSON出力から `title` と `html` を取得する。

### Step 2: Open X Articles Editor

新規記事の場合:

```bash
agent-browser --headed open "https://x.com/compose/articles"
```

既存記事の編集:

```bash
agent-browser --headed open "https://x.com/compose/articles/edit/<article_id>"
```

初回はログインが必要。`--headed` でブラウザを表示し、ユーザーがログインする。
ログイン完了を `agent-browser wait --load networkidle` で待機。

### Step 3: Snapshot & Identify Editor

```bash
agent-browser snapshot -i
```

X Articles エディタの構造を確認し、タイトル入力欄と本文エリア (contenteditable) の ref を特定する。

### Step 4: Set Title

```bash
agent-browser click @<title_ref>
agent-browser fill @<title_ref> "<title>"
```

### Step 5: Inject HTML into Body

本文の contenteditable 要素にHTMLを挿入する。

**方法A: insertHTML (推奨)**

```bash
agent-browser click @<body_ref>
agent-browser eval "document.execCommand('insertHTML', false, '<h2>Section</h2><p>Content</p>')"
```

**方法B: innerHTML直接設定**

```bash
agent-browser eval "
  const editor = document.querySelector('[data-testid=\"articleBodyEditor\"]') || document.querySelector('[contenteditable=\"true\"]');
  if (editor) {
    editor.focus();
    editor.innerHTML = '<h2>Section</h2><p>Content</p>';
    editor.dispatchEvent(new Event('input', { bubbles: true }));
  }
"
```

**方法C: Clipboard API経由 (フォールバック)**

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

### Step 6: Verify

```bash
agent-browser screenshot /tmp/x-article-preview.png
```

スクリーンショットを確認して、フォーマットが正しく反映されているか検証する。

### Step 7: Images (Manual)

カバー画像とコンテンツ画像は手動アップロードが必要。
parse_markdown.py の出力に画像パスとblock_index（挿入位置）が含まれる。

## Notes

- X Articles はテーブル非対応。テーブルがある場合はリスト形式に変換するか、画像として挿入する
- 区切り線 (---) は X Articles の Insert > Divider メニューから手動挿入
- `document.execCommand` が効かない場合は方法B/Cにフォールバック
- HTML内のシングルクォートは `eval` のクォーティングに注意。長いHTMLはファイル経由で渡す:
  ```bash
  # HTMLをファイルに保存
  python3 parse_markdown.py article.md --html-only > /tmp/article.html
  # ファイルから読み込んで挿入
  agent-browser eval "
    const html = await (await fetch('file:///tmp/article.html')).text();
    document.querySelector('[contenteditable]').focus();
    document.execCommand('insertHTML', false, html);
  "
  ```

## Files

- `scripts/parse_markdown.py` - Markdown parser (frontmatter title対応済み)
