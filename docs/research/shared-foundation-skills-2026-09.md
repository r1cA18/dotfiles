---
title: "複数agentで共有する基礎skillの選定"
created: 2026-09-07
type: research
tags: [skills, agents, nix, testing]
---

# 複数agentで共有する基礎skillの選定

## 採用内容

既存の文書化・Web UI・Swift・review skillに加え、GitHub Actionsの失敗調査、
明示的なsecurity review、property-based testingの3つをglobal共有へ追加する。
公式かどうかだけでは決めず、適用範囲・補助script・runtime依存・個別licenseを確認した。

| 採用skill                 | 出典                 | 判断                              | License      |
| ------------------------- | -------------------- | --------------------------------- | ------------ |
| `gh-fix-ci`               | OpenAI skills        | CLI workflowをlocal adapterへ更新 | Apache-2.0   |
| `security-best-practices` | OpenAI skills        | 言語別referenceをそのまま利用     | Apache-2.0   |
| `property-based-testing`  | Trail of Bits skills | 限定的なmetadata調整と出典追記    | CC-BY-SA-4.0 |

新しい専用API・MCP・accountは要求しない。Codex/Claude両targetに同じskillを配布する。
workspace専用のskill切替やruntime plugin cacheのコピーは追加しない。

## 公式sourceの現状

