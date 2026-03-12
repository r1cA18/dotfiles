---
name: profile
description: |
  Performance profiling with xctrace (Instruments CLI). Record, parse, analyze, and optimize.
  Triggers: "profile", "profiler", "performance", "Instruments", "xctrace", "Time Profiler"
  日本語: 「パフォーマンス計測」「プロファイルして」「ボトルネック調べて」
---

# Performance Profiling (xctrace)

CLI から Xcode Instruments の Time Profiler を実行し、ボトルネックを特定・修正する。

## シミュレータでプロファイル取得

```bash
# シミュレータ起動 & アプリインストール済みの前提
xcrun simctl boot "iPhone 16" 2>/dev/null

# Time Profiler で5秒間記録
xctrace record \
  --template 'Time Profiler' \
  --attach '<APP_NAME_OR_PID>' \
  --time-limit 5s \
  --output /tmp/profile.trace

# アプリ起動時のプロファイル
xctrace record \
  --template 'Time Profiler' \
  --time-limit 10s \
  --output /tmp/profile.trace \
  --launch -- <APP_BINARY_PATH>
```

## 実機でプロファイル取得

```bash
# デバイスUDID確認
xcrun devicectl list devices

# 実機アプリにアタッチ
xctrace record \
  --template 'Time Profiler' \
  --device '<UDID>' \
  --attach '<APP_NAME>' \
  --time-limit 5s \
  --output /tmp/profile.trace
```

## 結果をパース & 分析

```bash
# パーサースクリプトで要約（top 20 hotspots）
python3 "$(agent-skill-path swift-dev-toolkit scripts/parse_profile.py)" \
  --input /tmp/profile.trace --top 20

# TOC確認（利用可能なテーブル一覧）
xctrace export --input /tmp/profile.trace --toc

# 生データ出力
python3 "$(agent-skill-path swift-dev-toolkit scripts/parse_profile.py)" \
  --input /tmp/profile.trace --raw
```

出力例:

```
Time Profiler Summary (top 20 hotspots)
============================================================
    Weight       %  Symbol
----------  ------  ----------------------------------------
    4520.0   35.2%  -[DataManager loadInitialData]
    2100.0   16.4%  -[ViewRenderer renderMainView]
     890.0    6.9%  swift_retain
...
```

## 自律プロファイリングループ

エージェントが自動でプロファイル→分析→修正→再計測を回す。

```
1. xctrace record でプロファイル取得
2. parse_profile.py で上位ホットスポット抽出
3. 該当コードを読み、改善策を実施
4. ビルド (/swift-dev-toolkit:build)
5. 再度 xctrace record で効果測定
6. 改善が確認できるまで繰り返す
```

## 他のテンプレート

| テンプレート    | 用途                       |
| --------------- | -------------------------- |
| `Time Profiler` | CPU ボトルネック           |
| `Allocations`   | メモリ使用量・確保パターン |
| `Leaks`         | メモリリーク検出           |
| `System Trace`  | スレッド・システムコール   |
| `Network`       | ネットワーク通信           |

```bash
# 利用可能テンプレート一覧
xctrace list templates
```

## UIテストと組み合わせ

特定の操作シナリオをプロファイルする場合、UIテストと組み合わせる。

```bash
# UIテスト実行中にプロファイル
xctrace record \
  --template 'Time Profiler' \
  --time-limit 30s \
  --output /tmp/profile.trace \
  --launch -- xcodebuild test \
    -scheme <SCHEME> \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing '<TARGET>/<TEST_CLASS>/<TEST_METHOD>'
```
