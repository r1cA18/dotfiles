#!/bin/bash
set -euo pipefail

INPUT="${1:?Usage: $0 <input.png> <output.png> <text> [options]}"
OUTPUT="${2:?Usage: $0 <input.png> <output.png> <text> [options]}"
TEXT="${3:?Usage: $0 <input.png> <output.png> <text> [options]}"
FONT="${4:-Inter-Bold}"
SIZE="${5:-96}"
COLOR="${6:-#FFFFFF}"
GRAVITY="${7:-North}"
OFFSET="${8:-+0+200}"

magick "$INPUT" \
  -font "$FONT" \
  -pointsize "$SIZE" \
  -fill "$COLOR" \
  -gravity "$GRAVITY" \
  -annotate "$OFFSET" "$TEXT" \
  "$OUTPUT"

echo "Text overlaid: $OUTPUT"
