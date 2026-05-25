#!/bin/bash
set -euo pipefail

INPUT_DIR="${1:?Usage: $0 <input-dir> <output-dir> [device]}"
OUTPUT_DIR="${2:?Usage: $0 <input-dir> <output-dir> [device]}"
DEVICE="${3:-iphone}"

declare -a SIZES LABELS

case "$DEVICE" in
  iphone)
    SIZES=("1320x2868" "1284x2778" "1206x2622" "1125x2436")
    LABELS=('6.9"' '6.5"' '6.3"' '6.1"')
    ;;
  ipad)
    SIZES=("2064x2752" "2048x2732")
    LABELS=('13"' '12.9" Pro')
    ;;
  android)
    SIZES=("1080x1920")
    LABELS=("phone")
    ;;
  android-7)
    SIZES=("1200x1920" "1920x1200")
    LABELS=('7" portrait' '7" landscape')
    ;;
  android-10)
    SIZES=("1600x2560" "2560x1600")
    LABELS=('10" portrait' '10" landscape')
    ;;
  feature-graphic)
    SIZES=("1024x500")
    LABELS=("banner")
    ;;
  all)
    echo "Generating all device sizes..."
    "$0" "$INPUT_DIR" "$OUTPUT_DIR/ios/iphone" iphone
    "$0" "$INPUT_DIR" "$OUTPUT_DIR/ios/ipad" ipad
    "$0" "$INPUT_DIR" "$OUTPUT_DIR/android/phone" android
    "$0" "$INPUT_DIR" "$OUTPUT_DIR/android/feature-graphic" feature-graphic
    echo "Done."
    exit 0
    ;;
  *)
    echo "Unknown device: $DEVICE"
    echo "Options: iphone, ipad, android, android-7, android-10, feature-graphic, all"
    exit 1
    ;;
esac

for file in "$INPUT_DIR"/*.png; do
  [ -f "$file" ] || continue
  base=$(basename "$file" .png)
  for i in "${!SIZES[@]}"; do
    size="${SIZES[$i]}"
    label="${LABELS[$i]}"
    outdir="$OUTPUT_DIR/$size"
    mkdir -p "$outdir"
    magick "$file" -resize "${size}^" -gravity center -extent "$size" "$outdir/${base}.png"
    echo "  $base -> $size ($label)"
  done
done
