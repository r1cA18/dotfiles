# Research Playbook

## Research Questions

最初に次を仮説として書く。

- 誰のどの状況を改善するか。
- 現在は何で代替しているか。
- 既存解決策が失敗する理由は何か。
- 今作る技術的または市場的な理由は何か。
- 成功を何で観測するか。

## Source Routing

全sourceを機械的に検索せず、作るものに合う一次情報を優先する。

| 対象 | 優先source |
| --- | --- |
| developer tool、library、CLI | official docs、GitHub、issues、releases、HN、Reddit |
| SaaS、consumer product | official product、pricing、reviews、Reddit、X、Product Hunt |
| startup idea、market gap | YC companies、Launch HN、Product Hunt、founder posts、X |
| workflow automation | official integrations、GitHub、community forums、Reddit |
| regulated domain | official regulation、standards、vendor security docs |
| fast-moving trend | dated official announcements、X、GitHub activity、recent discussions |

X調査では利用可能なら`x-research`を使う。Web pageの操作や取得には環境で指定されたbrowser skillを使う。

## Coverage

可能なら次を満たすまで探索する。

- direct competitorを3件以上
- adjacent solutionまたはmanual workaroundを2件以上
- OSS building blockを1件以上
- user complaintまたはswitching reasonを3件以上
- pricing、license、activity、integration surfaceの確認

候補が少ない市場では件数を捏造せず、検索queryと見つからなかった範囲を記録する。

## Evidence Rules

1. 価格、version、利用規約、API availabilityには日付を付ける。
2. 公式claimとuser reportを分ける。
3. snippetだけで判断せず元pageを開く。
4. XやRedditの単発投稿を市場全体の事実として扱わない。
5. GitHub starsだけで採用を決めず、recent release、issue response、bus factor、licenseを見る。
6. source URLと取得日を残す。
7. 推論は事実と分離し、「この証拠からの推論」と明示する。

## Comparison Matrix

各候補を同じ軸で比較する。

| Axis | Questions |
| --- | --- |
| Problem fit | primary use caseを本当に解くか |
| Integration | local environmentへ自然に入るか |
| Extensibility | 必要な差分を小さく実装できるか |
| Reliability | maintenanceとproduction実績は十分か |
| Security | credential、data、supply chain riskは何か |
| Cost | 初期、継続、migration costはいくらか |
| Lock-in | 撤退、export、置換は可能か |
| Differentiation | そのまま採用すると独自価値を失わないか |

## Decision

調査後は必ず次の4案を比較する。

1. 既存solutionをそのまま使う。
2. 既存solutionをlocal environmentへ統合する。
3. OSSをforkまたはextendする。
4. 新規実装する。

「作りたいから作る」を結論にしない。採用、統合、新規実装のどれがGoalを最短かつ安全に満たすかで決める。

## Stop Rule

追加検索で新しいcompetitor、decision axis、重大riskが2巡続けて増えなければsaturationとみなし、実装判断へ進む。重大な矛盾が残る場合は質問または小さなprototypeで解消する。
