#!/bin/bash
# 動画をカットするスクリプト

INPUT=$1
OUTPUT=$2
START=$3
END=$4

if [ -z "$INPUT" ] || [ -z "$OUTPUT" ] || [ -z "$START" ]; then
    echo "Usage: cut-video.sh <input> <output> <start_time> [end_time]"
    echo ""
    echo "Time format: HH:MM:SS or SS"
    echo ""
    echo "Examples:"
    echo "  cut-video.sh input.mp4 output.mp4 00:00:30 00:01:00  # 30秒〜1分"
    echo "  cut-video.sh input.mp4 output.mp4 30 60              # 同上（秒指定）"
    echo "  cut-video.sh input.mp4 output.mp4 00:01:00           # 1分から最後まで"
    exit 1
fi

if [ ! -f "$INPUT" ]; then
    echo "Error: Input file not found: $INPUT"
    exit 1
fi

echo "Cutting video..."
echo "Input: $INPUT"
echo "Output: $OUTPUT"
echo "Start: $START"
[ -n "$END" ] && echo "End: $END"

if [ -n "$END" ]; then
    ffmpeg -ss "$START" -to "$END" -i "$INPUT" -c copy "$OUTPUT"
else
    ffmpeg -ss "$START" -i "$INPUT" -c copy "$OUTPUT"
fi

if [ -f "$OUTPUT" ]; then
    echo ""
    echo "Done! Created: $OUTPUT"
else
    echo ""
    echo "Error: Failed to create output file"
    exit 1
fi
