---
name: swift-dev-toolkit
description: |
  Swift/iOS/macOS development automation toolkit. Build loop, project setup, localization, UI debug, Widget, App Store Connect upload.
  Triggers: "build", "fix errors", "Bundle ID", "App Groups", "localization", "翻訳", "screenshot", "UIスクショ", "Widget", "TestFlight", "App Store", "deploy", "upload", "archive", "fastlane setup", "fastlane init"
  日本語: 「ビルドして」「エラー直して」「Bundle ID変更」「App Groups設定」「翻訳チェック」「UIスクショ」「Widget追加」「macOSカテゴリ設定」「TestFlightアップロード」「デプロイ」「Fastlaneセットアップ」
---

# Swift Dev Toolkit

**核心思想**: Fastlane + App Store Connect API Key で完全自動化

---

## エージェントの行動原則

1. **手順を説明するのではなく、実行する**
2. **Fastlane 未設定なら自動セットアップしてから進める**
3. **エラーは修正してリトライ**（Build Loop）
4. **API で不可能な操作のみ Chrome 自動化を使用**

---

## 1. Fastlane セットアップ

### 1.1 事前チェック

```bash
ls fastlane/Fastfile 2>/dev/null && echo "✅ 設定済み" || echo "❌ 未設定"
```

**設定済み** → Section 5 へスキップ
**未設定** → 以下を実行

### 1.2 プロジェクト情報を検出

```bash
# スキーム
xcodebuild -list -project *.xcodeproj 2>/dev/null | grep -A 20 "Schemes:" | tail -n +2 | head -5

# Bundle ID
grep "PRODUCT_BUNDLE_IDENTIFIER" *.xcodeproj/project.pbxproj | head -1 | sed 's/.*= //' | tr -d '";'

# Team ID
grep "DEVELOPMENT_TEAM" *.xcodeproj/project.pbxproj | head -1 | sed 's/.*= //' | tr -d '";'
```

### 1.3 セットアップ実行

```bash
mkdir -p fastlane
cp ~/.claude/skills/swift-dev-toolkit/templates/Fastfile fastlane/Fastfile
cp ~/.claude/skills/swift-dev-toolkit/templates/Appfile fastlane/Appfile

# 値を置換（検出した値を使う）
sed -i '' 's/com\.example\.yourapp/<BUNDLE_ID>/g' fastlane/Appfile
sed -i '' 's/XXXXXXXXXX/<TEAM_ID>/g' fastlane/Appfile
sed -i '' 's/YourScheme/<SCHEME>/g' fastlane/Fastfile
```

### 1.4 動作確認

```bash
fastlane ios builds
```

**API Key 未設定の場合** → `references/api_key_setup.md`

---

## 2. Build Loop

エラーがなくなるまでビルド→修正を繰り返す。

```bash
xcodebuild -scheme <SCHEME> -destination 'generic/platform=iOS Simulator' build 2>&1 | tee /tmp/build.log
grep -E "error:|fatal error:" /tmp/build.log
```

| エラーパターン | 対処 |
|---------------|------|
| `Cannot find 'X' in scope` | import 追加 or 型定義確認 |
| `Cannot convert value` | 型変換を追加 |
| `Missing argument` | 必須引数を追加 |

---

## 3. Project Setup

### Bundle ID / App Groups

```bash
# 確認
grep "PRODUCT_BUNDLE_IDENTIFIER" *.xcodeproj/project.pbxproj | head -4
grep -r "group\." *.entitlements 2>/dev/null

# 変更
sed -i '' 's/old\.bundle\.id/new.bundle.id/g' *.xcodeproj/project.pbxproj
```

### App Category (macOS)

```
INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
```

---

## 4. Widget / Live Activity

1. **Xcode**: File → New → Target → Widget Extension
2. **App Groups**: 両ターゲットに同じ Group ID を設定
3. **コード**: `templates/SharedDataManager.swift` を参照

---

## 5. TestFlight Upload

### iOS

```bash
fastlane ios beta          # ビルド番号自動増分 + アップロード
```

### macOS

```bash
fastlane mac beta
```

### テスター管理

```bash
fastlane pilot list                                    # 一覧
fastlane pilot add email@example.com -g "Internal Testers"  # 追加
```

### 手動アップロード（Fastlane なし）

```bash
xcodebuild archive -scheme <SCHEME> -archivePath ./build/App.xcarchive -destination 'generic/platform=iOS' && \
xcodebuild -exportArchive -archivePath ./build/App.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath ./build/export
```

---

## 6. Localization

```bash
cat Localizable.xcstrings | jq '.strings | to_entries[] | select(.value.localizations.ja == null) | .key'
```

---

## 7. UI Screenshot

```bash
xcrun simctl boot "iPhone 16"
xcrun simctl io booted screenshot /tmp/screenshot.png
```

---

## 8. Chrome 自動化（フォールバック）

API で不可能な操作に限定:
- 内部テストグループ作成（初回のみ）
- App Store メタデータ UI 操作
- スクリーンショットアップロード

---

## ファイル構成

```
swift-dev-toolkit/
├── SKILL.md
├── scripts/build_loop.sh
├── templates/
│   ├── Fastfile
│   ├── Appfile
│   ├── SharedDataManager.swift
│   └── ExportOptions.plist
└── references/
    ├── api_key_setup.md
    ├── fastlane_actions.md
    └── troubleshooting.md
```
