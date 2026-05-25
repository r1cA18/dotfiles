---
name: app-store-screenshots
description: >
  Use when generating App Store marketing screenshots via ChatGPT Web UI.
  Opens ChatGPT in Chrome, uploads reference images + app screenshots,
  sends a prompt, waits for image generation, and downloads the results.
  Reads the project context to generate appropriate app descriptions and
  screen headlines for each mockup.
  Triggers on: app store screenshots, store screenshots, marketing screenshots,
  generate app screenshots, app store mockup, mockup generation.
  JA: アプリストアスクリーンショット生成, ストア画像生成, モックアップ生成,
  App Storeスクリーンショット, ストアスクショ
---

# App Store Screenshots Generator (ChatGPT Web UI)

ChatGPT 4o のネイティブ画像生成を使って App Store スクリーンショットモックアップを作る。

**フロー**: プロジェクト理解 → プロンプト構築 → Chrome で ChatGPT 操作 → 生成 → ダウンロード

## Why ChatGPT Web UI

API 経由の画像生成では iPhone モックアップ内に実際のアプリ UI を正確に配置する
品質が出ない。ChatGPT Web UI の 4o ネイティブ画像生成は参考画像を few-shot example
として受け取り、スタイルを再現できる。

## Assets

スキルディレクトリ: `~/dotfiles/agents/skills/codex-app-screenshots/`

| ファイル | 用途 |
|----------|------|
| `references/IMG_3833.jpg` | 参考画像 1 (ホーム画面モックアップ例) |
| `references/IMG_3834.jpg` | 参考画像 2 (カレンダー画面モックアップ例) |
| `references/IMG_3835.jpg` | 参考画像 3 (分析画面モックアップ例) |
| `references/IMG_3836.jpg` | 参考画像 4 (診断画面モックアップ例) |
| `prompt-template.md` | プロンプトテンプレート (固定制約 + 動的パート) |
| `scripts/resize-screenshots.sh` | 生成画像を各デバイスサイズにリサイズ |

## Step 1: プロジェクト理解 & プロンプト構築

### 1a. プロジェクトのコンテキストを読む

以下を読んでアプリの概要を把握する:
- `CLAUDE.md` / `README.md` -- アプリの説明、機能一覧
- Xcode プロジェクト設定 -- アプリ名、Bundle ID
- 既存の App Store メタデータ -- `description.txt`, `keywords.txt` 等

### 1b. ユーザーから受け取る情報

| 項目 | 必須 | 説明 |
|------|------|------|
| アプリ画面スクショ | 必須 | モックアップ内に入れる画像のパス群 |
| 見出し / 説明文 | 任意 | 各画面に付けるテキスト。省略時は自動生成 |
| スタイル指示 | 任意 | 「参考画像と同じ」がデフォルト |
| 出力先 | 任意 | デフォルトはプロジェクト内の適切な場所 (後述) |

### 1c. プロンプトを組み立てる

`prompt-template.md` を読み込み、2つのパートを結合する:

1. **固定制約** -- そのまま使う (サイズ、レイアウト、制約ルール)
2. **動的パート** -- プロジェクトから得た情報で埋める:
   - `{{APP_NAME}}`: アプリ名
   - `{{APP_DESCRIPTION}}`: アプリの一言説明
   - `{{TARGET_USER}}`: ターゲットユーザー
   - `{{STYLE_DIRECTION}}`: スタイル指示 (デフォルト: 「参考画像と同じクリーンなスタイルで」)
   - `{{SCREEN_LIST}}`: 各画面の見出しと説明

見出し/説明が省略された場合は、アプリの機能と各スクショの内容から適切な
見出し（短く、インパクト重視）を自動生成してプロンプトに含める。

## Step 2: ChatGPT で生成 (Chrome 操作)

### 2a. ChatGPT を開く

```
mcp__claude-in-chrome__tabs_create_mcp  -- 新しいタブを作成
mcp__claude-in-chrome__navigate         -- https://chatgpt.com にナビゲート
```

- ログイン済みであることを確認（サイドバーに会話一覧が表示されるか）
- 新しいチャットが開いていることを確認

### 2b. 画像をアップロード (clipboard paste)

