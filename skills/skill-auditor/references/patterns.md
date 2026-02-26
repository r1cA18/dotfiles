# Skill Architecture Patterns

既存スキルから抽出した4つのアーキテクチャパターン。
audit 時に「このスキルはどのパターンに当てはまるか」を判定し、
パターンに見合った構成を持っているかを評価する。

---

## Type 1: Router + Sub-skills

複数の独立した機能を持つツールキット型スキル。

### いつ使うか

- 3つ以上の独立した機能がある
- 各機能が独自の指示（50行以上）を必要とする
- ユーザーが「〜の機能だけ使いたい」と言える粒度がある

### 必須構成

```
skill-name/
├── SKILL.md              # ルーター: 振り分けテーブル + ルーティングロジック
├── skills/
│   ├── sub1/SKILL.md     # サブスキル1
│   ├── sub2/SKILL.md     # サブスキル2
│   └── sub3/SKILL.md     # サブスキル3
├── scripts/              # 共有スクリプト
├── templates/            # 共有テンプレート
└── references/           # 共有参照資料
```

### ルーター SKILL.md の必須要素

1. **Sub-Skill テーブル**: 各サブスキルの名前、呼び出し方、用途を表で整理
2. **ルーティングルール**: 「〜のキーワード → sub1」の振り分け条件
3. **共有リソースの説明**: scripts/templates/references/ の構成

### 良い例: swift-dev-toolkit

- 6サブスキル（build, fastlane, project, profile, xcodegen, docc）
- 各サブスキルが独立した SKILL.md を持つ
- 共有リソース: `scripts/build_loop.sh`, `templates/Fastfile`, `references/troubleshooting.md`
- ルーター description に全サブスキルのトリガーを網羅

### よくある問題

- ルーターの description にサブスキルのトリガーが含まれていない
- 共有リソースが特定サブスキルのディレクトリに入っている（root に置くべき）
- サブスキルが2つしかない（router にするほどでもない → Type 2 で十分）

---

## Type 2: Single Skill + References

1つの明確な目的を持ち、ドメイン知識やヘルパーを参照資料として同梱。

### いつ使うか

- 目的は1つだが、実行にドメイン知識が必要
- ヘルパースクリプトやテンプレートがある
- SKILL.md だけでは 200行を超える

### 必須構成

```
skill-name/
├── SKILL.md              # メイン指示（500行以下）
├── REFERENCE1.md         # ドメイン知識（progressive disclosure）
├── REFERENCE2.md         # 追加参照
├── scripts/              # ヘルパースクリプト
└── templates/            # 出力テンプレート
```

### SKILL.md の設計

- 最も重要な情報を SKILL.md body に含める
- 詳細は references にリンク: `[FFMPEG.md](FFMPEG.md)` 形式
- 判断基準は表で整理（「いつ A を使い、いつ B を使うか」）

### 良い例: video-editing

- SKILL.md: ワークフロー概要 + ツール選択の判断基準表
- FFMPEG.md: FFmpeg コマンドリファレンス
- FRAMESCRIPT.md: FrameScript API リファレンス
- TEMPLATES.md: コピペ用テンプレート
- ANALYSIS.md: 動画内容分析ガイド

### よくある問題

- SKILL.md に全部詰め込んで 500行超（references に分割すべき）
- references/ に入れるべき内容を SKILL.md にインライン展開
- references が SKILL.md の内容と重複している

---

## Type 3: Reference Library

ドメインのベストプラクティスや規約を整理した知識ベース型。

### いつ使うか

- 多数の独立したルール/パターンがある（10個以上）
- エージェントが必要なルールだけ読めばよい
- 定期的にルールが追加/更新される

### 必須構成

```
skill-name/
├── SKILL.md              # インデックス: ルール一覧 + いつ使うか
└── rules/
    ├── rule1.md
    ├── rule2.md
    └── ...
```

### SKILL.md の設計

- ルール一覧をリンク付きで列挙
- カテゴリ分類（優先度、ドメイン等）
- 「全ルール読め」ではなく「関連するルールだけ読め」と指示

### 良い例: remotion-best-practices, vercel-react-best-practices

- remotion: 28ルールファイル（3d, animations, audio, ...）
- vercel-react: 45ルール、8カテゴリ、優先度付き

### よくある問題

- SKILL.md にルールが全部インラインで書かれている（rules/ に分割すべき）
- ルールファイルの粒度が不均一（1つだけ 500行、他は 20行）
- インデックスが古くなっている（新しいルールが SKILL.md に未記載）

---

## Type 4: Simple

単一目的の小さなスキル。SKILL.md のみで完結。

### いつ使うか

- 目的が明確で単純（CLI ラッパー、チェックリスト等）
- 指示が 100行以下で収まる
- 外部ドメイン知識が不要

### 必須構成

```
skill-name/
└── SKILL.md              # 全ての指示
```

### SKILL.md の設計

- frontmatter に集中投資（description がトリガーの唯一の手がかり）
- 本文はコンパクトに（コマンド一覧、チェックリスト等）
- 「これだけ読めば使える」を目指す

### 良い例: gog-calendar（ただし frontmatter 改善の余地あり）

### よくある問題

- 複雑なスキルなのに Simple で済ませている（Type 2 以上にすべき）
- frontmatter の description が貧弱（Simple こそ description が命）
- JA triggers がない

---

## パターン選択フローチャート

```
スキルの機能数は？
├── 3つ以上の独立した機能 → Type 1: Router + Sub-skills
├── 1つだが、ドメイン知識が必要
│   ├── 10個以上のルール/パターン → Type 3: Reference Library
│   └── 少数の参照資料で十分 → Type 2: Single + References
└── 1つで、100行以下で書ける → Type 4: Simple
```
