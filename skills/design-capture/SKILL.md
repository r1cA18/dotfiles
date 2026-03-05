---
name: design-capture
description: >-
  Webデザインのスクショ撮影+デザイントークン抽出+構造化分析をvaultのKnowledge noteに保存する。
  AIがコーディング時に読んで即座にデザインを再現できる形式で記録する。
  このスキルは以下の場合に必ず使う:
  ユーザーがURLを共有して「かっこいい」「デザインいい」「参考にしたい」「保存して」等と言った場合、
  「デザインキャプチャ」「デザイン参考」「このサイト保存」「save this design」「capture this site」
  「design reference」「design inspiration」「bookmark this design」と言った場合、
  ユーザーがWebサイトの見た目について感想を述べてそれを記録したい場合。
  /design-capture コマンドで直接呼び出すこともできる。
user-invocable: true
---

# Design Capture

Webサイトのデザインをキャプチャし、AIコーディング時に即座に参照できる構造化ナレッジノートとして保存する。

保存されたノートには Color Palette, Typography, Layout, Animation が構造化されており、
AI が Tailwind config, CSS custom properties, Framer Motion 等に直接変換できる。

## Usage

```
/design-capture <url> <感想>
```

第1トークン (https:// or http:// で始まる文字列) が URL。残り全てがユーザーの感想。
感想は音声入力を想定しているので、文法が崩れていてもそのまま記録する。
感想が空の場合は My Take セクションを「(感想なし)」とする。

例:

- `/design-capture https://linear.app/ UIめっちゃシュッとしてる、ダークテーマの使い方がうまい`
- `/design-capture https://stripe.com/jp グラデーションの使い方が天才`
- `/design-capture https://vercel.com/`

## Process

### Step 1: 引数パース + slug 生成

URL と感想を分離し、URL からファイル名用の slug を生成する。

```
URL:  https://official-site-4ez.pages.dev/
感想: ダーク系の配色がめちゃ好き...
slug: official-site-4ez-pages-dev
```

slug ルール:

- ドメイン名のみ使用 (パスは無視)
- `.` を `-` に変換、小文字統一、`www.` 除去
- 既に `~/vault/20_Knowledge/web-design-ref-{slug}.md` が存在する場合は `-2`, `-3` を付与

### Step 2: ブラウザでサイト訪問 + スクショ撮影

Skill tool で `/agent-browser` を呼び出す。以下の内容を args に含める:

```
1. <URL> を新しいタブで開く
2. ページの読み込みを待つ
3. Cookie consent バナーやポップアップがあれば閉じる (best effort)
4. ページタイトルを取得して報告する
5. フルページスクリーンショットを撮影して ~/vault/91_attachments/web-design-ref-<slug>.png に保存する
6. 以下の JavaScript を実行してデザイントークンを抽出する:

(function() {
  const selectors = 'body,header,main,footer,nav,section,button,a,h1,h2,h3,[class*="hero"],[class*="card"],[class*="btn"]';
  const els = document.querySelectorAll(selectors);
  const colors = new Map();
  const fonts = new Map();
  els.forEach(el => {
    const s = getComputedStyle(el);
    const bg = s.backgroundColor; const fg = s.color;
    if (bg !== 'rgba(0, 0, 0, 0)') colors.set(bg, (colors.get(bg)||0)+1);
    colors.set(fg, (colors.get(fg)||0)+1);
    const fontKey = s.fontFamily+'|'+s.fontWeight+'|'+s.fontSize+'|'+s.lineHeight;
    fonts.set(fontKey, (fonts.get(fontKey)||0)+1);
  });
  const maxW = getComputedStyle(document.querySelector('main,article,.container,[class*="container"],[class*="wrapper"]') || document.body).maxWidth;
  return JSON.stringify({
    colors: [...colors.entries()].sort((a,b)=>b[1]-a[1]).slice(0,12),
    fonts: [...fonts.entries()].sort((a,b)=>b[1]-a[1]).slice(0,6),
    maxWidth: maxW,
    title: document.title
  });
})()

7. 結果を報告する
```

`/agent-browser` が使えない場合のフォールバック:
ToolSearch で `claude-in-chrome` の MCP tools を検索して直接使う
(navigate, javascript_tool, read_page 等)。

### Step 3: スクリーンショットの視覚分析

保存したスクショを Read tool で読み込む（Claude はマルチモーダルなので画像を直接分析できる）。

```
Read(file_path: "~/vault/91_attachments/web-design-ref-<slug>.png")
```

スクショから以下を視覚的に分析する:

- 全体のビジュアルトーン（ダーク/ライト、ミニマル/装飾的）
- レイアウト構造（セクションの並び、グリッドパターン）
- タイポグラフィの印象（大胆/繊細、セリフ/サンセリフ）
- 目立つアニメーションの痕跡（スクロール位置で要素がフェード途中等）
- design-category の判定材料

この視覚分析と Step 2 の JS 抽出データを組み合わせて、最終的な分析を行う。
JS 抽出が失敗した場合はこの視覚分析のみで全セクションを埋める。

### Step 4: Knowledge Note 生成

`~/vault/20_Knowledge/web-design-ref-{slug}.md` に以下のフォーマットで Write する。

#### Frontmatter

```yaml
---
title: "{サイト名} - {一行説明}"
type: knowledge
notetype: literature
created: { YYYY-MM-DD }
tags:
  - web-design-ref
  - { style-tag-1 }
  - { category-tag }
  - { technique-tag-1 }
  - { technique-tag-2 }
aliases:
  - { サイト名 }
  - { サイト名の英語 or 日本語バリエーション }
  - "web design {slug}"
  - "デザイン参考 {サイト名}"
source: "{URL}"
design-category: { category }
---
```

#### Sections

全7セクションを以下の順序で記載する。セクションの省略は不可。

**## Screenshot**

```
![[web-design-ref-{slug}.png]]
```

**## Color Palette**

hex 値で記載。RGB/HSL は使わない。最低4色、最大8色。
Role 名はセマンティック（Background, Surface, Accent, Text, Muted, Border, Success, Error 等）。

| Role     | Value    | Note                                 |
| -------- | -------- | ------------------------------------ |
| {Role名} | `{#hex}` | {どこで使われているか、どんな印象か} |

**## Typography**

| Element                   | Family          | Weight    | Size   | Line Height |
| ------------------------- | --------------- | --------- | ------ | ----------- |
| {H1/H2/Body/Accent/Nav等} | {font-family名} | {100-900} | {px値} | {倍率}      |

フォントが特定できない場合は視覚的特徴で記述する（例: "sans-serif (Geometric, wide)"）。

**## Layout**

箇条書きで以下を記載:

- Max Width, Grid system, Section spacing, Component spacing
- Responsive の兆候
- セクション構造を上から順に列挙（例: Hero -> Features -> Testimonials -> CTA -> Footer）

**## Animation & Interaction**

テーブルで記載。アニメーションが無い場合は「Static なデザイン。目立ったアニメーションなし。」と記載。

| Element | Type                 | Duration | Easing   | Trigger        |
| ------- | -------------------- | -------- | -------- | -------------- |
| {要素}  | {アニメーション種別} | {ms}     | {easing} | {トリガー条件} |

**## My Take**

ユーザーの感想をblockquoteでそのまま記載。整形・要約しない。

```
> {ユーザーの感想テキスト}
```

**## Use As**

AI がこのデザインリファレンスをどんな場面で参考にすべきかの提案。2-4 bullet points。
ユーザーの感想 + デザイン分析から導く。

### Step 5: 完了報告

以下をユーザーに報告:

- Knowledge note のパス
- Screenshot のパス
- 主要3色のサマリー
- 付与したタグ

## Tag Taxonomy

### 必須

`web-design-ref` -- 全デザインリファレンスノートに共通。横断検索用。

### Style (1-2個)

| Tag           | 判定基準                                 |
| ------------- | ---------------------------------------- |
| dark-theme    | 背景 #000-#333 系                        |
| light-theme   | 背景 #f0f0f0-#fff 系                     |
| glassmorphism | 半透明 backdrop-filter blur              |
| brutalist     | 太ボーダー、生タイポグラフィ             |
| minimal       | 余白主体、装飾排除                       |
| retro         | ヴィンテージ風                           |
| gradient      | グラデーションが主要表現                 |
| neo-brutalist | カラフル + 太ボーダー + ドロップシャドウ |
| neumorphism   | ソフトシャドウの凹凸表現                 |

### Category (1個、frontmatter の design-category と一致させる)

| Tag          | 判定基準                          |
| ------------ | --------------------------------- |
| landing-page | プロダクト/サービス紹介。CTA あり |
| portfolio    | 作品/実績一覧。About/Contact あり |
| dashboard    | データ表示、サイドバー、設定画面  |
| e-commerce   | 商品一覧、カート、価格表示        |
| app          | ログイン後の操作画面、ツール系    |
| corporate    | 会社情報、IR、採用                |

### Technique (0-3個)

| Tag                | 判定基準                                |
| ------------------ | --------------------------------------- |
| scroll-animation   | スクロール連動アニメーション            |
| parallax           | パララックス効果                        |
| micro-interaction  | ホバー/クリック時の細かいフィードバック |
| 3d                 | WebGL, CSS 3D transform                 |
| typography-focused | タイポグラフィが主要デザイン要素        |
| illustration       | イラストが主要ビジュアル                |
| motion-heavy       | 全体的にアニメーション多め              |
| grid-layout        | 明確なグリッドレイアウト                |

## Error Handling

| 状況                                  | 対応                                                    |
| ------------------------------------- | ------------------------------------------------------- |
| agent-browser / claude-in-chrome 不可 | エラー報告して中断。手動スクショのパスを聞く            |
| JS トークン抽出失敗                   | スクショの視覚分析のみで全セクション埋める              |
| 403 / ログイン必須                    | エラー報告して中断                                      |
| スクショ保存失敗                      | Note は生成するが Screenshot セクションに「(取得失敗)」 |
