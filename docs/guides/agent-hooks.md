---
title: "Agent hooksと進捗保存"
created: 2026-09-07
type: guide
tags: [agents, hooks, progress]
---

# Agent hooksと進捗保存

## 方針

hookは短く決定的な検査と任意の通知を担当する。文体や作業工程は共有ルールへ置き、文脈を判断できない検出はadvisoryとして返す。進捗の要約を行うLLMやtranscriptの自動保存はhookから起動しない。

登録と実装は分離する。

| 対象               | Source of truth                                      |
| ------------------ | ---------------------------------------------------- |
| 共有hook           | `agents/hooks/`                                      |
| Claude固有hook     | `claude/hooks/`                                      |
| Claude登録         | `nix/home-manager/programs/claude-code.nix`の`hooks` |
| Codex登録          | `codex/hooks.json`                                   |
| 共有進捗保存ルール | `agents/rules/engineering.md`の`Progress Records`    |

## 登録済みhook

2026-09-07のリポジトリ宣言を対象にした棚卸し。pluginが独自に提供するhookや各repoのlocal hookはこの表に含めない。現在のruntimeと宣言が一致するかは設定反映後に確認する。

| Agent  | Event                                                                      | Hook                         | 動作                                                  |
| ------ | -------------------------------------------------------------------------- | ---------------------------- | ----------------------------------------------------- |
| Claude | PreToolUse / Edit・Write                                                   | emoji-guard                  | 絵文字候補のadvisory                                  |
| Claude | PreToolUse / Write                                                         | large-file-guard             | UTF-8で50KiBを超える書き込みのadvisory                |
| Claude | PreToolUse / Bash                                                          | debug-print-guard            | 単純なgit commitのstaged内容にあるprint/logのadvisory |
| Claude | PostToolUse / Edit・Write                                                  | ai-slop-guard                | 今回追加したprint/logの装飾候補のadvisory             |
| Claude | PostToolUse / Edit・Write                                                  | check-knowledge-index        | vaultのKnowledge Markdownを編集した場合のindex検査    |
| Claude | Notification / idle・permission                                            | OS音声通知                   | 利用可能な場合のみ再生                                |
| Claude | Stop                                                                       | OS音声通知                   | 利用可能な場合のみ再生                                |
| Claude | PostToolUse・PostToolUseFailure・PermissionRequest・Stop・UserPromptSubmit | Superset通知                 | `SUPERSET_HOME_DIR`が設定された場合のみ実行           |
| Codex  | SessionStart・UserPromptSubmit・Stop                                       | Superset通知                 | `SUPERSET_HOME_DIR`が設定された場合のみ実行           |
| Codex  | Stop                                                                       | check-knowledge-index --stop | vault内の最初のStopでindex検査                        |

すべての登録に5秒のtimeoutを設定した。Claude側のscript参照はprimary profileの`~/.claude/hooks`を経由せず、Nixが解決したdotfiles内の絶対パスを使う。Superset通知は両agentで同じ環境変数を使い、通常のterminalから既定の`~/.superset`を暗黙に実行しない。

`check-knowledge-index`は検出時にstderrとexit 2を返す。ClaudeのPostToolUseでは実行済み編集へのfeedbackになる。CodexのStopでは追加の修正turnを発生させるため、`stop_hook_active=true`の再実行では検査を行わない。未掲載が解消しない場合も同じStop hookが繰り返し作業を続行させることはない。

