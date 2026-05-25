---
name: video-editing
description: |
  完全版動画編集スキル。FFmpeg（高速処理）+ FrameScript（クリエイティブ編集）のいいとこ取り。
  使用タイミング: 動画編集、動画変換、カット、トリミング、フレーム抽出、
  アニメーション作成、モーショングラフィックス、動画の内容確認、字幕作成、video。
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Video Editing Skill

FFmpeg + FrameScript のいいとこ取り。状況に応じて最適なツールを組み合わせる。

## ツールの強み

| FFmpeg | FrameScript |
|--------|-------------|
| 高速カット（再エンコードなし） | テキスト/画像オーバーレイ |
| フォーマット変換 | アニメーション効果 |
| フレーム抽出 | 複数動画の合成 |
| 音声処理 | プログラマティック編集 |
| バッチ処理 | プレビュー確認 |

## 組み合わせワークフロー例

### 例1: 動画カット + タイトル追加

```
1. FFmpegで必要な部分をカット（高速）
   ffmpeg -ss 00:00:30 -to 00:01:00 -i input.mp4 -c copy clip.mp4

2. FrameScriptでタイトル/エフェクト追加
   <Video src="clip.mp4" />
   <TitleCard text="My Video" />

3. レンダリングで最終出力
```

### 例2: 複数動画の結合 + トランジション

```
1. FFmpegで各動画を必要な長さにカット
2. FrameScriptでタイムラインに配置 + トランジション追加
3. レンダリング
```

### 例3: 動画内容確認 + 編集

```
1. FFmpegでフレーム抽出
2. frame-analyzer（Haiku）で内容をテキスト化（低コスト）
3. 編集方針を決定
4. FFmpeg or FrameScript で編集実行
```

### 例4: 字幕作成 + 焼き込み

```
1. FFmpegで音声抽出
2. Whisperで字幕生成（SRT）
3. 選択肢:
   - FFmpegで焼き込み（シンプル）
   - FrameScriptでスタイリッシュな字幕（カスタマイズ）
```

## クイックリファレンス

### FFmpeg（高速処理向け）

```bash
# カット
ffmpeg -ss 00:00:30 -to 00:01:00 -i input.mp4 -c copy output.mp4

# 変換
ffmpeg -i input.mov output.mp4

# フレーム抽出
ffmpeg -i input.mp4 -vf "fps=1" frames/frame%04d.png

# 音声抽出
ffmpeg -i input.mp4 -vn output.mp3

# GIF作成
ffmpeg -i input.mp4 -vf "fps=10,scale=480:-1" output.gif
```

### FrameScript（クリエイティブ編集向け）

```bash
# プロジェクト作成
bunx @frame-script/create-frame-script my-project
cd my-project && bun install

# プレビュー
bun run start

# レンダリング
bun run render
```

```tsx
// 既存動画 + オーバーレイ
<Project width={1920} height={1080} fps={30} duration={10}>
  <TimeLine>
    <Clip start={0} duration={10}>
      <Video src="/public/video.mp4" />
      <div style={{ position: 'absolute', bottom: 50, color: 'white' }}>
        テキストオーバーレイ
      </div>
    </Clip>
  </TimeLine>
</Project>
```

## 判断基準

**FFmpegを使う場面:**
- 単純なカット/トリミング → `-c copy` で再エンコードなし、超高速
- フォーマット変換
- フレーム/音声抽出
- バッチ処理（複数ファイル）

**FrameScriptを使う場面:**
- テキスト/画像のオーバーレイ
- アニメーション効果
- 複数動画のレイヤー合成
- プレビューしながら調整したい時

**組み合わせる場面:**
- 「カットしてからタイトル追加」
- 「複数動画を結合してトランジション」
- 「字幕をスタイリッシュに」

## コスト最適化（動画内容確認）

動画の内容確認には **Haikuサブエージェント** を使用:

```
1. FFmpegでフレーム抽出
2. Taskツールで frame-analyzer（Haiku）起動
3. Haikuがフレームを読み込みテキスト化
4. 結果を元に回答
```

**コスト比較:**
- Opus直接: ~$1.50/10フレーム
- Haiku委譲: ~$0.025/10フレーム（約60倍削減）

## 詳細リファレンス

- [FFMPEG.md](FFMPEG.md) - FFmpegコマンド詳細
- [FRAMESCRIPT.md](FRAMESCRIPT.md) - FrameScript API詳細
- [TEMPLATES.md](TEMPLATES.md) - コピペで使えるテンプレート
- [ANALYSIS.md](ANALYSIS.md) - 動画解析・内容確認

## 前提条件

- **FFmpeg** - `brew install ffmpeg`
- **Bun** - `curl -fsSL https://bun.sh/install | bash`
- **Whisper**（オプション）- `pip install whisper-timestamped`
