---
name: fastlane
description: |
  Fastlane setup, TestFlight upload, App Store deployment.
  Triggers: "fastlane setup", "fastlane init", "TestFlight", "App Store", "deploy", "upload", "archive"
  日本語: 「TestFlightアップロード」「デプロイ」「Fastlaneセットアップ」
---

# Fastlane & Deployment

**核心思想**: Fastlane + App Store Connect API Key で完全自動化

## 1. 事前チェック

```bash
ls fastlane/Fastfile 2>/dev/null && echo "OK: configured" || echo "NG: not configured"
```

**設定済み** → TestFlight Upload へスキップ
**未設定** → 以下を実行

## 2. プロジェクト情報を検出

```bash
# スキーム
xcodebuild -list -project *.xcodeproj 2>/dev/null | grep -A 20 "Schemes:" | tail -n +2 | head -5

# Bundle ID
grep "PRODUCT_BUNDLE_IDENTIFIER" *.xcodeproj/project.pbxproj | head -1 | sed 's/.*= //' | tr -d '";'

# Team ID
grep "DEVELOPMENT_TEAM" *.xcodeproj/project.pbxproj | head -1 | sed 's/.*= //' | tr -d '";'
```

## 3. セットアップ実行

```bash
mkdir -p fastlane
cp ~/.claude/skills/swift-dev-toolkit/templates/Fastfile fastlane/Fastfile
cp ~/.claude/skills/swift-dev-toolkit/templates/Appfile fastlane/Appfile

# 値を置換（検出した値を使う）
sed -i '' 's/com\.example\.yourapp/<BUNDLE_ID>/g' fastlane/Appfile
sed -i '' 's/XXXXXXXXXX/<TEAM_ID>/g' fastlane/Appfile
sed -i '' 's/YourScheme/<SCHEME>/g' fastlane/Fastfile
```

## 4. 動作確認

```bash
fastlane ios builds
```

**API Key 未設定の場合** → `references/api_key_setup.md`

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

## 6. Chrome 自動化（フォールバック）

API で不可能な操作に限定:

- 内部テストグループ作成（初回のみ）
- App Store メタデータ UI 操作
- スクリーンショットアップロード
