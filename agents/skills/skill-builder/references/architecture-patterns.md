# Skill Architecture Patterns

Anthropic公式ガイド + dotfiles実績から抽出した4つのアーキテクチャパターン。
スキル作成時に最適なパターンを選択する。

## パターン選択フローチャート

```
スキルの機能数は?
|-- 3つ以上の独立した機能 --> Type 1: Router + Sub-skills
|-- 1つだが、ドメイン知識が必要
|   |-- 10個以上のルール/パターン --> Type 3: Reference Library
|   +-- 少数の参照資料で十分 --> Type 2: Single + References
+-- 1つで、100行以下で書ける --> Type 4: Simple
```

---

## Type 1: Router + Sub-skills

複数の独立した機能を持つツールキット型。

### 条件

- 3つ以上の独立した機能
- 各機能が独自の指示（50行以上）を必要とする
- ユーザーが個別の機能を名指しできる粒度

### 構成

```
skill-name/
|-- SKILL.md              # ルーター: 振り分けテーブル + ルーティングロジック
|-- skills/
|   |-- sub1/SKILL.md     # サブスキル1
|   |-- sub2/SKILL.md     # サブスキル2
|   +-- sub3/SKILL.md     # サブスキル3
|-- scripts/              # 共有スクリプト
|-- templates/            # 共有テンプレート
+-- references/           # 共有参照資料
```

### ルーター SKILL.md の必須要素

1. **Sub-Skill テーブル**: 各サブスキルの名前、用途を表で整理
2. **ルーティングルール**: キーワード -> サブスキルの振り分け条件
3. **共有リソースの説明**: scripts/templates/references/ の構成
4. **description**: 全サブスキルのトリガーを網羅

### dotfiles 実例: swift-dev-toolkit

- 6サブスキル（build, fastlane, project, profile, xcodegen, docc）
- 各サブスキルが独立した SKILL.md を持つ
- 共有リソース: scripts/build_loop.sh, templates/, references/

### よくある問題

- ルーターの description にサブスキルのトリガーが漏れている
- 共有リソースが特定サブスキルのディレクトリに入っている（root に置くべき）
- サブスキルが2つしかない（Type 2 で十分）

---

## Type 2: Single Skill + References

1つの明確な目的 + ドメイン知識を参照資料として同梱。

### 条件

- 目的は1つだが、実行にドメイン知識が必要
- ヘルパースクリプトやテンプレートがある
- SKILL.md だけでは 200行を超える

### 構成

```
skill-name/
|-- SKILL.md              # メイン指示（200行以下目標）
|-- references/
|   |-- guide.md          # ドメイン知識
|   +-- troubleshooting.md
|-- scripts/              # ヘルパースクリプト
+-- templates/            # 出力テンプレート
```

### SKILL.md の設計

- 最も重要な情報を body に含める
- 詳細は references にリンク: `[file.md](references/file.md)` 形式
- 判断基準は表で整理

### dotfiles 実例: video-editing, skill-auditor

- video-editing: FFmpeg vs FrameScript の判断基準表 + 各ツールの詳細をリファレンスに分離
- skill-auditor: ルーブリック/パターン/アンチパターンを references に分離

### よくある問題

- SKILL.md に全部詰め込んで 200行超（references に分割すべき）
- references が SKILL.md の内容と重複
- references へのリンクが SKILL.md にない

---

## Type 3: Reference Library

ベストプラクティスやルールの知識ベース型。

### 条件

- 多数の独立したルール/パターン（10個以上）
- エージェントが必要なルールだけ読めばよい
- 定期的にルールが追加/更新される

### 構成

```
skill-name/
|-- SKILL.md              # インデックス: ルール一覧 + いつ使うか
+-- rules/
    |-- rule1.md
    |-- rule2.md
    +-- ...
```

### SKILL.md の設計

- ルール一覧をリンク付きで列挙
- カテゴリ分類
- 「全ルール読め」ではなく「関連するルールだけ読め」と指示

### dotfiles 実例: remotion-best-practices, vercel-react-best-practices

### よくある問題

- SKILL.md にルールが全部インラインで書かれている
- ルールファイルの粒度が不均一
- インデックスが更新されていない

---

## Type 4: Simple

単一目的の小さなスキル。SKILL.md のみで完結。

### 条件

- 目的が明確で単純
- 指示が 100行以下
- 外部ドメイン知識が不要

### 構成

```
skill-name/
+-- SKILL.md              # 全ての指示
```

### SKILL.md の設計

- frontmatter に集中投資（description がトリガーの唯一の手がかり）
- body はコンパクトに
- 「これだけ読めば使える」を目指す

### よくある問題

- 複雑なスキルなのに Simple で済ませている（Type 2 以上にすべき）
- frontmatter の description が貧弱
- JA triggers がない

---

## Anthropic公式パターン（ワークフロー設計用）

スキルのアーキテクチャとは別に、SKILL.md body 内のワークフロー設計に使えるパターン:

### Pattern A: Sequential Workflow Orchestration

多段階プロセスを特定の順序で実行。各ステップに依存関係とバリデーション。

### Pattern B: Multi-MCP Coordination

複数のMCPサービスをフェーズごとに連携。サービス間のデータ受け渡しを明示。

### Pattern C: Iterative Refinement

出力品質をループで改善。品質チェック -> 問題特定 -> 修正 -> 再チェック。

### Pattern D: Context-Aware Tool Selection

同じ目的に複数のツール候補。条件によって最適なツールを選択する判断木。

### Pattern E: Domain-Specific Intelligence

ドメイン専門知識をロジックに埋め込み。コンプライアンスチェック、監査ログ等。
