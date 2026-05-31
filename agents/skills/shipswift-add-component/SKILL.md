---
name: shipswift-add-component
description: Add a single SwiftUI UI component from ShipSwift recipes (animation, chart, alert, loading, input, etc.). Use when the user asks to add a ShipSwift component, "add a shimmer/chart/loading view", or wants a specific SwiftUI UI element backed by a ShipSwift recipe. Requires the shipswift MCP server. 日本語: 「ShipSwiftのコンポーネント追加」「シマー/チャート/ローディングを追加」「SwiftUI部品を入れて」
---

# ShipSwift: Add Component

ShipSwift の recipe から SwiftUI コンポーネントを 1 つ追加する。recipe (ソース + 統合手順) は shipswift MCP server が供給する (`listRecipes` / `searchRecipes` / `getRecipe`)。ローカルにソースは持たない。

## 前提

- `shipswift` MCP server が接続されていること (ios パック選択時に `.mcp.json` へ登録される)。
- 無料 recipe は API key 不要。Pro recipe は環境変数 `SHIPSWIFT_API_KEY` が必要 ($89)。

## 手順

1. 要求されたコンポーネント種別を特定する (animation / chart / component / module)。
2. `searchRecipes` でキーワード検索、または `listRecipes` でカテゴリ一覧から該当 recipe を探す。
3. `getRecipe` で完全な実装 (ソース + アーキテクチャ解説 + 統合チェックリスト) を取得する。
4. プロジェクトに統合する。スタイル / データ / platform 条件を実際の用途へ合わせる。
5. 依存を確認する。

## 規約

- 型は `SW` prefix (例 `SWDonutChart`)、view modifier は `.sw` prefix (例 `.swShimmer()`)。
- Dark Mode / Dynamic Type 対応をデフォルトで保つ。
- 単一ファイル component と複数ファイル module を区別し、module はフォルダごと取り込む。
