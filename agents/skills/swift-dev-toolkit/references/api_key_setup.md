# App Store Connect API Key セットアップ

## 1. API Key を作成

1. [App Store Connect](https://appstoreconnect.apple.com) にアクセス
2. **Users and Access** → **Integrations** → **App Store Connect API**
3. **Generate API Key** をクリック
4. 設定:
   - **Name**: `Fastlane` など識別しやすい名前
   - **Access**: `Admin` または `App Manager`
5. **Generate** をクリック

## 2. 必要な情報をメモ

| 項目 | 場所 | 例 |
|------|------|-----|
| **Issuer ID** | ページ上部 | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| **Key ID** | 作成したキーの行 | `ABC123XYZ` |
| **.p8 ファイル** | Download ボタン | `AuthKey_ABC123XYZ.p8` |

**重要**: .p8 ファイルは **1回しかダウンロードできない**。紛失した場合は新しいキーを作成する必要がある。

## 3. ローカルに配置

```bash
# ディレクトリ作成
mkdir -p ~/.appstoreconnect/private_keys

# .p8 ファイルを移動
mv ~/Downloads/AuthKey_ABC123XYZ.p8 ~/.appstoreconnect/private_keys/

# パーミッション設定（セキュリティ）
chmod 600 ~/.appstoreconnect/private_keys/AuthKey_*.p8
```

## 4. 環境変数を設定

`~/.zshrc` (または `~/.bashrc`) に追加:

```bash
# App Store Connect API Key
export APP_STORE_CONNECT_API_KEY_KEY_ID="ABC123XYZ"
export APP_STORE_CONNECT_API_KEY_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export APP_STORE_CONNECT_API_KEY_KEY="$(cat ~/.appstoreconnect/private_keys/AuthKey_ABC123XYZ.p8)"
```

設定を反映:
```bash
source ~/.zshrc
```

## 5. 動作確認

```bash
# Fastlane で確認
fastlane pilot builds
```

エラーなく最新ビルド番号が表示されれば成功。

---

## トラブルシューティング

### "Invalid token" エラー

- Issuer ID または Key ID が間違っている
- .p8 ファイルの内容が正しくない（改行などに注意）

### "Forbidden" エラー

- API Key の Access が不足している（Admin または App Manager が必要）
- Team ID が間違っている

### 環境変数が読み込まれない

```bash
# 確認
echo $APP_STORE_CONNECT_API_KEY_KEY_ID

# 空なら source し直す
source ~/.zshrc
```
