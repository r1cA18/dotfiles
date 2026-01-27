# テンプレート集

FFmpeg コマンドと FrameScript コードのよく使うテンプレート。

---

## FFmpeg テンプレート

### 動画カット

```bash
# シンプルカット（再エンコードなし、高速）
ffmpeg -ss 00:00:30 -to 00:01:00 -i input.mp4 -c copy output.mp4

# 精密カット（キーフレームに依存しない）
ffmpeg -i input.mp4 -ss 00:00:30 -to 00:01:00 -c:v libx264 -c:a aac output.mp4
```

### GIF作成

```bash
# シンプルGIF
ffmpeg -i input.mp4 -vf "fps=10,scale=480:-1" -loop 0 output.gif

# 高品質GIF（パレット最適化）
ffmpeg -i input.mp4 -vf "fps=10,scale=480:-1,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" output.gif

# 特定区間をGIFに
ffmpeg -ss 00:00:05 -t 3 -i input.mp4 -vf "fps=15,scale=320:-1" output.gif
```

### 音声抽出

```bash
# MP3で抽出
ffmpeg -i input.mp4 -vn -acodec libmp3lame -q:a 2 output.mp3

# WAVで抽出（Whisper用）
ffmpeg -i input.mp4 -vn -ar 16000 -ac 1 output.wav
```

### サムネイル生成

```bash
# 動画の最初のフレーム
ffmpeg -i input.mp4 -frames:v 1 thumbnail.png

# 指定時間のフレーム
ffmpeg -ss 00:00:10 -i input.mp4 -frames:v 1 thumbnail.png

# 複数サムネイル（10秒ごと）
ffmpeg -i input.mp4 -vf "fps=1/10" thumbnails/thumb%03d.png
```

### 動画結合

```bash
# filelist.txt を作成
cat > filelist.txt << EOF
file 'clip1.mp4'
file 'clip2.mp4'
file 'clip3.mp4'
EOF

# 結合
ffmpeg -f concat -safe 0 -i filelist.txt -c copy output.mp4
```

### 字幕埋め込み

```bash
# SRT字幕を焼き込み
ffmpeg -i input.mp4 -vf "subtitles=subtitle.srt" output.mp4

# フォント指定
ffmpeg -i input.mp4 -vf "subtitles=subtitle.srt:force_style='FontSize=24,FontName=Arial'" output.mp4
```

---

## FrameScript テンプレート

### 基本プロジェクト

```tsx
import { Project, TimeLine, Clip } from '@frame-script/core';

export default function MyProject() {
  return (
    <Project width={1920} height={1080} fps={30} duration={10}>
      <TimeLine>
        <Clip start={0} duration={10}>
          <div style={{
            width: '100%',
            height: '100%',
            backgroundColor: '#1a1a2e',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}>
            <h1 style={{ color: 'white', fontSize: '72px' }}>
              Hello World
            </h1>
          </div>
        </Clip>
      </TimeLine>
    </Project>
  );
}
```

### フェードイン テキスト

```tsx
import {
  Project, TimeLine, Clip,
  useAnimation, useVariable, BEZIER_SMOOTH
} from '@frame-script/core';

function FadeInText({ text }: { text: string }) {
  const opacity = useVariable(0);
  const y = useVariable(30);

  useAnimation(async (ctx) => {
    await ctx.parallel(
      ctx.move(opacity).to(1, 0.8, BEZIER_SMOOTH),
      ctx.move(y).to(0, 0.8, BEZIER_SMOOTH)
    );
  });

  return (
    <div style={{
      position: 'absolute',
      top: '50%',
      left: '50%',
      transform: `translate(-50%, calc(-50% + ${y.value}px))`,
      opacity: opacity.value,
      fontSize: '64px',
      fontWeight: 'bold',
      color: 'white',
    }}>
      {text}
    </div>
  );
}

export default function MyProject() {
  return (
    <Project width={1920} height={1080} fps={30} duration={5}>
      <TimeLine>
        <Clip start={0} duration={5}>
          <div style={{ width: '100%', height: '100%', backgroundColor: '#000' }}>
            <FadeInText text="Welcome" />
          </div>
        </Clip>
      </TimeLine>
    </Project>
  );
}
```

### スライドショー

