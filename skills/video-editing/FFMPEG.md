# FFmpeg コマンドリファレンス

動画の処理・変換・抽出に使用するFFmpegコマンド集。

## 基本構文

```bash
ffmpeg [入力オプション] -i 入力ファイル [出力オプション] 出力ファイル
```

## 動画カット・トリミング

### 時間指定でカット

```bash
# 開始時間から終了時間まで（再エンコードなし、高速）
ffmpeg -ss 00:00:30 -to 00:01:00 -i input.mp4 -c copy output.mp4

# 開始時間から指定秒数（再エンコードなし）
ffmpeg -ss 00:00:30 -t 30 -i input.mp4 -c copy output.mp4

# 精密カット（キーフレームに依存しない、遅いが正確）
ffmpeg -i input.mp4 -ss 00:00:30 -to 00:01:00 -c:v libx264 -c:a aac output.mp4
```

### 時間形式

- `00:01:30` - 時:分:秒
- `90` - 秒数
- `00:01:30.500` - ミリ秒含む

## フォーマット変換

```bash
# MOV → MP4
ffmpeg -i input.mov output.mp4

# MP4 → WebM（VP9）
ffmpeg -i input.mp4 -c:v libvpx-vp9 -c:a libopus output.webm

# MP4 → GIF（ループあり）
ffmpeg -i input.mp4 -vf "fps=10,scale=480:-1" -loop 0 output.gif

# 高品質GIF（パレット生成）
ffmpeg -i input.mp4 -vf "fps=10,scale=480:-1,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" output.gif
```

## フレーム抽出

```bash
# 全フレーム抽出（注意: 大量のファイルが生成される）
ffmpeg -i input.mp4 frames/frame%04d.png

# 1秒ごとに抽出
ffmpeg -i input.mp4 -vf "fps=1" frames/frame%04d.png

# N秒ごとに抽出
ffmpeg -i input.mp4 -vf "fps=1/3" frames/frame%04d.png  # 3秒ごと

# 特定時間のフレームを1枚抽出
ffmpeg -ss 00:01:30 -i input.mp4 -frames:v 1 screenshot.png

# 時間範囲内のフレーム抽出
ffmpeg -ss 00:01:00 -to 00:01:10 -i input.mp4 -vf "fps=1" frames/frame%04d.png
```

## 音声処理

```bash
# 音声抽出（そのままのコーデック）
ffmpeg -i input.mp4 -vn -acodec copy output.aac

# 音声抽出（MP3に変換）
ffmpeg -i input.mp4 -vn -acodec libmp3lame -q:a 2 output.mp3

# 音声抽出（WAV）
ffmpeg -i input.mp4 -vn output.wav

# 音声削除（無音動画）
ffmpeg -i input.mp4 -an -c:v copy output.mp4

# 音声置換
ffmpeg -i video.mp4 -i audio.mp3 -c:v copy -map 0:v:0 -map 1:a:0 output.mp4
```

## 解像度・サイズ変更

```bash
# 指定解像度にリサイズ
ffmpeg -i input.mp4 -vf "scale=1280:720" output.mp4

# アスペクト比維持（幅指定）
ffmpeg -i input.mp4 -vf "scale=1280:-1" output.mp4

# アスペクト比維持（高さ指定）
ffmpeg -i input.mp4 -vf "scale=-1:720" output.mp4

# 偶数に丸める（コーデック互換性）
ffmpeg -i input.mp4 -vf "scale=1280:-2" output.mp4
```

## 動画結合

```bash
# ファイルリストから結合（同じコーデックの場合）
# filelist.txt:
#   file 'clip1.mp4'
#   file 'clip2.mp4'
#   file 'clip3.mp4'
ffmpeg -f concat -safe 0 -i filelist.txt -c copy output.mp4

# 異なるコーデックの結合（再エンコード）
ffmpeg -f concat -safe 0 -i filelist.txt -c:v libx264 -c:a aac output.mp4
```

## フィルター

```bash
# 回転
ffmpeg -i input.mp4 -vf "transpose=1" output.mp4  # 90度時計回り
ffmpeg -i input.mp4 -vf "transpose=2" output.mp4  # 90度反時計回り

# 反転
ffmpeg -i input.mp4 -vf "hflip" output.mp4  # 水平反転
ffmpeg -i input.mp4 -vf "vflip" output.mp4  # 垂直反転

# 速度変更
ffmpeg -i input.mp4 -vf "setpts=0.5*PTS" -af "atempo=2.0" output.mp4  # 2倍速
ffmpeg -i input.mp4 -vf "setpts=2.0*PTS" -af "atempo=0.5" output.mp4  # 0.5倍速

# クロップ（切り抜き）
ffmpeg -i input.mp4 -vf "crop=640:480:100:50" output.mp4  # width:height:x:y

# フェードイン/アウト
ffmpeg -i input.mp4 -vf "fade=in:0:30,fade=out:870:30" output.mp4
```

## 動画情報取得

```bash
# 詳細情報表示
ffprobe -v quiet -print_format json -show_format -show_streams input.mp4

# 再生時間取得
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 input.mp4

# 解像度取得
ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 input.mp4
```

## よく使うオプション

| オプション | 説明 |
|-----------|------|
| `-c copy` | 再エンコードなし（高速） |
| `-c:v libx264` | H.264エンコード |
| `-c:a aac` | AACオーディオエンコード |
| `-crf 23` | 品質指定（18-28、低いほど高品質） |
| `-preset fast` | エンコード速度（ultrafast/fast/medium/slow） |
| `-y` | 上書き確認なし |
| `-n` | 上書きしない |
| `-vn` | 映像なし |
| `-an` | 音声なし |
