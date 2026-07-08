# Nix Modernization — ryoppippi dotfiles 参考の再構築計画

ryoppippi の dotfiles を参考に自分の Nix 構成を近代化するための
調査結果と方針の記録。旧ブランチ "codex/nix-modernize" から main に吸収した。

> 出典: Claude Code セッション `260be7c3`（2026-06-02）の比較調査。
> 進捗 (2026-07-04 時点):
>
> - 実装済み: treefmt + git-hooks (deadnix / statix) の flake checks 組込
> - 実装済み: Neovim の ryoppippi 式ハイブリッド化（`docs/guides/neovim.md` 参照）
> - 未実装（提案のまま）: flake-parts 化・nix modules 再編・`nix run .#switch`。
>   大規模リファクタのため、着手時は Plan mode で段階分割してから進める

参考リポジトリ: `~/Develop/github.com/ryoppippi/dotfiles`（ローカルクローン）

---

## 背景・目的

- ryoppippi の dotfiles が「flake = ハブ」設計で、外部リポを全部 flake input として
  declarative に取り込む構成になっている。これを参考に自分の構成を近代化したい。
- ただし全部真似ると依存ツールが増えるので、「自分の運用に取り込める部分」を選別する。
- 自分の現状は「ローカル skill 中心 + Anthropic 公式 skills を flake input」の中間。

---

## 構造の比較

| 項目                 | ryoppippi                                                                                                  | 自分（現状）                                     |
| -------------------- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| flake モジュール構造 | `nix/modules/{home,darwin,linux,lib}` で完全分離                                                           | `nix/{home-manager,darwin,overlays,pkgs}` 平置き |
| flake-parts          | 使用（`perSystem` で `apps`/`devShells` 分離）                                                             | 未使用（手書き `forAllSystems`）                 |
| `nix run .#switch`   | flake app として定義済み                                                                                   | 外部の `nh` コマンドに依存                       |
| treefmt / git-hooks  | flake-module 組込（pre-commit で treefmt + deadnix + statix）                                              | 導入済み（`flake.nix` の checks + devShell）     |
| シェル               | fish（function 30 / config 9）                                                                             | zsh                                              |
| AI tool 取得         | `numtide/llm-agents.nix` overlay で codex/opencode/cursor-agent/copilot-cli/coderabbit-cli を全部 nix 管理 | claude-code + codex のみ                         |
| nix-claude-code      | 自作の `ryoppippi/nix-claude-code` overlay                                                                 | 無し                                             |
| Cachix               | 4 種設定済（自前 cache 含む）                                                                              | 無し                                             |

---

## ryoppippi の skill 運用で秀逸な点

`agents/skills/` 配下に 20 個の Conventional Commit / TDD / Code review 系 skill。共通点:

- 全部 `description` に "when to use" を必ず書く（Anthropic best practices 準拠）
- 100–300 行で簡潔。長い例は `references/*.md` に切り出し
- `tdd` skill は runner 別に `vitest-example.md` / `rust-example.md` / `zig-example.md` を
  分離して progressive disclosure を実装

特に `commit` skill が強い:

- revertability first（hunk 単位で独立 revert 可能な粒度を強制）
- `git add -p` 禁止（Claude が interactive を扱えないため）→ `git apply --cached -v` で精密 stage
- PR 中の review fix は amend せず tiny commit で積む（squash merge 前提）

---

## 真似したい仕掛け（調査時点の評価）

1. **Codex review を PR 作成の前段に強制する hook**
   - `PreToolUse` for `gh pr create`: codex-review 未実行ならブロック
   - `PostToolUse` for Skill: codex-review 実行で `/tmp/.claude-codex-review-done` を touch
   - skill 実行を hook で track して依存 skill を強制起動できる。
2. **agent-skills-nix の外部 flake input 化**
   - ryoppippi は `ast-grep-skill` / `agent-browser-skill` / `tgrab-skill` を flake input で
     GitHub から pull → `transform` で nix-store の絶対パスにバイナリ書き換えして注入。
   - 自分はローカルのみ＋外部 skill 手動 clone なので差が大きい。
3. **`council` skill（並列 task agent）**
   - n=10 の subagent を並列起動して同一領域を別視点で掘らせる。ad-hoc な Explore より構造化。
