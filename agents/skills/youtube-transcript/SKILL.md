---
name: youtube-transcript
description: >-
  YouTube 動画の字幕・音声を取得し、LLM に読ませるためのテキストに変換する。
  トリガー: "youtube 字幕", "youtube 文字起こし", "動画 内容 読ませて", "字幕 取得", "transcribe youtube".
user-invocable: true
---

# YouTube Transcript

YouTube 動画の内容をテキスト化して LLM に渡すための手順。

## 前提

- `yt-dlp` で字幕を取得
- `whisper-ctranslate2` で音声認識（字幕がない場合）
- エイリアス: `yt-sub`, `yt-auto-sub`, `yt-transcribe`

## 1. 字幕がある場合

```bash
yt-sub <URL>
```

手動字幕・自動字幕の両方を `ja.*, en.*` で取得し、SRT ファイルに保存する。
取得した SRT は `Read` tool または `cat` で読める。

## 2. 自動字幕のみの場合

```bash
yt-auto-sub <URL>
```

## 3. 字幕がない場合

```bash
yt-transcribe <URL>
```

`whisper-ctranslate2` のモデルはデフォルト `large-v3-turbo`。日本語動画向けに `--language Japanese` を指定している。
英語の場合は `--language English` を上書きする。

```bash
yt-transcribe <URL> -- --language English
```

## 4. 直接音声をパイプで渡す

```bash
yt-dlp -x --audio-format mp3 -o - <URL> | whisper-ctranslate2 --model small --language Japanese -
```

## 注意

- 長い動画は文字起こしに時間がかかる。必要なら `--verbose` を付ける。
- ライブ配信・会員限定動画は取得できない。
- 著作権・利用規約に従い、個人の学習用途で使用する。
