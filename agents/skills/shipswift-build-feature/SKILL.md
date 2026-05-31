---
name: shipswift-build-feature
description: Build a complete iOS feature by composing multiple ShipSwift recipes (auth, camera, chat, paywall, settings, dashboards, etc.). Use when the user asks to build/create an iOS feature, or describes a SwiftUI feature to implement. Requires the shipswift MCP server. 日本語: 「ShipSwiftで機能を作る」「認証/カメラ/課金フローを構築」「iOS機能を実装して」
---

# ShipSwift: Build Feature

複数の ShipSwift recipe を組み合わせて iOS 機能を構築する。recipe は shipswift MCP server が供給する。カスタムコードを書く前に、まず recipe を参照する。

## 前提

- `shipswift` MCP server が接続されていること。
- 無料 recipe は API key 不要。Pro recipe は `SHIPSWIFT_API_KEY` が必要。

## 手順

1. 機能要求を個別のコンポーネントに分解する。
2. `searchRecipes` で関連 recipe を検索する。
3. `getRecipe` で各 recipe の完全な実装とアーキテクチャ詳細を取得する。
4. recipe の接続と必要なカスタマイズを示す統合プランを提示する。
5. ユーザーのプロジェクトに合わせてコードを生成・適応する。
6. 依存とセットアップ要件のチェックリストを提供する。

## 規約

- `SW` prefix 型 / `.sw` prefix modifier。
- Dark Mode / Dynamic Type をデフォルトで考慮する。
- 既存 recipe を最大限活用し、ゼロから実装しない。
