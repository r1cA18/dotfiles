---
name: shipswift-explore-recipes
description: Explore and browse the ShipSwift recipe catalog (animations, charts, components, modules). Use when the user says explore/browse/show recipes, "what ShipSwift components are available", or wants to discover what ShipSwift offers. Requires the shipswift MCP server. 日本語: 「ShipSwiftのレシピを見る」「使えるコンポーネント一覧」「ShipSwiftで何ができる」
---

# ShipSwift: Explore Recipes

ShipSwift の recipe カタログを閲覧・検索する。recipe は shipswift MCP server が供給する。

## 前提

- `shipswift` MCP server が接続されていること。

## 手順

1. `listRecipes` でカテゴリ別 (Animation / Chart / Component / Module) に一覧表示する。必要ならカテゴリで絞る。
2. `searchRecipes` でキーワード検索する。
3. `getRecipe` で個別 recipe の詳細とコードプレビューを表示する。
4. よくある用途 (オンボーディング、分析ダッシュボード、ソーシャル機能等) に向けた recipe の組み合わせを提案する。

## メモ

- recipe には無料 tier と Pro tier ($89) がある。Pro は `SHIPSWIFT_API_KEY` が必要。
- 無料 tier だけでも animation / chart / 基本 UI component は一通り使える。
