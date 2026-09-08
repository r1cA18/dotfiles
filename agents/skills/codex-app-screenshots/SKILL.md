---
name: codex-app-screenshots
description: >
  Generate App Store marketing mockups when the user chooses the ChatGPT Web UI workflow.
  Upload reference images and app screenshots through an available authenticated browser,
  generate mockups, and download the results. Supports iPhone and iPad layouts.
  Use the requested image tool or screenshot editor for other screenshot workflows.
---

# App Store Screenshots Generator (ChatGPT Web UI)

ChatGPT Web UIの利用可能な画像生成機能でApp Storeスクリーンショットのmockupを作る。
iPhone / iPad の両デバイスに対応し、縦向き・横向きを選択可能。

**フロー**: デバイス選択 → プロジェクト理解 → プロンプト構築 → Chrome で ChatGPT 操作 → 生成 → ダウンロード

## Why ChatGPT Web UI

ユーザーがWeb UIでの生成を選んだ場合に使う。APIや他の画像生成toolとの品質差は未測定。
生成結果のUI・文字・寸法を検証する。別の生成手段が指定された場合はその選択に従う。

## Browser capability

- 利用中agentで使用可能なbrowser skillの操作規則を先に読む
- 通常は`agent-browser`を使い既存Chrome sessionが必要な場合は利用可能なChrome操作toolを選ぶ
- tab操作・クリック・画像upload・downloadが可能か確認する
- 特定製品のMCP tool名が他製品にも存在するとは考えない
- 必要な操作が提供されない場合は不足している操作だけを説明する
- 本文のclipboard操作はmacOS用の代替例として扱いbrowser toolがuploadを提供する場合はそちらを使う

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

## Step 0: デバイス選択と向き自動判定

### 0a. デバイスを聞く

対象デバイスは依頼やproject設定から確認する。未確定で出力に影響する場合だけ、利用中agentの質問機能か通常の会話で確認する。

**質問: 対象デバイス**
- iPhone
- iPad
- 両方

### 0b. 向きを自動判定

ユーザーから受け取ったアプリ画面スクショの画像サイズから縦横を自動判定する。

```bash
# 画像の幅と高さを取得
magick identify -format "%w %h" "$IMAGE_PATH"
```

- 幅 < 高さ → 縦向き (Portrait)
- 幅 > 高さ → 横向き (Landscape)
- 幅 = 高さ → 縦向き (Portrait) をデフォルトとする

### デバイスサイズ早見表

| デバイス | 縦向き (Portrait) | 横向き (Landscape) |
|----------|-------------------|--------------------|
| iPhone | 1284 x 2778 | 2778 x 1284 |
| iPad | 2048 x 2732 | 2732 x 2048 |

判定結果を以降のステップで使う:
- `{{DEVICE_TYPE}}`: iphone / ipad
- `{{OUTPUT_SIZE}}`: デバイス + 向きに応じたサイズ (例: `1284 x 2778`)
- `{{DEVICE_LABEL}}`: iPhone / iPad
- `{{ORIENTATION}}`: portrait / landscape

「両方」が選択された場合、Step 2 以降をデバイスごとに繰り返す。
向きは両デバイスとも同じスクショから判定するため共通。

### 配色とスタイル

プロンプトの `{{STYLE_DIRECTION}}` には、アプリの実際のデザイン（配色、フォント、
雰囲気）を反映させる。アプリの UI スクショやプロジェクトのアセットから
メインカラーやアクセントカラーを読み取り、プロンプトに含める。

例: 「アプリのメインカラー #007AFF を基調にしたクリーンなスタイル」

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

選んだbrowser toolで新しいtabを作成し`https://chatgpt.com`へ移動する。

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

browser toolの文字入力機能へプロンプトを文字列として渡す。macOSのclipboardを使う場合は保存したprompt fileを`pbcopy < prompt.txt`で読み込み、本文をshell commandへ展開しない。

直接入力した場合は追加のpasteを行わない。clipboard方式の場合だけ入力欄をクリックして`Cmd+V`で貼り付ける。どちらも本文と添付画像を確認してから送信する。

### 2d. 生成を待つ

生成時間は選択したmodelと混雑状況によって変わる。

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

今回のdownloadで得たfileだけを列挙して出力先へ配置する。`~/Downloads`全体へのglobやfile名からshell commandを組み立てる操作は使わない。出力先に同名fileがある場合は別名を選び、生成前からあった画像を上書きしない。

## Step 3: リサイズ (任意)

```bash
# iPhone の場合
~/dotfiles/agents/skills/codex-app-screenshots/scripts/resize-screenshots.sh \
  "$OUTPUT_DIR" "$OUTPUT_DIR/export" iphone

# iPad の場合
~/dotfiles/agents/skills/codex-app-screenshots/scripts/resize-screenshots.sh \
  "$OUTPUT_DIR" "$OUTPUT_DIR/export" ipad
```

| デバイス | サイズ |
|----------|--------|
| iPhone 6.9" | 1320 x 2868 |
| iPhone 6.5" | 1284 x 2778 |
| iPhone 6.3" | 1206 x 2622 |
| iPhone 6.1" | 1125 x 2436 |
| iPad 13" | 2064 x 2752 |
| iPad 12.9" Pro | 2048 x 2732 |

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
| ChatGPT を開く | browser依存 | 利用可能なtab操作 |
| 画像アップロード | browser/OS依存 | 対応するupload機能またはmacOSのclipboard |
| プロンプト送信 | browser依存 | 対応する文字入力またはclipboardからのpaste |
| 生成待ち | screenshot機能が必要 | 30秒間隔で状態を確認 |
| ダウンロード | browser/UI依存 | 現行UIで対象画像と保存先を確認 |
| リサイズ | ImageMagickが必要 | 元画像を残して別の出力先へ保存 |

## Notes

- 全画面分のモックアップは1回のプロンプトで一括生成される
- 同一セッション内で修正指示を送るとスタイルの一貫性が保たれる
- 参考画像を変えたい場合は `references/` 内の画像を差し替える
- ChatGPT の UI が変更された場合はスクリーンショットで確認しながら適応する
