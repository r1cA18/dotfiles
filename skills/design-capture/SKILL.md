---
name: design-capture
description: >-
  Webデザインのスクショ撮影+デザイントークン抽出+構造化分析をvaultのKnowledge noteに保存する。
  AIがコーディング時に読んで即座にデザインを再現できる形式で記録する。
  このスキルは以下の場合に必ず使う:
  ユーザーがURLを共有して「かっこいい」「デザインいい」「参考にしたい」「保存して」「UIいい」「レイアウト好き」等と言った場合、
  「デザインキャプチャ」「デザイン参考」「このサイト保存」「このページ保存」「デザインメモ」「UI参考」
  「save this design」「capture this site」「design reference」「design inspiration」「bookmark this design」と言った場合、
  ユーザーがWebサイトの見た目について感想を述べてそれを記録したい場合。
  /design-capture コマンドで直接呼び出すこともできる。
  このスキルを使わない場合: バグ報告、エラー調査、コンテンツ閲覧のみが目的の場合。
user-invocable: true
---

# Design Capture

Webサイトのデザインをキャプチャし、AIコーディング時に即座に参照できる構造化ナレッジノートとして保存する。
保存されたノートの Color Palette, Typography, Layout, Animation は AI が Tailwind config, CSS custom properties, Framer Motion 等に直接変換できる形式になっている。

## Bundled Resources

| Path                               | 用途                                 | 読むタイミング       |
| ---------------------------------- | ------------------------------------ | -------------------- |
| `scripts/extract-design-tokens.js` | ブラウザ注入用トークン抽出スクリプト | Step 2b              |
| `references/tag-taxonomy.md`       | タグ分類と判定基準                   | Step 4               |
| `references/example-output.md`     | 完成形の参考例                       | 初回実行時・迷った時 |

同梱スクリプトは `agent-skill-path design-capture ...` で解決する。

## Usage

```
/design-capture <url> <感想>
```

