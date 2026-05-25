---
name: build
description: |
  Build loop: fix Xcode build errors iteratively until clean.
  Triggers: "build", "fix errors", "ビルドして", "エラー直して"
---

# Build Loop

エラーがなくなるまでビルド→修正を繰り返す。

## 実行

```bash
xcodebuild -scheme <SCHEME> -destination 'generic/platform=iOS Simulator' build 2>&1 | tee /tmp/build.log
grep -E "error:|fatal error:" /tmp/build.log
```

## エラーパターン

| エラーパターン             | 対処                      |
| -------------------------- | ------------------------- |
| `Cannot find 'X' in scope` | import 追加 or 型定義確認 |
| `Cannot convert value`     | 型変換を追加              |
| `Missing argument`         | 必須引数を追加            |

## ループ手順

1. ビルド実行
2. エラーログから原因特定
3. コード修正
4. 再ビルド
5. エラーゼロになるまで繰り返す

詳細なトラブルシューティング → `references/troubleshooting.md`