Claudeのadvisoryは`hookSpecificOutput.additionalContext`を含むJSONをstdoutへ返す。permission decisionは返さない。現行仕様ではイベントごとの出力形式が異なるため、plain textをstdoutへ書くだけでmodelへ伝わるとは扱わない。[Claude Code hooks](https://code.claude.com/docs/en/hooks#hook-input-and-output)

## 削除した未使用hook

| Script           | 判断               | 理由                                                  |
| ---------------- | ------------------ | ----------------------------------------------------- |
| auto-format.sh   | 登録とscriptを削除 | repoのformatter選択を確認せずfile全体を書き換えていた |
| test-reminder.sh | 登録とscriptを削除 | 毎編集で同じ静的指示を繰り返していた                  |

両scriptは登録と呼び出し元が残っていないことを確認して削除した。過去の実装はGit履歴から参照できる。formatとtestはrepoが指定するコマンドをagentが明示的に実行する。

emoji-guardは削除せずadvisoryへ変更した。旧実装はfile内容全体を文脈なく拒否していたため、product dataに必要な文字や明示的な依頼まで妨げていた。共有ルールの絵文字方針自体は維持する。

## 修正した検査

- Knowledge indexのalias・heading・`20_Knowledge/`付きリンクを掲載済みとして扱う
- Knowledge index自体の編集も検査する
- Markdown以外の編集ではKnowledge検査を行わない
- Stopのhook payloadにあるcwdと続行stateを使う
- 不正なhook JSONやfile path型を受け取っても通常作業を妨げない
- `VAULT_DIR`指定時はCodexのcwd制限も同じvaultへ向ける
- large-fileの判定を文字数からUTF-8 byte数へ修正する
- ai-slop検査を今回追加した文字列へ限定する
- debug-print検査でworking treeの代わりにGit index内のcontentを読む
- debug-print検査で`git -C <directory> commit`の対象repoを解決する

debug-printはPython標準の`shlex`でcommandを解析する。入力commandを実行しない。複雑なshell式や`git -c`などの任意のglobal optionを完全には解釈せず、対象が確定できない場合は検査を省く。print/logはCLIの正常出力である場合もあるため、commitはblockしない。共有ルールとreviewが最終的な判断を担う。

Knowledge indexは`20_Knowledge`直下のMarkdownが対象。本文の意味や説明の品質は検証しない。vaultまたはindexを読めない環境では検査を省く。subdirectoryを含む一般的なObsidian link検証器としては使わない。

## MacとLinux

検査scriptはBunとPython標準libraryとGitを使う。BSD/GNUで挙動が異なる`grep`のUnicode分類や文字数計算への依存を減らした。Bunは共通packageで供給する。debug-printの登録にはNixのPythonとGitのPATHを明示し、macOS付属Pythonの存在に依存させない。

音声通知はmacOSの`afplay`とLinuxの`canberra-gtk-play`へ分岐している。通知commandが使えなければ無音で終了する。GUIや音声sessionを持たないhomelabへ通知用desktop stackを追加することは今回の対象外とした。

## 進捗保存

非trivialな複数段階の作業では、開始時と再開時に既存のtask文書を読む。調査結果が固まった時点、実装・検証が一区切りついた時点、中断・引き継ぎ前に同じ文書を更新する。

保存内容は次の5点を基本とする。

- 目的と対象範囲
- 採用した判断と根拠
- 変更したもの
- 実行済み検証と未検証事項
- 次に行う作業と必要な入力

projectにtask文書やsession logの慣例があればそれに合わせる。なければ`docs/`に短い文書を一つ作る。小変更と個々のtool callに記録義務は課さない。共有文書にはcredential・個人account情報・private path・生のsession transcriptを入れない。公開してよい判断と検証結果に要約する。

この運用はagent自身が実行する共有ルールであり、Stop hookによる強制保存ではない。強制終了やcontext上限直前の書き込みを保証するものではないため、意味のある節目で更新する。

## 検証と反映

```bash
bun test agents/hooks/check-knowledge-index.test.ts claude/hooks/hooks.test.ts
nix-instantiate --parse nix/home-manager/programs/claude-code.nix
git diff --check
```

修正前にalias誤検知・入力型エラー・byte数判定・emoji拒否・working treeとindexの不一致を再現した。修正後は上記のfixtureで検証した。testsはtemporary directoryだけを使い、実vaultや実repoのindexを変更しない。LLMの起動も行わない。

Claudeの登録変更はNix適用後に新しいsessionの`/hooks`で確認する。Codexはhookの定義変更後に`/hooks`で内容をreviewして再trustする。現在の仕様では未trustの変更hookは実行されないため、設定fileを編集しただけでruntime反映済みとは扱わない。[Codex hooks](https://learn.chatgpt.com/docs/hooks#review-and-trust-hooks)

Mac上でのfixtureと構文検査は確認済み。Linux実行・agentの実際のイベント発火・通知音再生はこの検証に含めていない。
