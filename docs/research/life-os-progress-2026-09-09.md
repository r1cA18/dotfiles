# Life OS調査の進捗

## 目的

音声・Discord・スマホからの入力を記憶と作業実行へつなぐLife OSについて既存資産と公開事例を比較し責務境界・段階導入・未決質問をまとめる。今回は調査と設計提案であり実サービスや保存方式を変更しない。

## 確認済み

- dotfilesのarchitecture・agent-platforms・workspace・session-handoffガイドを確認
- OlympusにTimes REST・intake schema・SQLite indexの実装が存在
- Home Assistantに未実装と明記されたVoiceOS設計が存在
- vault-agiにDiscord・Gateway・Master構成とDaily永続化の実装が存在
- vaultにTimesから観測・調査・ユーザーモデルへ接続する設計文書が存在
- 設計文書間にOlympusの責務と録音保持方針の差が存在
- Orca・Omi・Home Assistant・音声会話基盤・記憶基盤・耐久実行・評価研究の22組の一次資料を確認
- Olympusのintake route登録とLLM worker起動を確認。driverは設定情報を返すだけの実装と確認

## 判断と未検証事項

repositoryの責務は分けつつ入力契約と状態所有者を統合する。保存モデルは2026-09-14の再調査でDB正本・添付ファイル・Markdown exportを推奨する方向へ更新した。READMEや設計文書だけで稼働済みとは判定しない。サーバー稼働状態・日本語音声性能・予算・介入方針は未確認。Orcaの対象と予定hardwareは2026-09-14に確認済み。

## 成果物と検証

- [調査レポート](life-os-architecture-2026-09-09.md)を作成
- [56項目の設計質問票](life-os-questions-2026-09-09.md)を作成
- 脚注22組の参照と定義の対応を確認
- 質問番号の連続性とcode fenceの対応と末尾空白を確認
- 成果物に個人発言原文・account情報・private absolute pathを記載していない
- 実サービス変更・agent委譲・導入・性能benchmark・稼働確認は未実施

## 次の作業

初回調査は完了。質問票の最優先項目への回答を基に一つの通しの体験と受入条件を確定する。特に録音保持・介入・自動着手・cloud除外基準・予算が未決。既存の他作業の変更は保持した。

## 2026-09-14の要件反映

- Home Assistant repository側のdocs/16-open-homepod-vision.mdへ29項目の音声構想を保存
- 同repositoryのdocs目次・VoiceOS参照・Status・session logを更新
- Ryzen 5 PRO・RAM 16GB・storage 1TBを予定hardwareとして記録
- 圏外対応は初期scope外としUI/CLI編集を前提に変更
- 現在利用中のOrca / Orca CLIを対象として特定
- Markdown正本を必須とせずDB正本とexport方式も再比較する方針を記録
- wake→duckと呼びかけ前の常時記録の接続を未決点として明記
- cloud処理は許容方向だが個人情報の除外範囲は未確定

公開仕様の再調査・機器操作・deployは行っていない。Home Assistantの既存の他作業の差分は保持した。

## 2026-09-14の保存モデル再調査

前節は音声構想の保存作業についての記録。続く保存モデル調査では公開資料を再確認した。

- [vault保存モデル調査](vault-data-model-2026-09-14.md)を追加
- vaultの旧分類と新しいdomain directoryの併存を確認
- OlympusのTimes型とarchitectureを再確認
- Omi・LLM Wiki・Basic Memory・OpenClaw・Capacities・MyLifeBitsの一次資料を比較
- SQLiteの用途指針とFTS5の制約とGraphitiを確認
- DB正本を推奨しTimesを共通の生活ログとする設計を記録
- 原音声・STT・整形済みTimes・長期記憶・実行状態の境界を整理
- 新レポートの脚注9件の対応とcode fenceと表記を検証
- `git diff --check`が成功
- コード・設定・実データの変更と導入とbenchmarkは未実施

整形粒度は本人の意味のある発言を軽く整形して残す方針で確定した。重要度による選別は長期記憶への昇格で行い、Timesの原記録からは捨てない。Timesの表示先が内部feedかDiscordへの投稿も含むかは未確定。

## 2026-09-14の検証実装

- 現行vaultを`/Users/r1ca18/Backups/life-os/20260913T201923Z`へコピー
- 1,714ファイルと18 symlinkを含む約2.97GBをコピーし、SHA-256とコピー前後のmanifest一致を確認
- [検証実装](../../experiments/life-os-storage/README.md)を追加
- DB・blob・source version・evidence・revision・dependency・membership・jobを分離
- `10_Daily`からTimesを1,271件抽出し、Knowledge 124件、Task 42件、Resource 608件などを試験割当
- hidden/config/symlink 611件は検索対象から外し、バックアップには保持
- SQLite integrity checkとforeign key checkが成功
- 日本語短語・重複入力・訂正競合・派生記録のstale化・agent task候補の未承認状態をテスト
- export 13,340 rows・1,108 blobsからrestoreしcanonical table一致を確認
- Bun test 10件が成功。localhost listenは実行環境の制限でintegration testから除外
- semantic STT・LLM整理・embedding・外部公開・既存vault切替は未実施
