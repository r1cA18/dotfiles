---
name: forms-archive
description: Archive every page of a Microsoft Forms (Office 365, forms.office.com) survey/quiz/assignment as PDF and/or MHTML using a pre-saved logged-in browser session. MUST use when the user shares a forms.office.com URL and asks to save, archive, back up, download, PDF化, MHTML化, 手元に残す, or 問題文を保存. Auto-fills required fields only to traverse multi-page forms, and NEVER clicks Submit. Not for Google Forms (docs.google.com/forms) or generic web pages. Triggers: "Forms保存して", "フォームをPDF化", "フォームをアーカイブ", "office formsを保存", "MS Formsアーカイブ", "問題文を保存", "save forms as pdf", "archive ms forms", "forms-archive <URL>", "/forms-archive".
---

# Microsoft Forms Archive

Microsoft Forms (forms.office.com) の複数ページフォームを **全ページPDF + MHTML 保存** するスキル。
事前にログイン済みセッションを保存しておけば、URL 渡すだけで全ページを保存できる。送信はしない。

## When to use

- ユーザーが `https://forms.office.com/...` のURLを渡して「保存」「PDF化」「アーカイブ」と言ったとき
- 課題提出前に問題文だけ手元に残したいとき（提出はユーザー側で別途）
- 必須項目があって途中で次ページに進めない複数ページフォーム

## When NOT to use

- Google Forms (docs.google.com/forms) → このスキル対象外
- 単に1ページの内容を読みたいだけ → `agent-browser open` + `snapshot` で十分
- フォーム送信を自動化したい → このスキルは **submit を絶対に押さない** 設計。別スキルが必要

## 初回セットアップ（一度だけ）

```bash
cd ~/dotfiles/skills/forms-archive
bun install
bunx playwright install chromium
```

## 使い方

### 1. ログイン（初回 + セッション期限切れ時）

`--login` で Chromium ウィンドウが開く。**手動でログイン**（MFA 込み）して
フォーム1ページ目まで到達すると、スクリプトが自動検出して storageState を保存し、ブラウザを閉じる。
（stdin は使わない。Enter キー操作不要）

```bash
bun ~/dotfiles/skills/forms-archive/archive.ts --login "<forms-url>"
# ブラウザで Microsoft ログイン + MFA → 1ページ目表示 → 自動で保存・終了
# → ~/.agent-browser/forms-state.json (0o600)
```

セッションは数週間〜数ヶ月持つ。期限切れたら同じコマンドで上書き保存。

### 2. アーカイブ実行

```bash
# 基本: ./docs/ 配下に PDF/ と MHTML/ を作って全ページ保存
bun ~/dotfiles/skills/forms-archive/archive.ts "<forms-url>"

# 出力先指定
bun ~/dotfiles/skills/forms-archive/archive.ts "<forms-url>" ./03/docs

# MHTML だけ欲しい
FORMAT=mhtml bun ~/dotfiles/skills/forms-archive/archive.ts "<forms-url>"

# デバッグ（ブラウザを表示）
HEADED=1 bun ~/dotfiles/skills/forms-archive/archive.ts "<forms-url>"
```

実行はどのディレクトリからでも OK。出力先は引数（カレント基準）。

## 環境変数

| 変数 | 役割 | デフォルト |
|---|---|---|
| `FORMAT` | csv of `pdf,mhtml,html` （`both` = `pdf,mhtml`） | `pdf,mhtml` |
| `HEADED` | `1` でブラウザを可視化（デバッグ用） | unset |
| `FORMS_STATE_PATH` | storageState JSON のパス | `~/.agent-browser/forms-state.json` |
| `MAX_PAGES` | ループ安全上限 | `30` |
| `DEBUG_DOM` | `1` で1ページ目の生HTMLを `_debug-page1.html` に吐いて終了 | unset |

## 動作

1. `storageState` を読み込んでログイン状態を復元
2. フォームURLを開く
3. ループ:
   - 現在ページを `${N}.pdf` / `${N}.mhtml` で保存（PDFはフルページ、MHTMLは完全スナップショット）
   - 必須項目を自動充填（ラジオは先頭、textarea は `-`）
   - 「次へ」ボタンを探す → あればクリックして次ページへ
   - 「次へ」がなく「送信」だけ残ったら停止（送信しない）
4. 終了時にブラウザを閉じる

## 注意

- **送信ボタンは絶対に押さない**。実提出はユーザー判断
- 自動充填は「次ページに遷移するためのダミー」。本回答は別途
- フォームによって構造が違うので、新しいフォームで初回失敗したら `HEADED=1` で挙動を見て `archive.ts` のセレクタを調整

## 出力例

```
03/docs/
├── PDF/
│   ├── 1.pdf       # ページ1/4 (AI用: Claude の Read で直読可)
│   ├── 2.pdf
│   ├── 3.pdf
│   └── 4.pdf
└── MHTML/
    ├── 1.mhtml     # ページ1/4 (人間用: Chrome で完璧再現)
    ├── 2.mhtml
    ├── 3.mhtml
    └── 4.mhtml
```

### 形式の使い分け

| 用途 | おすすめ | 理由 |
|---|---|---|
| Claude に投げて解説/Grep | **PDF** | テキスト層 + 画像ビジョン両対応 |
| 人間が見直す | **MHTML** | Chrome で元のフォームと寸分違わず |
| Safari / 軽量参照 | PDF | MHTML は Chrome/Edge のみ |
| diff / 検索 | PDF を `pdftotext` で抽出 | MHTML は quoted-printable で生読み不可 |

## 構造メモ（MS Forms 2026-05 観測）

質問要素は `data-automation-id` で安定識別できる:

| ID | 意味 |
|---|---|
| `questionItem` | 質問コンテナ |
| `requiredStar` | 必須マーク `*` |
| `questionTitle` | 質問文 |
| `radio` | ラジオ option (`role="radio"`) |
| `textInput` | textarea 自身（`<textarea data-automation-id="textInput">`） |
| `nextButton` | 「次へ」 |
| `submitButton` | 「送信」（最終ページのみ） |

## トラブルシュート

| 症状 | 原因 | 対処 |
|---|---|---|
| 1ページしか保存されない | 必須項目埋め失敗→次へ進めず即終了判定 | `DEBUG_DOM=1` で1ページ目DOM吐く |
| 「Page N did not advance」 | バリデーション通らず次へ進めず | `_debug-stuck-pageN.html` を見てセレクタ修正 |
| ログインで10分待ってもタイムアウト | フォームURL誤り or 認証失敗 | URLとアカウント確認 |
| storageState not found | 未ログイン | `--login` モードで保存 |
