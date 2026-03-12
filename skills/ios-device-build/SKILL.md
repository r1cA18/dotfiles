---
name: ios-device-build
description: "Swift/iOSアプリを実機にビルド・インストール・起動する。使用タイミング: 「実機にビルドして」「iPhoneで動かして」「デバイスにインストールして」など。xcodebuild → devicectl install → devicectl launchの一連のフローを自動化。"
---

# iOS Device Build

iOS実機へのビルド・インストール・起動を自動化するスキル。

## 実行フロー

### Step 1: 設定確認

まず設定ファイルの存在を確認:

```bash
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agent-skills/ios-device-build"
cat "$CONFIG_DIR/settings.conf" 2>/dev/null || echo "NOT_FOUND"
```

### Step 2: 設定がない場合 → ユーザーに質問

設定ファイルが存在しない、または `NOT_FOUND` の場合:

1. **接続中のデバイス一覧を取得**:
```bash
xcrun devicectl list devices 2>/dev/null
```

2. ユーザーに質問:
   - 「どのデバイスをデフォルトとして使用しますか？」
   - 取得したデバイス一覧から選択肢を提示
   - 選択肢に「自動検出（毎回最初のデバイスを使用）」も含める

3. **設定ファイルを作成**:
```bash
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agent-skills/ios-device-build"
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_DIR/settings.conf" << 'EOF'
# iOS Device Build - 設定ファイル
DEFAULT_DEVICE_NAME="<ユーザーが選んだデバイス名>"
DEFAULT_SCHEME=""
NOTIFY_LANGUAGE="ja"
BUILD_LOG_LINES=30
EOF
```

### Step 3: ビルド実行

設定が確認できたら、ビルドスクリプトを実行:

```bash
bash "$(agent-skill-path ios-device-build scripts/device_build.sh)" <project_path> [scheme] [device_name] [bundle_id]
```

## パラメータ

| パラメータ | 説明 | デフォルト |
|-----------|------|----------|
| `project_path` | プロジェクトのパス | `.`（カレントディレクトリ） |
| `scheme` | ビルドスキーム | 設定ファイル → xcodeproj名から自動検出 |
| `device_name` | デバイス名 | 設定ファイル → 接続中の最初のデバイス |
| `bundle_id` | バンドルID | Info.plistから自動取得 |

**優先順位**: コマンド引数 > 設定ファイル > 自動検出

## 設定の変更

ユーザーが「デバイスを変更したい」「設定をリセットしたい」と言った場合:

1. 現在の設定を表示:
```bash
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agent-skills/ios-device-build"
cat "$CONFIG_DIR/settings.conf"
```

2. ユーザーに新しい設定を確認
3. 設定ファイルを更新

## 設定ファイル形式

`$XDG_CONFIG_HOME/agent-skills/ios-device-build/settings.conf`
(`XDG_CONFIG_HOME` 未設定時は `~/.config/agent-skills/ios-device-build/settings.conf`):

```bash
# デフォルトのデバイス名（部分一致で検索）
# 空欄の場合は毎回自動検出
DEFAULT_DEVICE_NAME=""

# デフォルトのスキーム名（空欄で自動検出）
DEFAULT_SCHEME=""

# 完了通知の言語（"ja" or "en"）
NOTIFY_LANGUAGE="ja"

# ビルドログの表示行数
BUILD_LOG_LINES=30
```

## 手動実行コマンド

### 接続デバイス一覧
```bash
xcrun devicectl list devices
```

### ビルド
```bash
xcodebuild -project <project>.xcodeproj -scheme <scheme> -destination 'id=<UDID>' build
```

### インストール
```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "<scheme>.app" -path "*/Debug-iphoneos/*" -type d | head -1)
xcrun devicectl device install app --device <UDID> "$APP_PATH"
```

### 起動
```bash
xcrun devicectl device process launch --device <UDID> <bundle_id>
```

## 前提条件

- Xcode がインストール済み
- 有効な開発者証明書とプロビジョニングプロファイル
- デバイスがMac に接続され、信頼済みであること
- デバイスのロックが解除されていること

## トラブルシューティング

| エラー | 解決策 |
|--------|--------|
| No devices found | デバイスが接続・ロック解除されているか確認 |
| Device not found | 「デバイス変更したい」と言って再設定 |
| Build failed | Xcodeでエラー詳細確認、証明書/プロビジョニング確認 |
| Install failed | 「設定 > 一般 > VPNとデバイス管理」で開発元を信頼 |
| Launch failed | バンドルIDが正しいか確認 |

## ファイル構成

```
skills/ios-device-build/
├── SKILL.md
├── config/
│   └── settings.conf.example
└── scripts/
    └── device_build.sh

$XDG_CONFIG_HOME/agent-skills/ios-device-build/
└── settings.conf
```