4. **`ask-codex` / `codex-review`（cross-agent skill）**
   - Codex CLI を「セカンドオピニオン専用ツール」として skill 化。
   - 自分の `critical-advisor` agent は Claude 内で完結するので、Codex を呼べば真の独立性が出る（相補的）。
5. **`output-styles/ojosama.md`**
   - Claude Code の output style 機能（`/output-style`）の活用例。

---

## 真似しなくていい部分

- **flake input の量**: ryoppippi は inputs 20 個超で `nix flake update` が重い。自分の 4 個は妥当。
- **fish 移行**: zsh で困っていないなら価値薄。shell ハック自体が目的化している側面。
- **自前 cachix**: dotfiles で自前 cache を立てるのはオーバーキル。
- **`alwaysThinkingEnabled = true` + `effortLevel = "high"` + `skipDangerousModePermissionPrompt = true`**:
  コストが爆発する設定。彼は ccusage 作者で常時 monitoring しているから成立しているだけ。

---

## 自分にあって ryoppippi にない要素（守りの強さ）

- **hooks/ 7 個**（emoji-guard / ai-slop-guard / debug-print-guard / large-file-guard 等）
- **skills 21 個**（swift-dev-toolkit / video-editing / x-research など実務寄り）
- **agent-platforms.md / architecture.md でドキュメント化**
- **OS 分岐パターン**（`nixEnable = false` で会社マシン除外）

総括: 自分は「日常運用の守り」が強く、ryoppippi は「実験的 workflow を flake 経由でブン回す」のが強い。

---

## 優先順位テーブル（調査時点）

| 優先度 | 取り込む案                                                        | 工数  | テーマ      |
| ------ | ----------------------------------------------------------------- | ----- | ----------- |
| 高     | `commit` skill 移植（hunk-revertable + `git apply --cached`）     | 30min | claude 運用 |
| 高     | `codex-review` skill + PR 作成前ブロック hook                     | 1h    | claude 運用 |
| 中     | `council` skill（並列 subagent 起動）                             | 30min | claude 運用 |
| 中     | `tdd` の runner 別 reference 分離を `autonomous-dev` に取り込む   | 1h    | skill       |
| 中     | **flake-parts 化 + treefmt/git-hooks flake module**               | 半日  | nix 構成    |
| 低     | `numtide/llm-agents.nix` overlay で他 AI tool も nix 管理に寄せる | 1h    | nix 構成    |
| 低     | output-styles 機能で専用 style を作る                             | 30min | claude 運用 |

---

## 今後の方針（本心）

ユーザーの意図は「**nix を**ryoppippi 参考に構築し直す」。
nix 構成そのものに当たるのは以下で、これらは密結合のため一緒にやるのが筋:

### nix 構成の本丸（未着手分。着手時は専用ブランチを切る）

1. **flake-parts 化** — 手書き `forAllSystems` を `perSystem` に移行
2. **nix modules 構造へ再編** — `nix/{home-manager,darwin,...}` 平置き → `nix/{modules/home,modules/darwin,modules/linux,modules/lib}`
   （flake-parts 導入時に出力を modules へ切り出すのが自然なので 1 と同時にやる）
3. ~~treefmt + git-hooks~~ — 導入済み（flake checks + devShell の pre-commit）
4. **`nix run .#switch`** — 外部 `nh` 依存を減らし flake app として switch/build を定義（上記のついで）

### claude 運用系（nix とテーマが別）

- `commit` skill 移植（高 ROI）
- `codex-review` skill + PR 作成前ブロック hook（高 ROI）
- `council` skill
- output-styles 活用

### 進め方の注意

- 大規模リファクタなので、いきなり書かず **Plan mode で具体案を承認** してから着手する。
- 段階コミット（flake-parts 化 → modules 再編 → treefmt/git-hooks → switch app）で進め、
  各段階で `dr`（または `nix run .#switch`）がビルド通ることを確認する。
- modules 再編は import パスが大量に変わるので、`dr` が通る最小単位で刻む。

---

## 残タスクに着手するときの手順

```bash
git switch -c refactor/flake-parts main
# このドキュメントと ~/Develop/github.com/ryoppippi/dotfiles/flake.nix を読む
# Plan mode で flake-parts 化の具体案を作り、承認後に着手
```
