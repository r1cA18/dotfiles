#!/bin/bash
# 音声認識（Whisper）スクリプト

INPUT=$1
OUTPUT=${2:-transcript.json}
FORMAT=${3:-json}

if [ -z "$INPUT" ]; then
    echo "Usage: transcribe.sh <input_video_or_audio> [output_file] [format]"
    echo ""
    echo "Formats: json, srt, vtt, txt"
    echo ""
    echo "Examples:"
    echo "  transcribe.sh video.mp4                    # JSON出力"
    echo "  transcribe.sh video.mp4 subtitle.srt srt   # SRT字幕"
    echo "  transcribe.sh audio.wav transcript.json    # 音声ファイルから"
    exit 1
fi

if [ ! -f "$INPUT" ]; then
    echo "Error: Input file not found: $INPUT"
    exit 1
fi

# whisper_timestamped が利用可能か確認
if ! command -v whisper_timestamped &> /dev/null; then
    echo "Error: whisper_timestamped not found"
    echo ""
    echo "Install with: pip install whisper-timestamped"
    exit 1
fi

# 入力が動画の場合は音声を抽出
INPUT_EXT="${INPUT##*.}"
AUDIO_FILE="$INPUT"

if [[ "$INPUT_EXT" =~ ^(mp4|mov|avi|mkv|webm)$ ]]; then
    echo "Extracting audio from video..."
    AUDIO_FILE="/tmp/whisper_audio_$$.wav"
    ffmpeg -i "$INPUT" -vn -ar 16000 -ac 1 "$AUDIO_FILE" -y
fi

echo "Transcribing audio..."
echo "Input: $INPUT"
echo "Output: $OUTPUT"
echo "Format: $FORMAT"
echo ""

whisper_timestamped "$AUDIO_FILE" --output_format "$FORMAT" > "$OUTPUT"

# 一時ファイルを削除
if [ "$AUDIO_FILE" != "$INPUT" ]; then
    rm -f "$AUDIO_FILE"
fi

if [ -f "$OUTPUT" ]; then
    echo ""
    echo "Done! Created: $OUTPUT"
else
    echo ""
    echo "Error: Failed to create output file"
    exit 1
fi
