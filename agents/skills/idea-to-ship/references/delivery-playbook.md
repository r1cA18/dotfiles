# Delivery Playbook

## Local Environment

実装先を決める前に次を確認する。

- project-local `AGENTS.md`、`CLAUDE.md`、architecture docs
- repository root、default branch、remote、working tree
- package manager、Nix flake、runtime、test/build commands
- sibling repositoriesと`ghq root`
-既存の命名、commit、PR、release規約
- user-owned uncommitted changes

secret fileの中身は出力しない。存在と必要なkey名だけ確認する。

## Repository Strategy

既存repositoryを優先するのではなく、ownershipとlifecycleが一致する場所を選ぶ。

新規repositoryが必要な場合:

1. `ghq root`と既存配置を確認する。
2. GitHub ownerと命名規則を確認する。
3. collisionのない短いkebab-case名を選ぶ。
4. local repositoryを適切なghq pathへ作る。
5. `git init -b main`を実行する。
6. 最小README、license方針、ignore、toolchainを追加する。
7. 許可済みなら`gh repo create --private --source . --remote origin`を実行する。
8. baseline commitをpushする。

既存OSSを取り込む場合はlicense、notice、upstream remote、update strategyを記録する。

## Commit Strategy

- Conventional Commitsなどproject規約を優先する。
- generated artifactとsource changeを意味なく分離しない。
- unrelated changesをstageしない。
- testを偽装するsnapshot更新や広すぎるformat変更を混ぜない。
- commit前にstaged diffを読む。

## Clean Definition

完了時に次を満たす。

- intended filesがcommit済み
- `git status --short`が空
- branchにupstreamがある
- remote branchが最新
- temporary logs、credentials、build outputsが未追跡でない
- stashを新しく残していない
- merge、PR、releaseの状態がhandoffに明記されている

既存のuser-owned dirty stateがあった場合は勝手に消さない。作業開始時と終了時の差を分けて報告する。

## Failure Handling

| Failure | Response |
| --- | --- |
| remote auth failure | local commitまで完了し、必要なlogin commandとretry手順を残す |
| branch protection | push後にPRを作り、mergeは止める |
| CI failure | logを読み、local reproduction後に修正する |
| secret detection | pushを止め、履歴へ入る前に除去する |
| unrelated dirty files | pathを除外し、clean claimを限定する |
