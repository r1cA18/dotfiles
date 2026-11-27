---
title: "repoの検査: scripts/check・agent hook・CI・main保護"
created: 2026-11-12
type: guide
tags: [lint, ci, hooks, github]
---

# repoの検査

## 方針

- 検査の入口は各repo直下の`scripts/check`に揃える。人もagentもCIも同じcommandを使う
- 機械で判定できる規則だけをlinterとtestへ入れる。`AGENTS.md`には判断が要る規則だけを残し、完了条件は「`scripts/check full`が0で終わること」の1行にする
- agent hookは規則を持たない。編集されたfileのrepoにある`scripts/check fast`を呼び、失敗を知らせるだけで止めない
- CIはGitHub Actionsで`scripts/check full`を回す
- 個人repoの`main`はrulesetで保護し、変更はPRで入れる

## 置き場

| もの                 | 置き場                                            | 理由                                                          |
| -------------------- | ------------------------------------------------- | ------------------------------------------------------------- |
| 検査の中身           | 各repoの`scripts/check`と道具の設定file           | 道具と規則はrepoごとに違う。repoと一緒にreviewされる          |
| 言語別の雛形         | このrepoの`templates/repo-check/<言語>/`          | 新しいrepoへcopyして始める。copy後はrepo側が正                |
| agent hook           | `agents/hooks/run-repo-check.ts`                  | Claude CodeとCodexで共有する製品非依存の実装                  |
| hookの登録           | `claude-code.nix`の`hooks`、`codex/hooks.json`    | 登録は製品ごと(`docs/agent-platforms.md`の境界)               |
| CIの共通部           | `.github/workflows/repo-check.yaml`               | reusable workflow。checkoutと道具の導入と固定SHAを1か所で保守 |
| CIの呼び出し         | 各repoのworkflow `check.yaml`                     | 雛形は`templates/repo-check/check.yaml`                       |
| `main`の保護         | GitHubのruleset                                   | 雛形は`templates/repo-check/main-ruleset.json`                |
| 信頼するremoteの一覧 | 各machineの`~/.config/repo-check/trusted-remotes` | account名を公開repoへ書かない。machineごとの判断              |
| 完了条件の文         | 共有ruleの`agents/rules/engineering.md`           | 全repoに共通。repoの`AGENTS.md`で繰り返さない                 |

template repo(GitHubのtemplate機能)は使わない。言語ごとに中身が違い、既存repoへの後付けが主な用途なので、雛形のcopyで足りる。

## `scripts/check`の契約

| 呼び方                         | 意味                                                                 | 目標時間 | 使う場所     |
| ------------------------------ | -------------------------------------------------------------------- | -------- | ------------ |
| `scripts/check fast <file>...` | 渡されたfileだけを検査する。対象外の拡張子は無視して0で終わる        | 数秒     | agent hook   |
| `scripts/check changed [base]` | `base`(既定は`HEAD`)から変わったfileと未追跡file、それに要る遅い検査 | 1分程度  | 作業の区切り |
| `scripts/check full`           | 全部                                                                 | 制限なし | 完了条件とCI |

- 終了codeは成功が0、検査の失敗が1、使い方の誤りが2
- 出力は`path:line: message`の形を優先する。色は付けない(`NO_COLOR=1`)
- fileを書き換えない。整形は各自が編集したfileにだけ掛ける。repo全体へformatterを掛けると、未追跡の文書まで書き換わる
- 道具はPATHにあればそれを使い、無ければflakeから借りる(`nix develop -c`か`nix shell --inputs-from .`)。hookから毎回`nix`を起動すると2秒から3秒かかるので、よく使うrepoの道具はPATHに置く
- 規則を足すときは、現在の違反が0件のものだけをerrorにする。違反が残る規則は直してから入れる

## 言語別の雛形

| 言語            | 雛形                           | `fast`                              | `changed`と`full`                                      | repo側に要るもの                                   |
| --------------- | ------------------------------ | ----------------------------------- | ------------------------------------------------------ | -------------------------------------------------- |
| Rust            | `templates/repo-check/rust/`   | `rustfmt --check`                   | `cargo fmt --all --check`、clippy(`-D warnings`)、test | `flake.nix`のdevShell。境界規則は`clippy.toml`     |
| TypeScript(Bun) | `templates/repo-check/bun/`    | `biome check`                       | Biome、`bun run typecheck`、`bun test`                 | `biome.json`、`@biomejs/biome`、`typecheck` script |
| Swift           | `templates/repo-check/swift/`  | SwiftLint                           | SwiftLint、`swift test`(packageごと)                   | `.swiftlint.yml`(`only_rules: [custom_rules]`から) |
| Nix             | `templates/repo-check/nix/`    | statix、deadnix、`nixfmt --check`   | `changed`は同じ。`full`は`nix flake check`             | flakeの`checks`                                    |
| Python          | `templates/repo-check/python/` | `ruff check`、`ruff format --check` | Ruff、pytest(`uv run`)                                 | `pyproject.toml`と`uv.lock`                        |

