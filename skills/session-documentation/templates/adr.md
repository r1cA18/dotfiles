# ADR Template

**保存先:** `docs/decisions/{nnnn}-{title}.md`
**用途:** 技術選定・設計判断の記録（Architecture Decision Record）

---

## テンプレート構造

```markdown
# {番号}. {タイトル}

## ステータス

{Proposed | Accepted | Deprecated | Superseded by [ADR-XXXX](link)}

## 日付

{YYYY-MM-DD}

## コンテキスト

{この決定が必要になった背景・状況}
{解決すべき問題・制約・要件}

## 決定

{何を決定したか。明確に記述}

## 検討した選択肢

### Option A: {選択肢A}

{選択肢の説明}

**Pros:**
- {メリット1}
- {メリット2}

**Cons:**
- {デメリット1}
- {デメリット2}

### Option B: {選択肢B}

{選択肢の説明}

**Pros:**
- {メリット1}

**Cons:**
- {デメリット1}

## 結果・影響

{この決定による影響・トレードオフ}
{今後の開発への影響}

## 参考リンク

- [{参考資料1}]({URL1})
- [関連ADR]({link})
```

---

## ファイル名の例

- `0001-use-swiftui-for-ui.md`
- `0002-adopt-stripe-for-payments.md`
- `0003-choose-postgresql-over-mysql.md`

## 番号付けルール

- 4桁のゼロパディング: `0001`, `0002`, ...
- 既存のADRがある場合は連番で付与
- `docs/decisions/` 内の最大番号 + 1
