# Tag Taxonomy

タグは複数軸から選択する。最低3つ、最大8つ。

## 必須

`web-design-ref` -- 全デザインリファレンスノートに共通。横断検索用。

## Style (1-2個)

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
| monochrome    | 単色 + 明度のみで構成                    |
| vibrant       | 高彩度の多色使い                         |
| bento-grid    | Bento box 風のグリッドレイアウト         |

## Category (1個、frontmatter の design-category と一致させる)

| Tag           | 判定基準                           |
| ------------- | ---------------------------------- |
| landing-page  | プロダクト/サービス紹介。CTA あり  |
| portfolio     | 作品/実績一覧。About/Contact あり  |
| dashboard     | データ表示、サイドバー、設定画面   |
| e-commerce    | 商品一覧、カート、価格表示         |
| app           | ログイン後の操作画面、ツール系     |
| corporate     | 会社情報、IR、採用                 |
| blog          | 記事一覧、読み物コンテンツ中心     |
| documentation | API/ライブラリのドキュメントサイト |

## Technique (0-3個)

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

## design-category 判定基準

| Category     | 判定基準                                                     |
| ------------ | ------------------------------------------------------------ |
| landing-page | 1つのプロダクト/サービスの紹介。CTA (Sign Up, Download) あり |
| portfolio    | 作品/実績の一覧。About/Contact あり                          |
| dashboard    | データ表示、サイドバー/ナビゲーション、設定画面              |
| e-commerce   | 商品一覧、カート、価格表示                                   |
| app          | ログイン後の操作画面、ツール系                               |
| corporate    | 会社情報、IR、採用ページ                                     |
