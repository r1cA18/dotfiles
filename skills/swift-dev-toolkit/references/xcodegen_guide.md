# XcodeGen ガイド

CLIから `.xcodeproj` を生成するツール。Xcodeを開かずにプロジェクトを初期化・管理できる。

- **GitHub**: https://github.com/yonaskolb/XcodeGen
- **インストール**: `brew install xcodegen`

---

## 基本ワークフロー

```
project.yml を作成 → xcodegen generate → .xcodeproj が生成
```

### 1. インストール確認

```bash
which xcodegen || brew install xcodegen
```

### 2. project.yml を作成

プロジェクトルートに配置。テンプレート → `templates/project.yml`

### 3. 生成

```bash
xcodegen generate
```

### 4. ビルド

```bash
# CLIでビルド
xcodebuild -project MyApp.xcodeproj -scheme MyApp -configuration Debug build

# Xcodeで開く
open MyApp.xcodeproj
```

---

## project.yml 構造

```yaml
name: アプリ名          # プロジェクト名
options:               # グローバルオプション
  bundleIdPrefix: com.example
  deploymentTarget:
    macOS: "15.0"      # or iOS: "18.0"

settings:              # ビルド設定
  base:
    SWIFT_VERSION: "6.0"

packages:              # SPM依存関係
  SomePackage:
    url: https://github.com/...
    from: "1.0.0"

targets:               # ターゲット定義
  MyApp:
    type: application
    platform: macOS     # or iOS
    sources:
      - path: Sources
    dependencies:
      - package: SomePackage
```

---

## よくあるパターン

### macOS アプリ（サンドボックスなし）

```yaml
targets:
  MyApp:
    type: application
    platform: macOS
    sources:
      - path: MyApp
        excludes:
          - "Resources/Info.plist"
          - "Resources/*.entitlements"
    settings:
      base:
        INFOPLIST_FILE: MyApp/Resources/Info.plist
        CODE_SIGN_ENTITLEMENTS: MyApp/Resources/MyApp.entitlements
        PRODUCT_BUNDLE_IDENTIFIER: com.example.myapp
        CODE_SIGN_IDENTITY: "-"
        ENABLE_HARDENED_RUNTIME: false
```

### iOS アプリ

```yaml
targets:
  MyApp:
    type: application
    platform: iOS
    sources:
      - path: MyApp
        excludes:
          - "Resources/Info.plist"
    settings:
      base:
        INFOPLIST_FILE: MyApp/Resources/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.example.myapp
        CODE_SIGN_STYLE: Automatic
        DEVELOPMENT_TEAM: XXXXXXXXXX
```

### SPM依存の追加

```yaml
packages:
  WhisperKit:
    url: https://github.com/argmaxinc/WhisperKit.git
    from: "0.12.0"
  KeyboardShortcuts:
    url: https://github.com/sindresorhus/KeyboardShortcuts.git
    from: "2.2.0"

targets:
  MyApp:
    dependencies:
      - package: WhisperKit
      - package: KeyboardShortcuts
```

### Widget Extension ターゲット

```yaml
targets:
  MyApp:
    type: application
    platform: iOS
    sources: [MyApp]
    dependencies:
      - target: MyAppWidget

  MyAppWidget:
    type: app-extension
    platform: iOS
    sources: [MyAppWidget]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.example.myapp.widget
        INFOPLIST_FILE: MyAppWidget/Info.plist
```

---

## sources の除外ルール

`Info.plist` と `entitlements` はソースではなく設定ファイルなので除外が必要:

```yaml
sources:
  - path: MyApp
    excludes:
      - "Resources/Info.plist"
      - "Resources/*.entitlements"
```

除外しないとビルドエラーになる（Info.plistの重複など）。

---

## Git管理の推奨

```gitignore
# .gitignore
*.xcodeproj
```

`project.yml` をgit管理し、`.xcodeproj` は生成物として扱う。
チームメンバーは `xcodegen generate` で再生成する。

---

## トラブルシューティング

| 問題 | 対処 |
|------|------|
| `Info.plist is not supported as a top-level resource` | sources の excludes に追加 |
| entitlements が空になる | XcodeGenが上書きする場合あり。生成後に確認 |
| SPMパッケージが見つからない | `xcodebuild -resolvePackageDependencies` を実行 |
| スキームが見つからない | `xcodegen generate` を再実行 |
| `@main` エラー | ターゲットの type が `application` であることを確認 |

---

## SPM (Package.swift) との違い

| | Package.swift (SPM) | project.yml (XcodeGen) |
|---|---|---|
| 生成物 | 実行バイナリ | .app バンドル |
| Info.plist | 使えない | 適用される |
| entitlements | 適用されない | 適用される |
| コード署名 | されない | される |
| 権限ダイアログ | 出ない | 出る |
| 配布 | 不可 | 可能 |
| Xcode不要 | `swift build` | `xcodegen` + `xcodebuild` |

**結論**: ライブラリ → SPM、アプリ → XcodeGen (or Xcode GUI)
