# Example Output

`/design-capture https://linear.app/ UIめっちゃシュッとしてる、ダークテーマの使い方がうまい` の場合の完成形:

```markdown
---
title: "Linear - プロジェクト管理ツールのダークUI"
type: knowledge
notetype: literature
created: 2026-03-05
tags:
  - web-design-ref
  - dark-theme
  - minimal
  - app
  - micro-interaction
aliases:
  - Linear
  - リニア
  - "web design linear-app"
  - "デザイン参考 Linear"
source: "https://linear.app/"
design-category: app
---

## Screenshot

![[web-design-ref-linear-app.png]]

## Color Palette

| Role       | Value     | Note                             |
| ---------- | --------- | -------------------------------- |
| Background | `#1a1a2e` | メイン背景、深いネイビーブラック |
| Surface    | `#232340` | カード、サイドバー背景           |
| Accent     | `#5e6ad2` | アクティブ状態、プライマリボタン |
| Text       | `#eeeef0` | メインテキスト、高コントラスト   |
| Muted      | `#8b8b9a` | 補助テキスト、プレースホルダー   |
| Border     | `#2e2e4a` | セパレーター、カードボーダー     |
| Success    | `#4ade80` | 完了ステータス                   |
| Danger     | `#ef4444` | エラー、削除                     |

## Typography

| Element | Family                    | Weight | Size | Line Height |
| ------- | ------------------------- | ------ | ---- | ----------- |
| H1      | Inter, sans-serif         | 600    | 24px | 1.3         |
| H2      | Inter, sans-serif         | 500    | 18px | 1.4         |
| Body    | Inter, sans-serif         | 400    | 14px | 1.5         |
| Nav     | Inter, sans-serif         | 500    | 13px | 1.4         |
| Code    | JetBrains Mono, monospace | 400    | 13px | 1.5         |

## Layout

- **Max Width**: フルスクリーン（サイドバー + メインコンテンツ）
- **Grid**: サイドバー (240px fixed) + メインエリア (fluid)
- **Section Spacing**: 16px / 24px
- **Component Spacing**: 8px / 12px（タイトなスペーシング）
- **Responsive**: デスクトップファースト
- **構造**: Sidebar (Navigation + Projects) -> Main (Header + Issue List/Board)

## Animation & Interaction

| Element            | Type              | Duration | Easing      | Trigger       |
| ------------------ | ----------------- | -------- | ----------- | ------------- |
| サイドバーメニュー | Collapse/Expand   | 200ms    | ease-in-out | Click         |
| Issue行            | Highlight + scale | 100ms    | ease        | Hover         |
| ステータスバッジ   | Color transition  | 150ms    | ease        | Status change |
| モーダル           | Fade + scale up   | 200ms    | ease-out    | Open          |
| ドロップダウン     | Slide down + fade | 150ms    | ease-out    | Click         |

## My Take

> UIめっちゃシュッとしてる、ダークテーマの使い方がうまい

## Use As

- ダークテーマの SaaS アプリを作る時の配色参考（特にネイビーブラック系）
- サイドバー + メインコンテンツ のレイアウトパターン
- タイトなスペーシング (8px/12px ベース) のアプリ UI 参考
- micro-interaction のタイミングと easing の実装参考
```
