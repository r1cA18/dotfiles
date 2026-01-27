# FrameScript API リファレンス

React + CSSベースの動画作成ツール。コードで動画を定義し、レンダリングする。

## プロジェクト作成

```bash
# 新規プロジェクト作成
bunx @frame-script/create-frame-script my-project
cd my-project && bun install

# プレビュー起動（ブラウザで確認）
bun run start

# レンダリング（動画出力）
bun run render
```

## プロジェクト構造

```
my-project/
├── project/
│   └── project.tsx    # メインのプロジェクトファイル
├── public/            # 静的ファイル（画像、動画など）
├── package.json
└── tsconfig.json
```

## 基本構造

```tsx
import { Project, TimeLine, Clip } from '@frame-script/core';

export default function MyProject() {
  return (
    <Project
      width={1920}
      height={1080}
      fps={30}
      duration={10}  // 秒
    >
      <TimeLine>
        <Clip start={0} duration={5}>
          {/* ここにコンテンツ */}
        </Clip>
      </TimeLine>
    </Project>
  );
}
```

## コアコンポーネント

### Project

プロジェクト全体の設定を定義。

```tsx
<Project
  width={1920}      // 幅（px）
  height={1080}     // 高さ（px）
  fps={30}          // フレームレート
  duration={60}     // 動画の長さ（秒）
>
  {/* ... */}
</Project>
```

### TimeLine

タイムラインコンテナ。複数のClipを配置。

```tsx
<TimeLine>
  <Clip start={0} duration={5}>{/* ... */}</Clip>
  <Clip start={5} duration={5}>{/* ... */}</Clip>
</TimeLine>
```

### Clip

タイムライン上の要素。開始時間と長さを指定。

```tsx
<Clip
  start={0}        // 開始時間（秒）
  duration={5}     // 長さ（秒）
>
  {/* コンテンツ */}
</Clip>
```

### Video

動画ファイルを読み込み。

```tsx
<Video
  src="/public/video.mp4"
  start={0}           // 動画内の開始位置（秒）
  volume={1}          // 音量（0-1）
  style={{ width: '100%', height: '100%' }}
/>
```

### Image

画像を表示。

```tsx
<Image
  src="/public/image.png"
  style={{
    width: '200px',
    height: 'auto',
    position: 'absolute',
    top: '50px',
    left: '100px',
  }}
/>
```

### Frame

特定のフレーム/時間に表示するコンテンツ。

```tsx
<Frame at={2.5}>  {/* 2.5秒時点で表示 */}
  <div>表示されるコンテンツ</div>
</Frame>
```

## アニメーション

### useAnimation フック

細粒度のアニメーション制御。

```tsx
import { useAnimation, useVariable, BEZIER_SMOOTH } from '@frame-script/core';

function AnimatedBox() {
  const x = useVariable(0);
  const opacity = useVariable(0);

  useAnimation(async (ctx) => {
    // 並列実行
    await ctx.parallel(
      ctx.move(x).to(500, 1, BEZIER_SMOOTH),      // 500pxまで1秒で移動
      ctx.move(opacity).to(1, 0.5, BEZIER_SMOOTH) // 不透明度を0.5秒で1に
    );

    // 待機
    await ctx.wait(0.5);

    // 順次実行
    await ctx.move(x).to(0, 1, BEZIER_SMOOTH);
  });

  return (
    <div
      style={{
        transform: `translateX(${x.value}px)`,
        opacity: opacity.value,
      }}
    >
      Animated Content
    </div>
  );
}
```

### useVariable

アニメーション可能な変数を作成。

```tsx
const position = useVariable(0);     // 初期値0
const color = useVariable('#ff0000'); // 色も可
```

### アニメーションメソッド

```tsx
// 値を変更
ctx.move(variable).to(targetValue, duration, easing)

// 並列実行
ctx.parallel(animation1, animation2, ...)

// 順次実行
ctx.sequence(animation1, animation2, ...)

// 待機
ctx.wait(seconds)
```

### イージング関数

```tsx
import {
  BEZIER_LINEAR,    // 線形
  BEZIER_SMOOTH,    // スムーズ
  BEZIER_EASE_IN,   // 加速
  BEZIER_EASE_OUT,  // 減速
  BEZIER_EASE_IN_OUT // 加速→減速
} from '@frame-script/core';
```

## スタイリング

CSSをそのまま使用可能。

```tsx
<div
  style={{
    position: 'absolute',
    top: '50%',
    left: '50%',
    transform: 'translate(-50%, -50%)',
    fontSize: '48px',
    fontWeight: 'bold',
    color: 'white',
    textShadow: '2px 2px 4px rgba(0,0,0,0.5)',
  }}
>
  タイトルテキスト
</div>
```

## テキストアニメーション例

```tsx
function TextAnimation() {
  const y = useVariable(50);
  const opacity = useVariable(0);

  useAnimation(async (ctx) => {
    await ctx.parallel(
      ctx.move(y).to(0, 0.5, BEZIER_SMOOTH),
      ctx.move(opacity).to(1, 0.5, BEZIER_SMOOTH)
    );
  });

  return (
    <div
      style={{
        transform: `translateY(${y.value}px)`,
        opacity: opacity.value,
        fontSize: '64px',
        color: 'white',
      }}
    >
      Hello World
    </div>
  );
}
```

## 完全な例

```tsx
import {
  Project, TimeLine, Clip, Video, Image,
  useAnimation, useVariable, BEZIER_SMOOTH
} from '@frame-script/core';

function TitleCard() {
  const scale = useVariable(0.8);
  const opacity = useVariable(0);

  useAnimation(async (ctx) => {
    await ctx.parallel(
      ctx.move(scale).to(1, 0.5, BEZIER_SMOOTH),
      ctx.move(opacity).to(1, 0.5, BEZIER_SMOOTH)
    );
    await ctx.wait(2);
    await ctx.move(opacity).to(0, 0.5, BEZIER_SMOOTH);
  });

  return (
    <div
      style={{
        position: 'absolute',
        top: '50%',
        left: '50%',
        transform: `translate(-50%, -50%) scale(${scale.value})`,
        opacity: opacity.value,
        fontSize: '72px',
        fontWeight: 'bold',
        color: 'white',
        textAlign: 'center',
      }}
    >
      My Video Title
    </div>
  );
}

export default function MyProject() {
  return (
    <Project width={1920} height={1080} fps={30} duration={10}>
      <TimeLine>
        {/* 背景動画 */}
        <Clip start={0} duration={10}>
          <Video src="/public/background.mp4" style={{ width: '100%', height: '100%' }} />
        </Clip>

        {/* タイトルカード */}
        <Clip start={1} duration={4}>
          <TitleCard />
        </Clip>

        {/* ロゴ表示 */}
        <Clip start={8} duration={2}>
          <Image
            src="/public/logo.png"
            style={{
              position: 'absolute',
              bottom: '50px',
              right: '50px',
              width: '200px',
            }}
          />
        </Clip>
      </TimeLine>
    </Project>
  );
}
```

## トラブルシューティング

### プレビューが表示されない

```bash
# 依存関係を再インストール
rm -rf node_modules && bun install
```

### レンダリングが失敗する

- Puppeteer/Chromiumの依存関係を確認
- FFmpegがインストールされているか確認
- メモリ不足の場合は解像度を下げる

### 動画/画像が読み込まれない

- ファイルパスが正しいか確認（`/public/` から始まる）
- ファイル形式がサポートされているか確認