macOS の clipboard を使って1枚ずつペーストする。

```bash
# JPEG
osascript -e 'set the clipboard to (read (POSIX file "PATH") as JPEG picture)'
# PNG
osascript -e 'set the clipboard to (read (POSIX file "PATH") as <<class PNGf>>)'
```

ペースト順序:
1. 参考画像 4枚 (`references/IMG_3833.jpg` ~ `IMG_3836.jpg`)
2. アプリ画面スクショ (ユーザー指定)

各画像: `osascript` でクリップボードにコピー → 入力欄をクリック → `Cmd+V` → 1.5秒待ち

全画像がサムネイルとして入力欄に表示されたことをスクリーンショットで確認。

### 2c. プロンプトを送信

```bash
# 構築済みプロンプトをクリップボードにコピー
echo "PROMPT_TEXT" | pbcopy
```

入力欄をクリック → `Cmd+V` でペースト → 送信ボタンをクリック

### 2d. 生成を待つ

生成には 2-5 分かかる (5画面で約3-4分)。

30秒間隔でスクリーンショットを取得してポーリング:
- 「Thinking...」「思考中」表示: まだ生成中
- 画像プレビュー表示 + 入力欄が復活: 生成完了
- 最大待機時間: 8分

### 2e. ダウンロード & 配置

1. 生成画像の右下にある **共有アイコン (↑)** をクリック
2. **「このシリーズの N 枚の画像すべて」** を選択
3. **「ダウンロードする」** をクリック

ダウンロード後、プロジェクト内の適切な場所に配置する。

#### 出力先の決定ロジック

ユーザーが出力先を指定した場合はそれに従う。
指定がない場合、プロジェクト構成から適切な場所を判断する:

| 条件 | 配置先 |
|------|--------|
| `docs/screenshots/` が存在 | `docs/screenshots/appstore/` |
| `docs/images/` が存在 | `docs/images/appstore/` |
| `docs/` が存在 | `docs/appstore-screenshots/` |
| fastlane を使用 (`fastlane/` が存在) | `fastlane/screenshots/ja/` |
| 上記いずれもなし | `docs/appstore-screenshots/` を新規作成 |

```bash
# 出力先ディレクトリを作成
mkdir -p "$OUTPUT_DIR"

# ~/Downloads から移動 & リネーム
mv ~/Downloads/ChatGPT*.png "$OUTPUT_DIR/"
cd "$OUTPUT_DIR"
ls -1 ChatGPT*.png | sort | awk '{printf "mv \"%s\" \"slide-%02d.png\"\n", $0, NR}' | sh
```

## Step 3: リサイズ (任意)

```bash
~/dotfiles/agents/skills/codex-app-screenshots/scripts/resize-screenshots.sh \
  "$OUTPUT_DIR" "$OUTPUT_DIR/export" iphone
```

| デバイス | サイズ |
|----------|--------|
| iPhone 6.9" | 1320 x 2868 |
| iPhone 6.5" | 1284 x 2778 |
| iPhone 6.3" | 1206 x 2622 |
| iPhone 6.1" | 1125 x 2436 |

## Output

```
$PROJECT_ROOT/docs/appstore-screenshots/   (or detected path)
  slide-01.png
  slide-02.png
  ...
  export/           (resize した場合)
    1320x2868/
    1284x2778/
    ...
```

## Automation Constraints

| ステップ | 自動化 | 方法 |
|----------|--------|------|
| ChatGPT を開く | OK | `navigate` MCP tool |
| 画像アップロード | OK | `osascript` clipboard + `Cmd+V` |
| プロンプト送信 | OK | `pbcopy` + `Cmd+V` + click send |
| 生成待ち | OK | 30秒間隔 screenshot polling |
| ダウンロード | OK | 共有ボタン → 全画像 → ダウンロード |
| リサイズ | OK | ImageMagick script |

## Notes

- 全画面分のモックアップは1回のプロンプトで一括生成される
- 同一セッション内で修正指示を送るとスタイルの一貫性が保たれる
- 参考画像を変えたい場合は `references/` 内の画像を差し替える
- ChatGPT の UI が変更された場合はスクリーンショットで確認しながら適応する
