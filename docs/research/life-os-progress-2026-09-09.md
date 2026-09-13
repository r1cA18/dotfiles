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

既存repoは維持して入力契約と状態所有者を統合する方向を暫定案とする。READMEや設計文書だけで稼働済みとは判定しない。サーバー稼働状態・日本語音声性能・本人が指すOrca・予算・介入方針は未確認。

## 成果物と検証

- [調査レポート](life-os-architecture-2026-09-09.md)を作成
- [56項目の設計質問票](life-os-questions-2026-09-09.md)を作成
- 脚注22組の参照と定義の対応を確認
- 質問番号の連続性とcode fenceの対応と末尾空白を確認
- 成果物に個人発言原文・account情報・private absolute pathを記載していない
- 実サービス変更・agent委譲・導入・性能benchmark・稼働確認は未実施

## 次の作業

初回調査は完了。質問票の最優先項目への回答を基に一つの通しの体験と受入条件を確定する。特に録音保持・介入・自動着手・hardware・予算が未決。既存の他作業の変更は保持した。
