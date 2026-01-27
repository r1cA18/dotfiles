# 動画解析ガイド

動画の内容を確認・解析するための方法。Haikuサブエージェントを使ったコスト効率的なアプローチを含む。

## 概要

動画の内容を理解するには、以下の方法がある:

1. **フレーム抽出 + 視覚解析** - FFmpegでフレーム抽出 → Claudeで画像解析
2. **音声認識** - Whisperで音声→テキスト変換
3. **両方組み合わせ** - 映像と音声の両方を解析

## フレーム抽出（FFmpeg）

### 1秒ごとにフレーム抽出

```bash
mkdir -p frames
ffmpeg -i input.mp4 -vf "fps=1" frames/frame%04d.png
```

### 特定時間のフレームを抽出

```bash
# 1分30秒のフレーム
ffmpeg -ss 00:01:30 -i input.mp4 -frames:v 1 screenshot.png

# 1分30秒〜1分40秒の範囲（1秒ごと）
ffmpeg -ss 00:01:30 -to 00:01:40 -i input.mp4 -vf "fps=1" frames/frame%04d.png
```

### N秒ごとにフレーム抽出

```bash
# 5秒ごと
ffmpeg -i input.mp4 -vf "fps=1/5" frames/frame%04d.png

# 10秒ごと
ffmpeg -i input.mp4 -vf "fps=1/10" frames/frame%04d.png
```

### キーフレームのみ抽出

```bash
ffmpeg -i input.mp4 -vf "select='eq(pict_type,I)'" -vsync vfr frames/keyframe%04d.png
```

## コスト効率的なフレーム解析

### Haikuサブエージェント戦略

画像解析にOpusを直接使うとコストが高い。代わりに:

1. FFmpegでフレーム抽出
2. **Taskツールで frame-analyzer（Haiku）を起動**
3. Haikuがフレームを読み込みテキスト化
4. テキスト結果を元にメインエージェントが回答

### フレーム解析の呼び出し例

```
Taskツールで frame-analyzer エージェントを起動し、
frames/ ディレクトリ内の画像を解析してください。
各フレームの内容をタイムスタンプ付きで記述してください。
```

### コスト比較

| 処理 | Opus直接 | Haiku委譲 |
|-----|---------|----------|
| 10フレーム解析 | ~$1.50 | ~$0.025 |
| 60フレーム（1分動画）| ~$9.00 | ~$0.15 |
| 300フレーム（5分動画）| ~$45.00 | ~$0.75 |

**約60倍のコスト削減**

## 音声認識（Whisper）

### whisper-timestamped のインストール

```bash
pip install whisper-timestamped
```

### 音声抽出 + 認識

```bash
# 1. 音声をWAVで抽出（Whisper推奨形式）
ffmpeg -i input.mp4 -vn -ar 16000 -ac 1 audio.wav

# 2. Whisperで認識
whisper_timestamped audio.wav --output_format json > transcript.json
```

### 出力形式

```json
{
  "text": "全文テキスト...",
  "segments": [
    {
      "start": 0.0,
      "end": 2.5,
      "text": "こんにちは",
      "words": [
        {"word": "こんにちは", "start": 0.0, "end": 1.2}
      ]
    }
  ]
}
```

### WhisperX（高速版）

```bash
pip install whisperx

# 実行（GPU推奨）
whisperx audio.wav --output_format json
```

### 字幕ファイル生成

```bash
# SRT形式
whisper_timestamped audio.wav --output_format srt > subtitle.srt

# WebVTT形式
whisper_timestamped audio.wav --output_format vtt > subtitle.vtt
```

## 実践的なワークフロー

### ワークフロー1: 動画の特定シーンを探す

```bash
# 1. 5秒ごとにフレーム抽出
ffmpeg -i input.mp4 -vf "fps=1/5" frames/frame%04d.png

# 2. frame-analyzer（Haiku）で解析
# → 「人物登場」「テロップ表示」などのシーンをテキスト化

# 3. 目的のシーンの時間を特定

# 4. その周辺を詳細に抽出
ffmpeg -ss 00:02:30 -to 00:02:40 -i input.mp4 -vf "fps=2" detail/frame%04d.png
```

### ワークフロー2: 動画全体の要約

```bash
# 1. キーフレーム抽出
ffmpeg -i input.mp4 -vf "select='eq(pict_type,I)'" -vsync vfr frames/key%04d.png

# 2. 音声認識
ffmpeg -i input.mp4 -vn -ar 16000 -ac 1 audio.wav
whisper_timestamped audio.wav --output_format json > transcript.json

# 3. 映像と音声の情報を組み合わせて要約
```

### ワークフロー3: 字幕作成

```bash
# 1. 音声抽出
ffmpeg -i input.mp4 -vn -ar 16000 -ac 1 audio.wav

# 2. 字幕生成
whisper_timestamped audio.wav --output_format srt > subtitle.srt

# 3. 字幕を動画に焼き込み
ffmpeg -i input.mp4 -vf "subtitles=subtitle.srt" output_with_subs.mp4
```

## frame-analyzer エージェントの使い方

`~/.claude/agents/frame-analyzer.md` に定義されたHaikuエージェント。

### 基本的な使い方

```
frame-analyzer エージェントを使って、
frames/ ディレクトリ内の画像を解析して、
各フレームの内容をテキストで記述してください。
```

### 出力例

```
## フレーム解析結果

- frame0001.png (0:00): 黒い背景にタイトルテキスト「Introduction」が表示
- frame0002.png (0:01): 男性がカメラに向かって話している、オフィス背景
- frame0003.png (0:02): 画面右上に「Chapter 1」のテロップ
- frame0004.png (0:03): 製品の写真がズームアップで表示
...
```

## トラブルシューティング

### フレームが多すぎる

- 抽出間隔を広げる（`fps=1/5` で5秒ごと）
- キーフレームのみ抽出

### Whisperが遅い

- WhisperXを使用（GPU利用で高速）
- 小さいモデルを使用（`--model small`）

### メモリ不足

- 動画を分割して処理
- フレーム抽出時に解像度を下げる（`scale=640:-1`）
