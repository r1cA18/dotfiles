---
name: x-article-publisher
description: "Prepare or publish Markdown articles in X Articles when the user requests that workflow. Convert Markdown to HTML and use an available authenticated browser to fill and verify the editor. Requires access to X Articles; ordinary short posts are outside this workflow."
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

Markdown記事をHTMLに変換し、利用可能なbrowser操作でX Articlesエディタへ入力する。

## Prerequisites

- ログイン済みsessionを操作できるbrowser tool
- Python 3 (parse_markdown.py用。標準ライブラリのみ)
- 対象accountでX Articlesエディタを使用できること
- Xにログイン済みのChromeブラウザ

利用中agentで提供されるbrowser skillの操作規則を読む。通常は`agent-browser`を使い、既存Chrome sessionが必要な場合は利用可能なChrome操作toolを選ぶ。特定製品のMCP名が他製品にも存在するとは考えない。アクセス制限に遭遇した場合は回避を試みず、利用できるsessionと対応操作を確認する。

以下のJavaScriptは実際にDraft.jsが使われていて選んだbrowser toolが編集用script実行を許す場合の参考。通常の入力・paste・file upload機能が使える場合はそれを優先する。

## Quick Reference

```
1. Parse:   python3 "$(agent-skill-path x-article-publisher scripts/parse_markdown.py)" article.md --html-only > /tmp/article.html
2. Open:    Open the X Articles editor in the selected browser
3. Title:   Locate the title input and type the title
4. Content: Paste the converted content using a supported editor action
5. Verify:  Inspect the rendered article and capture a screenshot
```

## Workflow

### Step 1: Parse Markdown to HTML

```bash
python3 "$(agent-skill-path x-article-publisher scripts/parse_markdown.py)" <markdown_file> --html-only > /tmp/article.html
```

JSON出力が必要な場合（画像・区切り線の位置情報付き）:

```bash
python3 "$(agent-skill-path x-article-publisher scripts/parse_markdown.py)" <markdown_file>
```

parse_markdown.pyはYAML frontmatterからのtitle抽出、画像パスの自動探索（~/Downloads, ~/Desktop等）、コードブロックのblockquote変換に対応。

### Step 2: Open X Articles Editor

選んだbrowser toolでtabとlogin状態を確認して`https://x.com/compose/articles`へ移動する。

新規記事: ドラフト一覧画面で「create」ボタンをクリック。
既存記事: `https://x.com/compose/articles/edit/<article_id>` に直接navigate。

### Step 3: Fill Title

```javascript
// Use only with a browser tool that permits editor scripting.
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

セレクタが見つからない場合はsnapshotや画面からタイトル入力欄を探し、browser toolの入力操作を使う。

### Step 4: Inject HTML Content (ClipboardEvent paste)

Draft.jsが使われている画面ではDOMの直接変更が編集stateへ反映されない場合がある。通常のpasteで書式が保持されない場合に、対応toolで次の方法を検証する。現行UIが異なる場合は観測した編集機能へ合わせる。

```javascript
// Use only when editor scripting is supported. Supply articleHtml as data.
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

1. snapshotでエディタの構造を確認
2. `[contenteditable="true"]` や `[role="textbox"]` で代替セレクタを試す
3. browserのscreenshotで目視確認

paste後にテキストが反映されない場合:

1. エディタ本文をクリックしてフォーカスを確実にしてからリトライ
2. 少量のHTMLで先にテスト（`<p>test</p>` 等）して動作確認

### Step 5: Upload Cover Image

選択したbrowserがfile uploadに対応する場合は画像追加UIから指定された画像をuploadする。未対応の場合だけユーザーへその操作を依頼する。反映された画像とcropを確認する。

### Step 6: Insert Content Images

parse_markdown.pyの`content_images`出力で挿入位置を確認し、利用可能なupload・編集操作で画像を追加する。未対応の操作だけユーザーへ依頼する。

block_indexが大きい順（後ろから前へ）に挿入すると位置がずれない。

### Step 7: Insert Dividers

parse_markdown.pyの`dividers`出力とpaste後の表示を比較する。区切り線が反映されない場合は現行エディタの挿入メニューを確認し、対応するbrowser操作で追加する。操作できない場合はその箇所をユーザーへ伝える。

### Step 8: Verify & Save

browserのscreenshotで本文・見出し・画像を確認し、画面の保存状態を確認する。

draft作成の依頼では公開しない。公開操作はユーザーが依頼した場合に限り、対象記事と完成内容を確認して行う。利用中browserの操作制約が追加確認を要求する場合はその規則に従う。

## Technical Notes

- 既存の参考実装はDraft.jsの`public-DraftEditor-content` classを使用
- Draft.js は独自の内部状態管理を持ち、DOM直接操作を無視する
- paste後は文字数だけでなく表示された書式と保存状態も確認
- browserやOSによってclipboardのHTML書式が保持されるかを確認

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
