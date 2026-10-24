# Native profile bindings

## Objective

Use one portable profile catalog for explicitly selected native Codex/Claude
logins and existing gateway routes. Keep config-home paths and host-scoped Core
account IDs in private device bindings. Preserve runtime, model, group and
logical account intent across devices without copying credentials.

## Design

- Extend the connection transport with an explicit native variant; retain the
  existing gateway format and its subscription restrictions.
- Resolve native config-home references without reading credential contents.
- Use existing read-only Core account/environment operations to check an
  explicit device binding. Core dispatch remains the authority for execution.
- Do not infer login validity from a directory, create accounts, assign groups,
  pick fallback accounts or launch a worker during doctor/resolve operations.
- Native runs use the selected existing config home. Gateway runs retain their
  private generated homes. The operator chooses every runtime and exact model.

## Verification plan

Baseline gateway/profile/runtime tests, transport/provider/runtime matrix,
cross-device resolution, binding mismatch/revocation and invalid-input cases,
CLI read-only behavior and synthetic native commands. Follow with the real Core
CLI over a signed synthetic registry. No subscription inference or activation.

Installed CLI help was observed in disposable homes: Codex 0.163.0 supports
`exec --json --model`; Claude Code 2.1.310 supports `--print --model`. No model
was run. Real account/model acceptance remains pending owner selection.

## State

Implemented above dotfiles #29; Core dispatch #67 is the integration target.
The legacy gateway format remains accepted and subscription gateway restrictions
remain enforced. New native examples contain synthetic references only.

## Completed checks

- Eleven Bun regressions passed with 84 assertions using fake native commands.
  These cover both providers, cross-device identity, JSON roundtrips, the finite
  runtime/provider capability matrix, literal task/model arguments, private
  version probes, retained config-home contents, startup refusal, registry
  identity/revocation and read failures.
- The real Core CLI resolved a signed synthetic registry through the actual Bun
  CLI. The operator-ledger record count remained unchanged and no Orca worker
  was created. A signed account unassignment was rejected on the next read.
- A first real-Core test failed because its test Bun executable path did not
  exist. Using the observed Nix executable fixed the harness; no product check
  was relaxed.
- Full pinned-tool Mac suite passed: 121 tests, 3 native-binary skips and zero
  failures across 17 files. Native dsh checks, Nix checks and Core full gates
  remain in progress. Linux CI has not yet run for this increment.

## Review and remaining work

Local review preserves transport-specific capabilities and avoids a second
policy authority. Native model capacity fields are metadata, not applied limits.
Doctor normalizes lexical paths but does not attest symlink identity or login.
Existing native config is trusted and may include hooks/provider settings.
The wrapper does not alter the selected home, but the native product may do so.

The result of resolve-core is advisory plan input, not a full signed DispatchPlan.
No credential reading/distribution, provider inference, native resume, host
selection, production activation or UI is implemented in this increment.
The current homelab probe failed DNS resolution before authentication. Native
subscription inference remains pending explicit group/profile/model values.

Next: finish full gates, publish signed scoped PRs and run the pinned resolver
against Core in Linux CI. Continue controller orchestration and Publisher fencing
separately; this increment does not complete the whole harness foundation.

## Published verification and adoption handoff

Signed dotfiles #30 head 4f5bf88a7dcff760c5fc57d64d8ee6cea11200e9 passed
Mac/Linux full 121-pass/3-skip suites, Nix checks and the separate three native
dsh synthetic endpoint checks. Core #68 passed 416 tests and the pinned joint
gate. Later Core #71 passed all 444 Mac/Linux tests and joint verification.
Core #72 signed head 106215d71d65a3d1442374e8e4d11f1ca30d2f2f adds buffered
Gateway proxy admission; its Mac full 457 tests and actual CLI/curl/TLS synthetic
gate passed. Linux results remain in that PR's checks and body.

The adoption guide pins both repository candidates, distinguishes component
implementation from live-agent workflows and links each operation's existing
runbook. Corrected historical handoff-guide statements about dispatch/Publisher
and homelab reachability. This documentation increment changes no runtime, Skill,
Nix configuration, login or service. Validate Markdown formatting, local/pinned
links and the evidence counts; do not rerun unrelated runtime suites for prose.

The first documentation CI rejected four Core script names written as inline
relative paths in the dotfiles guide. Replaced them with pinned Core links;
kept the existing path checker unchanged and reran it locally. No runtime or
configuration correction was needed.

## Attempt-scoped Gateway candidate

Core #72 Linux CI 40060286426 passed full, pinned joint and synthetic TLS gates.
Core #73 signed head 4f6755f56c230cd50fb19ff571a963ddc8194bf5 adds optional
Task/Attempt/Contract-bound grants with live lifecycle and approval checks.
Mac full 469 tests, fmt, warnings-denied Clippy, OpenAPI comparison, committed
fixture verification and the separate actual CLI/curl/TLS synthetic gate passed.
Linux full/joint/TLS CI 40062334641 passed all 469 tests on clean checkout
6561996abaedd3b5d768d650e02dc93842a825bb. Mac and Linux source tree both match
e956afab6a14b24b71fdeaa74ec4bb8fe3b9950b. The adoption guide now pins
this cumulative candidate and distinguishes issuance from dispatch-time token
delivery. No runtime configuration, account, Skill or service was changed.
