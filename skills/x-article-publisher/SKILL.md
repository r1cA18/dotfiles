---
name: x-article-publisher
description: "Markdown -> X Articles clipboard publisher. Convert article to rich text HTML and copy to clipboard for pasting into X Articles editor."
triggers:
  - "x article"
  - "X記事"
  - "x-article"
  - "クリップボードにコピー"
  - "publish to x"
  - "x articles"
---

# X Article Publisher

Markdown記事をリッチテキストHTMLに変換し、クリップボードにコピーする。
X Articles エディタに Cmd+V で貼り付けられる。

## Prerequisites

- nix (pyobjc-framework-Cocoa, Pillow を nix shell 経由で使用)
- macOS (AppKit NSPasteboard を使用)

## Usage

### Quick: Zenn/Qiita記事をX Articlesへ

```bash
bash ~/.claude/skills/x-article-publisher/scripts/publish_to_clipboard.sh <markdown_file>
```

### Step by step

1. **Parse**: Markdownをパースして構造化データ(JSON)を取得

```bash
NIX_EXPR='(import <nixpkgs> {}).python313.withPackages (ps: [ ps.pyobjc-framework-Cocoa ps.pillow ])'
nix shell --impure --expr "$NIX_EXPR" --command python3 \
  ~/.claude/skills/x-article-publisher/scripts/parse_markdown.py <markdown_file>
```

2. **Copy**: HTMLをクリップボードにコピー

```bash
nix shell --impure --expr "$NIX_EXPR" --command python3 \
  ~/.claude/skills/x-article-publisher/scripts/copy_to_clipboard.py html "<html_content>"
```

3. **Paste**: X Articles エディタで Cmd+V

## Workflow

1. `publish_to_clipboard.sh` を実行
2. X Articles エディタを開く (https://x.com/compose/articles)
3. タイトルを手動入力 (スクリプトが表示する)
4. 本文エリアで Cmd+V
5. カバー画像・コンテンツ画像は手動でアップロード
6. 区切り線 (dividers) は X Articles の Insert > Divider メニューで手動挿入

## Limitations

- X Articles のタイトルはリッチテキスト貼り付けでは設定できない (手動入力)
- 画像はクリップボード経由では挿入できない (手動アップロード)
- テーブルは X Articles 非対応 (画像変換が必要な場合は table_to_image.py を使用)
- 区切り線 (---) は HTML <hr> では挿入できない (X Articles のメニューから挿入)

## Files

- `scripts/parse_markdown.py` - Markdown parser (title, images, dividers, HTML extraction)
- `scripts/copy_to_clipboard.py` - Clipboard copier (HTML/image, macOS/Windows)
- `scripts/publish_to_clipboard.sh` - End-to-end wrapper script