第1トークン (https:// or http:// で始まる文字列) が URL。残り全てがユーザーの感想。
感想は音声入力想定なので崩れていてもそのまま記録する。感想が空なら My Take に「(感想なし)」。

例:

- `/design-capture https://linear.app/ UIめっちゃシュッとしてる、ダークテーマの使い方がうまい`
- `/design-capture https://stripe.com/jp グラデーションの使い方が天才`
- `/design-capture https://vercel.com/`

## Process

### Step 1: 引数パース + slug 生成

URL と感想を分離し、URL からファイル名用の slug を生成する。

slug ルール:

- ドメイン名のみ使用 (パスは無視)
- `.` を `-` に変換、小文字統一、`www.` 除去
- 既に `~/vault/20_Knowledge/web-design-ref-{slug}.md` が存在する場合は `-2`, `-3` を付与

```
https://official-site-4ez.pages.dev/ -> official-site-4ez-pages-dev
https://stripe.com/jp               -> stripe-com
```

### Step 2: ブラウザでサイト訪問 + スクショ + デザイントークン抽出

全処理を `/agent-browser` のみで完結させる。JS 実行も `agent-browser eval` で可能。

#### Step 2a: ナビゲーション + スクロールスルー + スクショ

多くのサイトはスクロールアニメーション (AOS, GSAP, Intersection Observer 等) を使っており、
スクロールしないと要素が不可視のまま。スクショ前に必ず全ページをスクロールしてアニメーションを発火させる。

Playwright の `screenshot --full` は内部スクロールで Intersection Observer を発火しない。
JS の `window.scrollTo()` で手動スクロールが必須。

agent-browser で以下を順に実行する:

```bash
agent-browser open <URL>
agent-browser wait --load networkidle

# Cookie バナーがあれば閉じる
agent-browser snapshot -i
# "Accept", "Close", "OK" 等のボタンがあれば click

# 段階的スクロール (Intersection Observer / lazy loading 発火用)
# ビューポート高さの 80% ずつスクロールして全セクションを通過させる
agent-browser eval "
(async () => {
  const vh = window.innerHeight;
  const totalHeight = document.body.scrollHeight;
  for (let y = 0; y <= totalHeight; y += vh * 0.8) {
    window.scrollTo(0, y);
    await new Promise(r => setTimeout(r, 400));
  }
  window.scrollTo(0, totalHeight);
  await new Promise(r => setTimeout(r, 1000));
  window.scrollTo(0, 0);
  await new Promise(r => setTimeout(r, 500));
  return 'done';
})()
"

# タイトル取得 + フルページスクショ
agent-browser get title
agent-browser screenshot --full ~/vault/91_attachments/web-design-ref-<slug>.png
```

ポイント:

- `window.scrollTo(0, bottom)` の一発ジャンプでは途中のセクションがビューポートを通過しない
- Intersection Observer は要素がビューポートと交差した瞬間に発火するため、段階的スクロールが必須
- ビューポート 80% ずつ + 400ms 待機で確実に全要素を通過させる
- 最後に先頭に戻してからスクショ

#### Step 2b: デザイントークン抽出

`scripts/extract-design-tokens.js` を `agent-browser eval --stdin` で実行する:

```bash
cat "$(agent-skill-path design-capture scripts/extract-design-tokens.js)" | agent-browser eval --stdin
```

結果は JSON 文字列で返ってくる（colors, fonts, spacing, animations, animationLibraries, keyframes, title）。

JS 実行が失敗した場合は Step 3 の視覚分析のみで進める。

### Step 3: スクリーンショットの視覚分析

保存したスクショを Read tool で読み込む（マルチモーダル分析）。

スクショから以下を分析する:

- 全体のビジュアルトーン（ダーク/ライト、ミニマル/装飾的）
- レイアウト構造（セクションの並び、グリッドパターン）
- タイポグラフィの印象（大胆/繊細、セリフ/サンセリフ）
- アニメーションの痕跡（フェード途中の要素等）
- グラデーション、ホバーエフェクト等 JS が取得できない視覚的要素
- design-category の判定材料

データ統合ルール:

- 具体的な値 (hex, px, font-family) は JS 抽出を優先
- レイアウト構造、アニメーション意図、全体印象は視覚分析を優先
- gradient, hover effect 等 JS で取得できない情報は視覚分析のみ

### Step 4: Knowledge Note 生成

`references/tag-taxonomy.md` を Read して、タグ判定基準を確認する。

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
  - { style-tag }
  - { category-tag }
  - { technique-tags... }
aliases:
  - { サイト名 }
  - { サイト名の英語 or 日本語バリエーション }
  - "web design {slug}"
  - "デザイン参考 {サイト名}"
source: "{URL}"
design-category: { category }
---
```

#### Sections (全7セクション、省略不可、この順序で)

**## Screenshot**

`![[web-design-ref-{slug}.png]]`

**## Color Palette**

hex 値で記載。最低4色、最大8色。Role 名はセマンティック。

| Role                                     | Value    | Note         |
| ---------------------------------------- | -------- | ------------ |
| {Background/Surface/Accent/Text/Muted等} | `{#hex}` | {用途・印象} |

**## Typography**

| Element                   | Family        | Weight    | Size | Line Height |
| ------------------------- | ------------- | --------- | ---- | ----------- |
| {H1/H2/Body/Accent/Nav等} | {font-family} | {100-900} | {px} | {倍率}      |

フォント特定不可時は視覚的特徴で記述（例: "sans-serif (Geometric, wide)"）。

**## Layout**

箇条書き: Max Width, Grid system, Section spacing, Component spacing, Responsive兆候, セクション構造。

**## Animation & Interaction**

テーブル。アニメーション無しなら「Static なデザイン。目立ったアニメーションなし。」。

| Element | Type   | Duration | Easing   | Trigger |
| ------- | ------ | -------- | -------- | ------- |
| {要素}  | {種別} | {ms}     | {easing} | {条件}  |

**## My Take**

ユーザーの感想を blockquote でそのまま記載。整形・要約しない。
感想が空の場合は「(感想なし)」。

**## Use As**

AI がこのリファレンスをどんな場面で参考にすべきかの提案。2-4 bullet points。

### Step 5: 完了報告

以下をユーザーに報告:

- Knowledge note パス
- Screenshot パス
- 主要3色のサマリー
- 付与したタグ

## Error Handling

| 状況                                      | 対応                                                    |
| ----------------------------------------- | ------------------------------------------------------- |
| agent-browser が使えない                  | エラー報告して中断。手動スクショのパスを聞く            |
| JS トークン抽出失敗                       | スクショの視覚分析のみで全セクション埋める              |
| 403 / ログイン必須 / Cloudflare challenge | エラー報告して中断。手動スクショのパスを聞く            |
| スクショ保存失敗                          | Note は生成するが Screenshot セクションに「(取得失敗)」 |
| ページ読み込みが遅い (SPA等)              | 10秒待ってからスクショ。それでもダメなら報告            |
