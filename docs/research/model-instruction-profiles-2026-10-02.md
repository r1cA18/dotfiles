# Model instruction profiles: evidence and integration

調査日: 2026-10-02
状態: instruction候補とcompilerを実装。モデルを呼び出した品質比較は未実施
資産: `agents/model-profiles/v1/`
compiler: `agents/scripts/model-profile.ts`

## 設計との関係

Harness Coreのarchitectureはinstruction packageにsource digest・Contract digest・rendered payload digest・runtime・generator versionを記録しようとしている。一方でmodel-specific compilationはMVP後の拡張としている。今回のcompilerは独立したopt-inの準備層。Task/Attemptや承認済みinstruction packageの代替ではない。Core側のledgerができた後にartifact digestをAttemptへ結び付ける。

共有instruction・project policy・skillをモデルごとに複製しない。model profileは短い行動上の差分だけを持つ。tool capability・account group・権限・approval・budget・thinking設定はruntimeが所有する。promptの文章による許可や秘密の保護を実装済みと見なさない。

## 調査対象と採用差分

主要なtext/tool-useモデルを対象とする。image・audio専用モデルとアクセス制限された特殊モデルは同じsystem instructionの適用対象にしない。APIでの提供とsubscription/native runtimeでの提供は別の確認項目。

| Provider | 明示的に選択するモデル | 採用した差分と根拠 |
| --- | --- | --- |
| OpenAI | GPT-6 Astra・GPT-6.1 Sol・GPT-6 Luna | 短いinstructionとtaskに必要なskill。Sol/Lunaはfamily-level候補で個別に最適とする実測なし。[公式catalog](https://developers.openai.com/api/docs/models)・[Astraのprompt/skill見直し](https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra) |
| Anthropic | Fable 5.1 | 進捗報告・独立toolのbatch・全要求の完了・handoffでconstraints保持。[専用guide](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1) |
| Anthropic | Opus 5.5 | 途中報告と完了を区別。外部contextはdataとして扱う。orchestrator側にも完了判定が必要。[専用guide](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5) |
| Anthropic | Sonnet 5.5 | 必要な検証まで継続。目的外の拡張と無制限reviewを避ける。[専用guide](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5) |
| Anthropic | Haiku 4.5 | bounded taskと明示output。大きいClaudeのadaptive effort設定を流用しない。[catalog](https://platform.claude.com/docs/en/models/overview)・[共通guide](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) |
| Google | Gemini 3.8 Flash・3.5 Flash-Lite・3.1 Pro Preview | constraintを明示。long contextの後にtaskを置く。reasoning全文を回答へ要求しない。[catalog](https://ai.google.dev/gemini-api/docs/models)・[prompt guide](https://ai.google.dev/gemini-api/docs/prompting-strategies) |
| xAI | Grok 4.7 | 時事はsearchで確認。X投稿の主張と根拠を分離。Xへの知識が自動で最新になるとは扱わない。[model guide](https://docs.x.ai/developers/grok-4-7)・[catalog](https://docs.x.ai/developers/models) |
| DeepSeek | V4.1 Flash alias・V4 Pro | 保守的なtask/output指示。Flash aliasが更新されるためruntimeで実modelを記録する。[公式changelog](https://api-docs.deepseek.com/updates/) |
| Qwen | Qwen3.5 397B-A17B・35B-A3B・9B | native chat templateとstructured tool parserを使う。小型を大型と同品質とは扱わない。[公式model card](https://huggingface.co/Qwen/Qwen3.5-397B-A17B) |
| Z.ai | GLM-5.3 | 明示taskとcode検証。reasoningは常時有効。endpointとsubscriptionごとのprotocol差を確認。[公式guide](https://docs.z.ai/guides/llm/glm-5.3) |
| Moonshot | Kimi K2.6 | deliverableと検証を明示。native swarmがあっても委譲権限を増やさない。[公式model card](https://huggingface.co/moonshotai/Kimi-K2.6) |
| MiniMax | M2.7 | native parser経由のtool利用と結果検証。出力XMLを正規表現で拾って実行しない。[公式model card](https://huggingface.co/MiniMaxAI/MiniMax-M2.7)・[tool guide](https://huggingface.co/MiniMaxAI/MiniMax-M2.7/blob/main/docs/tool_calling_guide.md) |
| Mistral | Medium 3.5・Small 4 | objectiveとschemaを明示。曖昧な形容詞や矛盾を減らす。[catalog](https://docs.mistral.ai/models)・[prompt guide](https://docs.mistral.ai/inference/prompting) |

上の文章は各sourceをもとにした短い候補でありvendorのsystem prompt全文をコピーしていない。`sources.json`はURL・確認日・source区分・採用理由を保持する。

## Model設定とhistoryで混ぜてはいけないこと

- Fable/Opusの新guideはsigned thinkingと過去messageの保持を要求する。履歴の書換えを共通のcontext圧縮処理として入れない
- Qwen3.5のmodel cardは過去turnのthinkingを履歴から除く方針。Claudeのhistory方針をそのまま流用しない
- Gemini 3.8のmigration guideはsampling parameterを外す指示を持つ。古いGeminiのtemperature推奨を3.8へコピーしない。[最新guide](https://ai.google.dev/gemini-api/docs/latest-model)
- GLM-5.3はthinkingをdisabledにできない。低latencyをpromptだけで実現したと扱わない
- Kimiのthinking/instantとhosted/localのparameterは異なる。MiniMaxもnative parserとsamplingは文章上の指示から分離する
- OpenAIのlatest-modelページには旧modelに言及する節が残る。GPT-5.xの設定をGPT-6へ自動で移さない

compilerはAPI parameter・effort・temperatureを自動変更しない。理由とadapterへの注意を`runtime_notes`に残す。

## OSSから確認した構成

[OpenCodeのmaintainer実装](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/session/system.ts)にはmodelごとのprompt dispatchがある。モデル差分を独立資産へ分ける根拠になる。ただし部分一致でmodel familyを選ぶ処理を今回のcompilerへは採用しない。未知の新modelはfail closedとする。

[Piのmaintainer実装](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/src/core/system-prompt.ts)はprompt sectionsとproject contextを構成する。今回もlayerごとのdigestを記録する。どちらもmutable branchの観察であり特定commitに対するruntime互換性の保証ではない。コードや巨大prompt本文はコピーしていない。

[Anthropicのcontext engineering記事](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)はtaskに必要なcontextの選別を重視する。skill一覧を増やすことや常時全文を読ませることを最適化と見なさない。

## X・Reddit・技術ブログの扱い

[Sonnet 5.5のCLAUDE.mdについてのReddit投稿](https://www.reddit.com/r/ClaudeAI/comments/1wspcmd/claudemd_for_sonnet_55_based_on_anthropics/)は高effortでのscope拡大を問題にしている。scope制御は公式guideで裏付けて採用した。投稿のcost削減率はこの環境の実測にはしない。

[Grok 4.7のtask単位costを疑問視するReddit投稿](https://www.reddit.com/r/cursor/comments/1wp9mhm/uh_is_grok_47_really_6x_more_expensive_and_8x/)は価格表よりtokens/latencyも評価すべきという仮説の入口。速度倍率・cost倍率をruntime policyへ採用していない。

[Simon Willisonの2026-09-29の記録](https://simonwillison.net/2026/Sep/29/)はreleaseと実artifactの観察。短い例での成功をすべての開発taskへ一般化しない。

[Boris ChernyのX thread](https://x.com/bcherny/status/2007179832300581177)を関連referenceから特定したが組み込みWebでの直接本文の取得は失敗した。独立したheadless ChromeでもHTTP response errorとなった。X検索ではindexed summaryとsecondary referenceまで確認した。本人の発言として断定したruleは採用していない。X本文の詳細検証は未完了であり研究済みと見なさない。Grokへの調査委譲はCodexのsingle-agent方針により実行していない。

[Claudeの公式system prompt index](https://platform.claude.com/docs/en/release-notes/system-prompts/overview)も確認した。consumer appのpromptとAPI/native coding runtimeのinstructionを同じものとして配布しない。

## 差し込みと版管理

- APIではtrusted instructionとuser task/source contextを分ける
- Codexでは既存`developer_instructions`へ追加する。[公式config reference](https://developers.openai.com/codex/config-reference)
- Claude Codeではappend flagを使う。[公式CLI reference](https://code.claude.com/docs/en/cli-reference)
- native runtimeでは共有/project instructionをcompilerへ再入力しない
- 既存addendumを渡した場合は出力へ保持する。渡していない場合はadapterでmergeする
- runtimeのdefault promptを置換するflagを生成しない
- account/modelのdefault・権限・toolsを変更しない
- releaseは`2026-10-02.1`。全profileのbehavior validationは`not_run`
- reviewed model IDを明示して選ぶ。retirementやalias更新は再調査と新releaseで扱う

Claude Code 2.1.287とCodex 0.160.0のCLI helpを観測した。新sessionでのprovider応答・Orcaがnative起動へ渡す経路は未検証。特にClaudeはresume時に以前のsystem prompt snapshotを使う場合がある。model/profile変更は新sessionまたはruntimeの正式なrefresh操作で適用し途中で黙って変えない。

## 検証と昇格条件

compilerのoffline検証はmodel mapping・出典の存在・未知model拒否・source contextのchannel分離・digest再現性・native既存instruction保持を確認する。これはモデルの品質評価ではない。

behavior評価では同じtoolsとfixture taskでnative baselineとaddendumを比較する。fixtureはread-only review・bounded code change・tool failure・許可のない外部効果・source内の偽instruction・途中報告後の未完了task・unknown outcome・必要なJSON fieldsを含める。記録する指標はtask成功・必須情報欠落・目的外変更・tokens・latency・cost。品質を落としてtokensが減った候補を昇格させない。最低限の代表taskを複数回評価しbaselineより悪化しないことを確認して新releaseを出す。

## 利用

```sh
bun agents/scripts/model-profile.ts list
bun agents/scripts/model-profile.ts render --provider openai --model gpt-6-astra --runtime codex
bun agents/scripts/model-profile.ts render --provider anthropic --model claude-sonnet-5-5 --runtime claude --format text
```

Home Manager moduleは同じcompilerを`harness-model-profile`として配布する。生成結果はinstruction packageの材料。現在のOrca起動やglobal configへ自動注入する処理は実装していない。
