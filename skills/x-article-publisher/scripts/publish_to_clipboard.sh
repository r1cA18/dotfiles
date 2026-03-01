#!/usr/bin/env bash
# Convert Markdown article to rich text and copy to clipboard.
# Usage: ./publish_to_clipboard.sh <markdown_file>
#
# Requires: nix (for pyobjc-framework-Cocoa + Pillow)
# Output: HTML content copied to system clipboard as rich text

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <markdown_file>" >&2
    exit 1
fi

MARKDOWN_FILE="$1"

if [ ! -f "$MARKDOWN_FILE" ]; then
    echo "Error: File not found: $MARKDOWN_FILE" >&2
    exit 1
fi

NIX_EXPR='(import <nixpkgs> {}).python313.withPackages (ps: [ ps.pyobjc-framework-Cocoa ps.pillow ])'

echo "[1/3] Parsing markdown: $MARKDOWN_FILE"
PARSE_RESULT=$(nix shell --impure --expr "$NIX_EXPR" --command python3 "$SCRIPT_DIR/parse_markdown.py" "$MARKDOWN_FILE" 2>&1)

# Extract HTML from JSON output (parse_markdown.py outputs JSON with "html" field)
HTML_CONTENT=$(echo "$PARSE_RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data['html'])")
TITLE=$(echo "$PARSE_RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data['title'])")
TOTAL_BLOCKS=$(echo "$PARSE_RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data['total_blocks'])")
COVER_IMAGE=$(echo "$PARSE_RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('cover_image') or 'none')")
CONTENT_IMAGES=$(echo "$PARSE_RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(len(data.get('content_images', [])))")
DIVIDERS=$(echo "$PARSE_RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(len(data.get('dividers', [])))")

echo "[2/3] Article info:"
echo "  Title: $TITLE"
echo "  Blocks: $TOTAL_BLOCKS"
echo "  Cover image: $COVER_IMAGE"
echo "  Content images: $CONTENT_IMAGES"
echo "  Dividers: $DIVIDERS"

echo "[3/3] Copying HTML to clipboard..."
nix shell --impure --expr "$NIX_EXPR" --command python3 "$SCRIPT_DIR/copy_to_clipboard.py" html "$HTML_CONTENT"

echo ""
echo "Done! Rich text is in clipboard."
echo "Open X Articles editor and Cmd+V to paste."

if [ "$COVER_IMAGE" != "none" ]; then
    echo ""
    echo "Cover image needs manual upload: $COVER_IMAGE"
fi

if [ "$CONTENT_IMAGES" -gt 0 ]; then
    echo ""
    echo "Content images need manual insertion ($CONTENT_IMAGES images)."
    echo "Run with --json flag for position details:"
    echo "  nix shell --impure --expr '$NIX_EXPR' --command python3 $SCRIPT_DIR/parse_markdown.py $MARKDOWN_FILE"
fi
