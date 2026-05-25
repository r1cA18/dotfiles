# Fastlane よく使うアクション

## TestFlight 関連

### upload_to_testflight (pilot)

```bash
# 基本
fastlane pilot upload

# オプション指定
fastlane pilot upload --ipa "path/to/app.ipa"
```

```ruby
# Fastfile 内
upload_to_testflight(
  api_key: api_key,
  ipa: "build/App.ipa",
  skip_waiting_for_build_processing: true,  # 処理完了を待たない
  distribute_external: false                 # 外部テスターに配布しない
)
```

### テスター管理

```bash
# テスター一覧
fastlane pilot list

# 内部テスター追加
fastlane pilot add email@example.com

# グループに追加
fastlane pilot add email@example.com -g "Internal Testers"

# テスター削除
fastlane pilot remove email@example.com
```

### ビルド番号

```ruby
# 最新ビルド番号取得
latest_testflight_build_number(api_key: api_key)

# 自動インクリメント
increment_build_number(
  build_number: latest_testflight_build_number(api_key: api_key) + 1
)
```

---

## ビルド関連

### build_app (gym)

```ruby
# iOS
build_app(
  scheme: "MyApp",
  export_method: "app-store",
  output_directory: "build"
)

# macOS
build_mac_app(
  scheme: "MyApp",
  export_method: "app-store"
)
```

### run_tests (scan)

```ruby
run_tests(
  scheme: "MyApp",
  devices: ["iPhone 16", "iPad Pro (12.9-inch)"],
  clean: true
)
```

---

## 証明書・プロファイル (match)

```ruby
# 取得のみ（変更しない）
match(
  api_key: api_key,
  type: "appstore",
  readonly: true
)

# 新規作成または更新
match(
  api_key: api_key,
  type: "appstore",  # development, adhoc, appstore
  force_for_new_devices: true
)
```

---

## App Store 提出 (deliver)

```ruby
# メタデータ + スクリーンショットをアップロード
deliver(
  api_key: api_key,
  submit_for_review: false,
  automatic_release: false
)

# 審査提出
deliver(
  api_key: api_key,
  submit_for_review: true,
  automatic_release: true,
  force: true  # 確認をスキップ
)
```

---

## その他

### スクリーンショット (snapshot)

```ruby
capture_screenshots(
  devices: ["iPhone 16", "iPad Pro (12.9-inch)"],
  languages: ["en-US", "ja"]
)
```

### 通知

```ruby
# Slack 通知
slack(
  message: "Build uploaded to TestFlight!",
  success: true,
  slack_url: ENV["SLACK_WEBHOOK_URL"]
)
```

---

## コマンドライン例

```bash
# TestFlight アップロード
fastlane pilot upload

# ビルド + アップロード
fastlane ios beta

# テスター追加
fastlane pilot add user@example.com -g "Internal Testers"

# 証明書同期
fastlane match appstore --readonly

# テスト実行
fastlane test

# スクリーンショット撮影
fastlane snapshot
```

---

## 環境変数

| 変数 | 用途 |
|------|------|
| `APP_STORE_CONNECT_API_KEY_KEY_ID` | API Key ID |
| `APP_STORE_CONNECT_API_KEY_ISSUER_ID` | Issuer ID |
| `APP_STORE_CONNECT_API_KEY_KEY` | .p8 ファイルの内容 |
| `SCHEME` | デフォルト scheme |
| `IPA_PATH` | IPA ファイルパス |
