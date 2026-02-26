---
name: xcodegen
description: |
  XcodeGen project initialization. Generate .xcodeproj from CLI.
  Triggers: "xcodegen", "xcodeproj", "プロジェクト作成", "新規プロジェクト"
  日本語: 「プロジェクト作成」「xcodeproj生成」
---

# XcodeGen プロジェクト初期化

Xcode GUI を使わずに CLI で `.xcodeproj` を生成する。

詳細 → `references/xcodegen_guide.md`

## セットアップ

```bash
which xcodegen || brew install xcodegen
```

## project.yml を作成

```bash
cp ~/.claude/skills/swift-dev-toolkit/templates/project.yml ./project.yml

# プレースホルダーを置換
sed -i '' 's/__APP_NAME__/MyApp/g' project.yml
sed -i '' 's/__BUNDLE_ID__/com.example.myapp/g' project.yml
sed -i '' 's/__PLATFORM__/macOS/g' project.yml
sed -i '' 's/__DEPLOY_TARGET__/15.0/g' project.yml
```

## 生成 & ビルド

```bash
xcodegen generate
xcodebuild -project MyApp.xcodeproj -scheme MyApp build
```

## 注意点

- `Info.plist` と `entitlements` は sources から除外する（excludes に追加）
- XcodeGen が entitlements を空にすることがある → 生成後に確認
- ファイル追加/削除後は `xcodegen generate` を再実行
- `.xcodeproj` は `.gitignore` に入れ、`project.yml` を管理する

| SPM (`swift build`)  | XcodeGen (`xcodegen`) |
| -------------------- | --------------------- |
| 実行バイナリのみ     | .app バンドル生成     |
| 権限ダイアログ出ない | 出る                  |
| ライブラリ向き       | アプリ向き            |
