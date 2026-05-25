#!/bin/bash
# 動画フォーマット変換スクリプト

INPUT=$1
OUTPUT=$2

if [ -z "$INPUT" ] || [ -z "$OUTPUT" ]; then
    echo "Usage: convert-video.sh <input> <output>"
    echo ""
    echo "Output format is determined by file extension."
    echo ""
    echo "Examples:"
    echo "  convert-video.sh input.mov output.mp4     # MOV → MP4"
    echo "  convert-video.sh input.mp4 output.webm    # MP4 → WebM"
    echo "  convert-video.sh input.mp4 output.gif     # MP4 → GIF"
    exit 1
fi

if [ ! -f "$INPUT" ]; then
    echo "Error: Input file not found: $INPUT"
    exit 1
fi

echo "Converting video..."
echo "Input: $INPUT"
echo "Output: $OUTPUT"
echo ""

# 拡張子に基づいて変換オプションを設定
OUTPUT_EXT="${OUTPUT##*.}"

case "$OUTPUT_EXT" in
    gif)
        echo "Creating GIF with optimized palette..."
        ffmpeg -i "$INPUT" -vf "fps=10,scale=480:-1,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 "$OUTPUT"
        ;;
    webm)
        echo "Converting to WebM (VP9)..."
        ffmpeg -i "$INPUT" -c:v libvpx-vp9 -c:a libopus "$OUTPUT"
        ;;
    *)
        ffmpeg -i "$INPUT" "$OUTPUT"
        ;;
esac

if [ -f "$OUTPUT" ]; then
    echo ""
    echo "Done! Created: $OUTPUT"
else
    echo ""
    echo "Error: Failed to create output file"
    exit 1
fi