[OpenAIの公式catalog](https://github.com/openai/skills)は非推奨を明記し、
[openai/plugins](https://github.com/openai/plugins)を現在の例として案内している。
2026-09-07に取得したpluginsのGitHub folderにはapp/MCP定義があり、
旧catalogの`gh-fix-ci`や`gh-address-comments`は含まれていなかった。
検索結果に以前のskillページが残るため、採用判断には実際のcheckoutを使った。

旧catalogからの採用はcommitを固定する。新しい公式pluginの全体を共通化したとは扱わない。
OpenAI自身もskillの入口にはname・descriptionを置き、必要時に本文やreferencesを読む構造を説明している。
[Build skills](https://learn.chatgpt.com/docs/build-skills)

Anthropicは[公開repo](https://github.com/anthropics/skills)に複数のskillを提供するが、
`docx`・`pptx`・`pdf`・`xlsx`には個別の制限付きLICENSEがある。
例として[docxのLICENSE](https://github.com/anthropics/skills/blob/main/skills/docx/LICENSE.txt)は
service外への複製・改変等を制限している。今回の汎用global共有の新規採用条件に合わないため、
docx/pptxの単純追加は行わない。既存のpdf/xlsxはこの作業で削除・改変していない。

## 選択の境界

### GitHub Actions

元の[gh-fix-ci](https://github.com/openai/skills/tree/49f948faa9258a0c61caceaf225e179651397431/skills/.curated/gh-fix-ci)は
GitHub CLIによるcheck・log調査を提供する。元の本文にはローカル修正前の固定承認があり、
補助scriptには古いCLI fieldのfallbackがある。

配布時に[local adapter](../../agents/skills/upstream-adapters/gh-fix-ci.md)へ入口だけを差し替える。
`gh pr view`・`gh pr checks`・`gh run view`のJSONを直接使い、以下を明記した。

- failing/pendingによるnonzero exitとCLI自体のエラーを区別
- forkのhead repoではなくPR URLのbase repoを使用
- 実行commitと現在のcheckoutを照合
- GitHub Actions以外のproviderはlinkの報告まで
- 調査依頼と修正依頼を区別
- 既に得た承認を保持
- local check成功とremote CI成功を区別

upstreamのPython helperはbundleに残るが、このadapterでは呼び出さない。
GitHubへの投稿・push・remote job再実行をskillの導入だけで許可するわけではない。

### Security Review

[security-best-practices](https://github.com/openai/skills/tree/49f948faa9258a0c61caceaf225e179651397431/skills/.curated/security-best-practices)は
Python・JavaScript/TypeScript・Go向けの言語/framework別referenceを持つ。
descriptionが明示的なsecurity reviewまたはsecure-by-defaultの依頼に限定されているため、
既存post-reviewと役割を分けられる。SwiftやNixを対応言語だとは扱わない。

通常の実装に必ず追加のsecurity工程を挟むためのskillではない。
修正依頼も含まれている場合は既存の承認範囲を引き継ぐ。

### Property-Based Testing

[Trail of Bitsのproperty-based-testing](https://github.com/trailofbits/skills/tree/d3323cefbcf645678b8dc481de204b02ad3d02dc/plugins/property-based-testing)
を採用する。parser・serializer・normalizer・numeric type等の性質を検証する用途に適する。
「実装を同じ式で再計算するtest」や「ほぼ全ての入力をfilterして何も検証しないtest」の検出に具体性がある。

本文と5つのreferencesを確認した。provider固有toolの呼び出しや自動インストールを要求しない。
既存のtest libraryを使い、性質を定義できないコードではexample testを選ぶ余地もある。
配布では`effort: low`を除去し、[CC-BY-SA-4.0](https://github.com/trailofbits/skills/blob/d3323cefbcf645678b8dc481de204b02ad3d02dc/LICENSE)
の出典とlicenseのNix store pathを追記する。

## 見送った候補

| 候補                              | 出典             | 今回見送る理由                                                               |
| --------------------------------- | ---------------- | ---------------------------------------------------------------------------- |
| docx・pptx                        | Anthropic        | 個別licenseが汎用共有の新規採用条件に合わない                                |
| webapp-testing                    | Anthropic        | Python Playwright固定。helperはshell子孫のcleanupやport所有確認に不足がある  |
| doc-coauthoring                   | Anthropic        | 文書化の既存skillと重複。繰り返す質問・承認段階が今回の運用と合わない        |
| gh-address-comments               | OpenAI           | helperがfork PRをhead repoで解決。独立connectionのpaginationに重複取得の余地 |
| systematic-debugging              | obra/superpowers | 全bugへの強い適用と別superpowers skillへの依存。既存instructionと重なる      |
| plugin同梱documents/presentations | OpenAI runtime   | Codex内では利用可能。runtime専用資産をそのままClaude共有へコピーしない       |

`webapp-testing`のreadinessはnetworkidleを必須とするが、現行Playwrightはこれをtestの準備完了判定に推奨していない。
既存`agent-browser`とproject内のPlaywright testを使う方針を維持する。
[Playwright Page API](https://playwright.dev/docs/api/class-page#page-wait-for-load-state)

上記は候補の品質を全面否定する評価ではなく、現在のdotfilesにglobal追加するかの判断である。
Officeの追加共有skillが必要になった場合は、利用可能なOSS libraryとrender手順を独立して選ぶ。

## 固定と配布

| Input                | Revision                                   | 対象                               |
| -------------------- | ------------------------------------------ | ---------------------------------- |
| `openai-skills`      | `49f948faa9258a0c61caceaf225e179651397431` | gh-fix-ci・security-best-practices |
| `trailofbits-skills` | `d3323cefbcf645678b8dc481de204b02ad3d02dc` | property-based-testingのみ         |

`flake.lock`更新前後のJSON比較で既存nodeとroot inputを全て保持し、新規2nodeだけを追加した。
OpenAI sourceは`filter.nameRegex`で2skillだけをdiscoveryし、既存pdfやsystem skillとの名前衝突を避ける。
Trail of Bits sourceも対象pluginのskills directoryだけを参照する。

PBT libraryは使うprojectの依存として管理する。Nixのglobal環境へHypothesisやfast-checkを追加しない。
skillの導入と各projectでのlibrary選択は別の操作である。

## 検証範囲

macOSのNix skill bundleをbuildし、indexion-workspaceも含む43件のYAML parseと
nameの一意性を確認した。追加3件はsystem skill-creatorの`quick_validate.py`を通過した。
PBTの5つのreferenceとlicense path、gh-fix-ciのApache LICENSEも配布物で確認した。

Linux Home Managerではskill選択・source・Claude/Codex両targetの評価が成功した。
Linux用bundleの実buildはmacOSからのplatform mismatchで実施できていない。
この結果をLinux実機への反映確認とは扱わない。

新規sourceの固定と既存lock保持、adapterで使う`gh`のJSON fieldを確認した。
Nix formatterと`git diff --check`も実施した。
GitHubへの実通信・remote CIの再実行・全frameworkでのsecurity評価は今回の導入検証に含めない。
モデルを使ったtrigger率の測定も行っていない。

運用は[Agent Skillsガイド](../guides/skills.md)を参照する。
