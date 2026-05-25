---
name: docc
description: |
  DocC documentation and tutorials.
  Triggers: "DocC", "tutorial", "チュートリアル", "DocCチュートリアル作成"
---

# DocC チュートリアル

詳細 → `references/docc_tutorial.md`

## コマンド

```bash
# スタンドアロン型: xcrun docc preview
xcrun docc preview Documentation.docc --port 8080
./preview.sh

# Xcode プロジェクト埋め込み型: xcodebuild docbuild
xcodebuild docbuild \
    -project MyApp.xcodeproj \
    -scheme MyApp \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -derivedDataPath ./build-docc
```

## ハマりポイント

| ハマりポイント             | 対処                                     |
| -------------------------- | ---------------------------------------- |
| ulimit エラー              | `ulimit -n 1024`                         |
| `@State` 誤認              | バッククォートで囲む                     |
| Chapter 画像なし           | SVG 追加（ワーニングのみ、ビルドは成功） |
| `@Metadata` ワーニング     | articles では使わない                    |
| `@Step` 複数段落           | 説明文は1段落にまとめる                  |
| Watch App で docbuild 失敗 | `-sdk` ではなく `-destination` を使う    |
