#!/bin/bash
# 動画からフレームを抽出するスクリプト

INPUT=$1
OUTPUT_DIR=${2:-frames}
FPS=${3:-1}

if [ -z "$INPUT" ]; then
    echo "Usage: extract-frames.sh <input_video> [output_dir] [fps]"
    echo ""
    echo "Examples:"
    echo "  extract-frames.sh video.mp4              # 1秒ごとにframes/へ"
    echo "  extract-frames.sh video.mp4 output 0.5   # 2秒ごとにoutput/へ"
    echo "  extract-frames.sh video.mp4 frames 2     # 0.5秒ごとに"
    exit 1
fi

if [ ! -f "$INPUT" ]; then
    echo "Error: Input file not found: $INPUT"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "Extracting frames from: $INPUT"
echo "Output directory: $OUTPUT_DIR"
echo "FPS: $FPS (1 frame every $(echo "scale=2; 1/$FPS" | bc) seconds)"
echo ""

ffmpeg -i "$INPUT" -vf "fps=$FPS" "$OUTPUT_DIR/frame%04d.png"

COUNT=$(find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.png' | wc -l | tr -d ' ')
echo ""
echo "Done! Extracted $COUNT frames to $OUTPUT_DIR/"
