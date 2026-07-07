# Decision Gates

## Purpose

自律実行を止めず、ユーザーの判断が結果を大きく変える場面だけ質問する。

## Ask or Continue

| 状況 | 行動 |
| --- | --- |
| 可逆でscope内の実装判断 | 仮定を明示して続行 |
| 調査で短時間に検証できる不明点 | 先に調査 |
| 2案の差が小さく後で変更可能 | project patternに合う案を選択 |
| 対象ユーザー、business model、privacy方針が変わる | 質問 |
| data loss、課金、公開、production影響がある | 質問 |
| user-owned changesとの衝突が避けられない | 質問 |
| credentialや外部承認が必要 | 質問 |

## Question Shape

1. 判断対象を1文で示す。
2. 推奨案を最初に置く。
3. 2〜3個の相互排他的な選択肢を出す。
4. 各選択肢の結果とtradeoffを1文で示す。
5. 回答がなくても進められる作業を続ける。

Claude Codeでは`AskUserQuestion`を使う。Codexで選択式input toolがあれば使う。どちらもなければ短いplain-text questionを使う。

## Authorization Record

開始時に次を内部stateまたはproject noteへ記録する。

- 許可された外部変更
- 必ず確認する変更
- 想定するrepositoryとvisibility
- deployの有無
- secretや個人dataの扱い

依頼文が「private repoを作ってpushまで」のように明確なら、その操作を再確認しない。visibility変更、public公開、production deployへscopeが広がる場合は追加確認する。

## Visual Explanation

選択肢がarchitecture、UX、multi-step flowに関わる場合は、文章だけで押し切らない。

- exact mappingにはtableを使う。
- sequenceにはMermaid flowchartかtimelineを使う。
- UI判断にはscreenshot、mockup、prototypeを使う。
- 3つ以上の下流影響がある判断にはdecision matrixを使う。

汎用Artifacts skillが利用可能なら使う。なければself-contained HTMLを一時生成し、選択後に最終handoffへ統合する。
