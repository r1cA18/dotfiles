# DocC チュートリアル作成ガイド

Apple の DocC でインタラクティブなチュートリアルを作成する手順とハマりポイント。

---

## プロジェクト構造

```
MyTutorial/
├── preview.sh                    ← プレビュー起動スクリプト
├── Package.swift                 ← 空パッケージ（任意）
└── Documentation.docc/
    ├── Documentation.md          ← ランディングページ
    ├── Resources/                ← コードスニペット・画像
    │   ├── 01-01-01-example.swift
    │   ├── chapter-intro.svg
    │   └── ...
    └── Tutorials/
        ├── MyTutorial.tutorial   ← 目次（Chapter 一覧）
        ├── 01-Basics/
        │   ├── 01-Basics-01-Intro.tutorial
        │   └── 01-Basics-02-Next.tutorial
        └── 02-Advanced/
            └── ...
```

---

## ファイル形式

### Documentation.md（ランディングページ）

```markdown
# チュートリアルタイトル

説明文。

## Topics

### はじめに

- <doc:GettingStarted>
- <doc:Tutorials/MyTutorial>
```

**注意**: `@Metadata` ブロックは articles では非対応。使うとワーニング。

### 目次ファイル（MyTutorial.tutorial）

```
@Tutorials(name: "チュートリアル名") {
    @Intro(title: "タイトル") {
        説明文。
    }

    @Chapter(name: "Chapter 名") {
        説明文。

        @Image(source: "chapter-image", alt: "説明")

        @TutorialReference(tutorial: "doc:01-Basics-01-Intro")
    }
}
```

**注意**: 各 `@Chapter` に `@Image` がないとワーニングが出るが、ビルド自体は成功する。画像を用意できない場合はワーニングを無視しても動作に問題はない。

### チュートリアルファイル（.tutorial）

```
@Tutorial(time: 20) {
    @Intro(title: "セクションタイトル") {
        説明文。

        @Image(source: "section-image", alt: "説明")
    }

    @Section(title: "ステップタイトル") {
        @ContentAndMedia {
            説明文（Markdown 対応）。
        }

        @Steps {
            @Step {
                ステップの説明。

                @Code(name: "表示名.swift", file: "01-01-01-example.swift")
            }

            @Step {
                インラインコードブロックも使用可能（@Code 不要）。

                ```swift
                struct Example {
                    let name: String
                }
                ```

                ステップの説明文は1段落のみ。2段落以上あるとワーニング。
                説明が複数ある場合はコードブロックの前に1段落にまとめる。
            }
        }
    }
}
```

---

## コードスニペット命名規則

```
{Chapter}-{Section}-{Step}-{description}.swift
```

例: `03-02-01-state-basic.swift` = Chapter 3, Section 2, Step 1

- ファイルは `Resources/` に配置
- `.swift`, `.sh`, `.txt`, `.xml` 等に対応
- ファイル名がユニークであれば、サブフォルダは不要

---

## Xcode プロジェクト埋め込み型 DocC

Xcode プロジェクト内に `.docc` カタログを配置している場合は、`xcrun docc preview` ではなく `xcodebuild docbuild` を使う。

```bash
# DocC ビルド（Xcode プロジェクト埋め込み型）
xcodebuild docbuild \
    -project MyApp.xcodeproj \
    -scheme MyApp \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -derivedDataPath ./build-docc

# 生成された .doccarchive を開く
open ./build-docc/Build/Products/Debug-iphonesimulator/MyApp.doccarchive
```

**注意: Watch App を含む混合プロジェクト**では `-sdk iphonesimulator` を使うと Watch ターゲットが WatchKit を解決できずビルド失敗する。`-destination` で特定シミュレータを指定すること。

```bash
# ❌ Watch App ターゲットがあるとビルド失敗
xcodebuild docbuild -sdk iphonesimulator ...

# ✅ -destination を使う
xcodebuild docbuild -destination 'platform=iOS Simulator,name=iPhone 17 Pro' ...
```

