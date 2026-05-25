#!/bin/bash
set -euo pipefail

FRAME="${1:?Usage: $0 <frame.png> <screenshot.png> <output.png> [device]}"
SCREENSHOT="${2:?Usage: $0 <frame.png> <screenshot.png> <output.png> [device]}"
OUTPUT="${3:?Usage: $0 <frame.png> <screenshot.png> <output.png> [device]}"
DEVICE="${4:-iphone}"

FRAME_W=$(magick identify -format "%w" "$FRAME")
FRAME_H=$(magick identify -format "%h" "$FRAME")

case "$DEVICE" in
  iphone)
    # iPhone screen area: left=5.08%, top=2.21%, width=89.82%, height=95.59%
    SCREEN_X=$((FRAME_W * 508 / 10000))
    SCREEN_Y=$((FRAME_H * 221 / 10000))
    SCREEN_W=$((FRAME_W * 8982 / 10000))
    SCREEN_H=$((FRAME_H * 9559 / 10000))
    CORNER_R=$((SCREEN_W * 1371 / 10000))
    ;;
  android)
    # Android screen area: left=3.5%, top=2%, width=93%, height=96%
    SCREEN_X=$((FRAME_W * 350 / 10000))
    SCREEN_Y=$((FRAME_H * 200 / 10000))
    SCREEN_W=$((FRAME_W * 9300 / 10000))
    SCREEN_H=$((FRAME_H * 9600 / 10000))
    CORNER_R=$((SCREEN_W * 550 / 10000))
    ;;
  ipad)
    # iPad screen area: left=4%, top=2.8%, width=92%, height=94.4%
    SCREEN_X=$((FRAME_W * 400 / 10000))
    SCREEN_Y=$((FRAME_H * 280 / 10000))
    SCREEN_W=$((FRAME_W * 9200 / 10000))
    SCREEN_H=$((FRAME_H * 9440 / 10000))
    CORNER_R=$((SCREEN_W * 220 / 10000))
    ;;
  *)
    echo "Unknown device: $DEVICE (options: iphone, android, ipad)"
    exit 1
    ;;
esac

magick "$SCREENSHOT" \
  -resize "${SCREEN_W}x${SCREEN_H}!" \
  \( +clone -alpha extract \
     -draw "fill black rectangle 0,0 ${SCREEN_W},${SCREEN_H}" \
     -draw "fill white roundrectangle 0,0 $((SCREEN_W-1)),$((SCREEN_H-1)) ${CORNER_R},${CORNER_R}" \
     -alpha off \) \
  -compose CopyOpacity -composite \
  /tmp/_screenshot_masked.png

magick "$FRAME" \
  /tmp/_screenshot_masked.png \
  -geometry "+${SCREEN_X}+${SCREEN_Y}" \
  -compose Over -composite \
  "$OUTPUT"

rm -f /tmp/_screenshot_masked.png
echo "Composited: $OUTPUT"