```tsx
import {
  Project, TimeLine, Clip, Image,
  useAnimation, useVariable, BEZIER_SMOOTH
} from '@frame-script/core';

const images = [
  '/public/image1.jpg',
  '/public/image2.jpg',
  '/public/image3.jpg',
];

function SlideImage({ src }: { src: string }) {
  const opacity = useVariable(0);
  const scale = useVariable(1.1);

  useAnimation(async (ctx) => {
    await ctx.parallel(
      ctx.move(opacity).to(1, 0.5, BEZIER_SMOOTH),
      ctx.move(scale).to(1, 3, BEZIER_SMOOTH)
    );
    await ctx.wait(0.5);
    await ctx.move(opacity).to(0, 0.5, BEZIER_SMOOTH);
  });

  return (
    <div style={{
      width: '100%',
      height: '100%',
      opacity: opacity.value,
      transform: `scale(${scale.value})`,
      backgroundImage: `url(${src})`,
      backgroundSize: 'cover',
      backgroundPosition: 'center',
    }} />
  );
}

export default function Slideshow() {
  return (
    <Project width={1920} height={1080} fps={30} duration={12}>
      <TimeLine>
        {images.map((src, i) => (
          <Clip key={i} start={i * 4} duration={4}>
            <SlideImage src={src} />
          </Clip>
        ))}
      </TimeLine>
    </Project>
  );
}
```

### タイトルカード

```tsx
import {
  Project, TimeLine, Clip,
  useAnimation, useVariable, BEZIER_SMOOTH
} from '@frame-script/core';

function TitleCard({ title, subtitle }: { title: string; subtitle: string }) {
  const titleY = useVariable(-50);
  const titleOpacity = useVariable(0);
  const subtitleOpacity = useVariable(0);
  const lineWidth = useVariable(0);

  useAnimation(async (ctx) => {
    // タイトル登場
    await ctx.parallel(
      ctx.move(titleY).to(0, 0.6, BEZIER_SMOOTH),
      ctx.move(titleOpacity).to(1, 0.6, BEZIER_SMOOTH)
    );
    // ライン展開
    await ctx.move(lineWidth).to(200, 0.4, BEZIER_SMOOTH);
    // サブタイトル登場
    await ctx.move(subtitleOpacity).to(1, 0.4, BEZIER_SMOOTH);
  });

  return (
    <div style={{
      width: '100%',
      height: '100%',
      backgroundColor: '#1a1a2e',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
    }}>
      <h1 style={{
        color: 'white',
        fontSize: '96px',
        fontWeight: 'bold',
        transform: `translateY(${titleY.value}px)`,
        opacity: titleOpacity.value,
        margin: 0,
      }}>
        {title}
      </h1>
      <div style={{
        width: `${lineWidth.value}px`,
        height: '4px',
        backgroundColor: '#e94560',
        margin: '20px 0',
      }} />
      <p style={{
        color: '#888',
        fontSize: '32px',
        opacity: subtitleOpacity.value,
        margin: 0,
      }}>
        {subtitle}
      </p>
    </div>
  );
}

export default function MyProject() {
  return (
    <Project width={1920} height={1080} fps={30} duration={5}>
      <TimeLine>
        <Clip start={0} duration={5}>
          <TitleCard title="My Video" subtitle="Created with FrameScript" />
        </Clip>
      </TimeLine>
    </Project>
  );
}
```

### 下から上へのテキストスクロール（エンドロール風）

```tsx
import {
  Project, TimeLine, Clip,
  useAnimation, useVariable, BEZIER_LINEAR
} from '@frame-script/core';

const credits = [
  'Director: John Doe',
  'Producer: Jane Smith',
  'Camera: Bob Johnson',
  'Editor: Alice Williams',
  'Music: Charlie Brown',
];

function EndRoll() {
  const y = useVariable(1080);

  useAnimation(async (ctx) => {
    await ctx.move(y).to(-credits.length * 80 - 100, 10, BEZIER_LINEAR);
  });

  return (
    <div style={{
      width: '100%',
      height: '100%',
      backgroundColor: '#000',
      overflow: 'hidden',
    }}>
      <div style={{
        position: 'absolute',
        left: '50%',
        transform: `translate(-50%, ${y.value}px)`,
        textAlign: 'center',
      }}>
        {credits.map((credit, i) => (
          <p key={i} style={{
            color: 'white',
            fontSize: '48px',
            margin: '20px 0',
          }}>
            {credit}
          </p>
        ))}
      </div>
    </div>
  );
}

export default function MyProject() {
  return (
    <Project width={1920} height={1080} fps={30} duration={12}>
      <TimeLine>
        <Clip start={0} duration={12}>
          <EndRoll />
        </Clip>
      </TimeLine>
    </Project>
  );
}
```
