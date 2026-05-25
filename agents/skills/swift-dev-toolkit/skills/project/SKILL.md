---
name: project
description: |
  Project setup: Bundle ID, App Groups, Widget, localization, screenshots.
  Triggers: "Bundle ID", "App Groups", "Widget", "localization", "翻訳", "screenshot", "UIスクショ"
  日本語: 「Bundle ID変更」「App Groups設定」「翻訳チェック」「UIスクショ」「Widget追加」「macOSカテゴリ設定」
---

# Project Setup

## Bundle ID / App Groups

```bash
# 確認
grep "PRODUCT_BUNDLE_IDENTIFIER" *.xcodeproj/project.pbxproj | head -4
grep -r "group\." *.entitlements 2>/dev/null

# 変更
sed -i '' 's/old\.bundle\.id/new.bundle.id/g' *.xcodeproj/project.pbxproj
```

## App Category (macOS)

```
INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
```

## Widget / Live Activity

1. **Xcode**: File -> New -> Target -> Widget Extension
2. **App Groups**: 両ターゲットに同じ Group ID を設定
3. **コード**: `templates/SharedDataManager.swift` を参照

## Localization

```bash
cat Localizable.xcstrings | jq '.strings | to_entries[] | select(.value.localizations.ja == null) | .key'
```

## UI Screenshot

```bash
xcrun simctl boot "iPhone 16"
xcrun simctl io booted screenshot /tmp/screenshot.png
```
