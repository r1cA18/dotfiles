# Troubleshooting

## App Store Connect Upload

### "Failed to Use Accounts" エラー

キーチェーン認証情報が壊れている場合:

```bash
# 認証情報を削除
security delete-generic-password -s "Xcode-Token" 2>/dev/null
security delete-generic-password -s "Xcode-AlternateDSID" 2>/dev/null

# Xcode 再起動
killall Xcode; sleep 2; open /Applications/Xcode.app
```

その後、Xcode → Settings → Accounts で再認証。

### "ARCHIVE FAILED" ビルドエラー

DerivedData をクリア:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/<PROJECT>-*
```

### macOS "LSApplicationCategoryType" エラー

SKILL.md Section 6 を参照して App Category を設定。

### dSYM 警告

「Upload Symbols Failed」の警告はサードパーティフレームワーク（Sentry など）の dSYM が含まれていない場合に表示される。アップロード自体は成功しており、通常は無視して問題ない。

---

## Build Errors

### Provisioning Profile エラー

```bash
# プロファイル確認
ls ~/Library/MobileDevice/Provisioning\ Profiles/

# 古いプロファイル削除
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/*
```

Xcode で再ビルドすると自動再取得される。

### Code Signing エラー

```bash
# キーチェーンのロック解除
security unlock-keychain -p "" ~/Library/Keychains/login.keychain-db
```

### Simulator 起動エラー

```bash
# シミュレータをリセット
xcrun simctl shutdown all
xcrun simctl erase all
```