---

## preview.sh テンプレート（スタンドアロン型 DocC）

```bash
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCC_DIR="$SCRIPT_DIR/Documentation.docc"
PORT="${1:-8080}"

# ファイル数が多い場合に必要
ulimit -n 1024 2>/dev/null || true

# ポート衝突時に自動で別ポートを使う
while lsof -i ":$PORT" >/dev/null 2>&1; do
    echo "ポート $PORT は使用中、$((PORT + 1)) を試行..."
    PORT=$((PORT + 1))
done

xcrun docc preview "$DOCC_DIR" --port "$PORT"
```

```bash
chmod +x preview.sh
./preview.sh
```

---

## ハマりポイントと対処

### 1. ulimit エラー（ファイル数超過）

```
264 files which is more than your shell session limit
```

**原因**: macOS デフォルトの open file limit が少ない
**対処**: `ulimit -n 1024` を preview.sh に追加

### 2. `@State` が DocC ディレクティブとして解釈される

```
warning: Unknown directive '@State'
```

**原因**: DocC が Swift の `@State` を DocC ディレクティブと誤認
**対処**: バッククォートで囲む → `` `@State` ``

他にも `@Binding`, `@Observable`, `@Environment` 等で同様の問題が起きる。

### 3. Chapter に @Image がない

```
warning: Missing 'Image' child directive
```

**対処**: 各 Chapter に SVG 画像を用意して `@Image` を追加。
最小限の SVG テンプレート:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <rect width="200" height="200" rx="40" fill="#007AFF"/>
  <text x="100" y="115" text-anchor="middle"
        font-size="80" fill="white" font-family="system-ui">
    🔧
  </text>
</svg>
```

### 4. `@Metadata` ワーニング

```
warning: '@Metadata' is not supported in articles
```

**対処**: `Documentation.md` から `@Metadata` ブロックを削除。
`@Metadata` は `.tutorial` ファイルでのみ使用可能。

### 5. Symbol が見つからない

```
warning: No symbol matched 'MyTutorial'
```

**対処**: `Documentation.md` のトップレベル見出しを `` # ``MyTutorial`` `` ではなく、
プレーンな `# タイトル` にする（DocC がシンボルリンクとして解釈しようとする）。

### 6. ポート衝突

**対処**: preview.sh に自動ポート検出を入れる（テンプレート参照）。

### 7. `@Step` に複数段落

```
warning: Extraneous element: 'Step' directive should only have a single paragraph
```

**原因**: `@Step` 内の説明文が2段落以上ある
**対処**: 説明文は1段落にまとめる。コードブロック（`@Code` またはインライン ` ``` `）の前に1段落だけ置く。
複数の概念を説明したい場合は `**太字:**` でポイントを1段落内に列挙するか、コードブロックの後に追加のポイント説明を置く。

### 8. Watch App 混合プロジェクトの docbuild 失敗

```
Unable to find module dependency: 'WatchKit'
```

**原因**: `-sdk iphonesimulator` では WatchKit SDK が利用不可
**対処**: `-destination 'platform=iOS Simulator,name=iPhone 17 Pro'` を使う（Section「Xcode プロジェクト埋め込み型 DocC」参照）。

---

## Chapter 構成のコツ

- SwiftUI を学んだ直後に iOS アプリで実践すると流れがスムーズ
- macOS 固有の機能（MenuBarExtra 等）は「拡張」として後半に配置
- 1 Chapter = 2〜3 Section が目安
- 各 Section = 3〜8 Step
- コードスニペットは段階的に積み上げる（前のステップに追加していく形）

---

## ファイル数の目安

| 規模 | Chapter 数 | スニペット数 | 合計ファイル数 |
|------|-----------|-------------|--------------|
| 小 | 3-5 | 50-80 | ~100 |
| 中 | 6-8 | 100-150 | ~170 |
| 大 | 8-10 | 150-250 | ~270 |

200ファイル超えたら `ulimit` 対策必須。