複数の言語を持つrepoは、雛形を組み合わせた1つの`scripts/check`にする。このrepo自身の`scripts/check`はNixとshellとBunのtestを並べた例。

## agent hook

`agents/hooks/run-repo-check.ts`はClaude CodeとCodexのPostToolUseで動く。

1. 編集されたfileを求める。Claude Codeは`tool_input.file_path`、Codexは`tool_input.command`にあるapply_patchの`*** Add File:`、`*** Update File:`、`*** Move to:`の行
2. fileのgit rootに実行可能な`scripts/check`があり、remote `origin`が信頼一覧の接頭辞に一致するときだけ、`scripts/check fast <file>...`をrepo rootで実行する
3. 失敗したら出力の先頭40行を`hookSpecificOutput.additionalContext`で返す。終了codeは常に0で、作業を止めない
4. 12秒を超えた検査は何も返さずに打ち切る(`REPO_CHECK_TIMEOUT_MS`で変更できる)

信頼一覧は1行に1つのremoteの接頭辞を書く。接頭辞は末尾の`/`まで書く。sshとhttpsのremoteは同じ形に揃えて比べる。

```text
github.com/<owner>/
```

一覧が無いmachineではhookは何もしない。cloneした他人のrepoの`scripts/check`を、編集のたびに実行しないための条件。

Codexでhookの内容を変えたときは、Codexの`/hooks`から信頼し直す。

## CI

各repoは`templates/repo-check/check.yaml`を自分の`.github/workflows/`へcopyし、`<owner>`とdotfilesのcommit SHAを埋める。reusable workflowの入力:

| 入力              | 既定                 | 用途                                 |
| ----------------- | -------------------- | ------------------------------------ |
| `runs-on`         | `ubuntu-latest`      | Swiftは`macos-latest`                |
| `nix`             | `true`               | Nixを入れる                          |
| `dev-shell`       | `false`              | commandを`nix develop`の中で実行する |
| `bun`             | `false`              | Nixを使わないBunのrepo               |
| `command`         | `scripts/check full` | 合否を決めるcommand                  |
| `timeout-minutes` | `20`                 |                                      |

必須checkの名前は`check / check`(呼び出し側のjob名と、reusable workflow内のjob名)。

このrepoは公開repoなので、private repoからもreusable workflowを呼べる。dotfiles側の変更が全repoのCIへ波及しないよう、呼び出しはbranch名でなくcommit SHAで固定する。

このrepo自身のCIは`.github/workflows/lint.yaml`の`regression` jobで`scripts/check full`とintegration testを回す。

### 料金

- 公開repoの標準runnerは無料
- private repoはaccountの月間の無料枠(分数)を消費する。macOSのrunnerは1分が10分として数えられる
- 枠を超えるとspending limitに従って止まるか課金される。Swiftのrepoは`full`からUI testを外し、macOSのjobを1つに抑える
- 枠と使用量は所有者のGitHubのBilling画面で確認する

## mainの保護

`templates/repo-check/protect-main.sh <owner>/<repo> [必須check]...`が`templates/repo-check/main-ruleset.json`から`main`という名のrulesetを作るか更新する。

- `main`の削除と強制pushを禁じる
- 変更はPR経由にする。承認数は0(1人のrepoでは自分のPRを承認できない)
- 必須checkは、既に`main`で走っているcheck名だけを指定する。一度も報告されない必須checkはmergeを永久に止める。CIの無いrepoでは必須checkを外す
- repository adminは`pull_request`の範囲でだけbypassできる。PRのmergeでは失敗中のcheckを越えられるが、直接pushはadminでも拒否される。agentは所有者のtokenを使うので、ここをbypass可にすると保護が効かない
- 明示的に直接pushする場合は、所有者がrulesetを一時的に無効にする

## 新しいrepoへの導入

1. 言語の雛形を`scripts/check`へcopyし、実行権限を付ける
2. `scripts/check full`を緑にする。既存の違反が多い規則は外すか直してから入れる
3. `AGENTS.md`の完了条件を`scripts/check full`の1行にし、検査で守られた規則の文を消す
4. workflowの`check.yaml`を置き、PRで1回走らせる
5. `protect-main.sh`で`check / check`を必須checkにする

## まだ入れていないもの

- localのpre-commit hook。CIとagent hookで足りるかを見てから決める
- Stop hookでの`scripts/check changed`(遅い検査)
- hookで失敗をagentへ返して止める段(最初は知らせるだけ)
- 各repoの秘密の混入検査(このrepoはCIでgitleaksを回している)
