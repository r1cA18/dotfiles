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

## Real Orca synthetic destination acceptance

Core #74 signed head b64c2b86419e66323b46cf4d601a3447af6c961e connects source
capture/restoration with the actual 1.4.219 destination and the public dispatch
CLI. Mac full 469 tests and required gates passed. Linux fmt, 19 dispatch
regressions and the explicit native gate passed in an isolated amd64 container
under emulation. The candidate's exact synthetic dsh config-home binding,
staged/unstaged/untracked/binary inputs, result collection to Verifying, budget
settlement and replay were checked. No dsh/model inference or actual login.

The adoption guide now pins #74 and links the optional gate. Keep Mac native
startup, cross-host live-agent moves and real profile acceptance unverified.
This is a documentation-only follow-up. Use targeted Markdown/path validation;
the existing PR checks retain their normal scope without an added CI job.

Owner decision: continue implementation with synthetic group/profile/model
registrations in isolated test ledgers and empty account homes. Register real
identities and perform subscription acceptance together after implementation.
Real profile names are deferred adoption inputs, not an implementation blocker.

## Bound terminal stop acceptance

Core #75 signed head 5e001da412c144627127b2d417a40d7963623c79 binds observe/stop
to the recorded effect and terminal and reads the matching nested positive PTY
receipt from real Orca 1.4.219. Mac full 471 tests and required gates passed.
Linux's 39 related regressions and both opt-in real-runtime gates passed together
in 70.319 seconds. The synthetic parent and child stopped, heartbeats stayed
stable and the terminal was no longer observed as running. Read-only readiness
probe timeouts recovered within the existing bound; the private display survives
short-lived clients. No detached-process or remote-loss guarantee is inferred.

The guide pins this cumulative candidate. Core's individual stop CLI, hard
deadlines and real-agent acceptance remain separate. Registration stays deferred
to joint adoption; no runtime, login, Skill, service or mandatory CI job changed.
Validate this prose with the existing Markdown and path checks.

## Individual stop and successor Attempts

Owner chose a new Attempt for continuation after confirmed termination, keeping
the Task. Core #76 signed head fe29687c27223af4c50d2046b59b1334394b5a23 adds
durable stop intent/observation, per-Attempt run/poll/stop exclusion and a JSON CLI.
Unconfirmed/lost receipts retain OutcomeUnknown, the budget hold and successor
refusal. Stop does not depend on renewed start admission. Replay does not close
again; confirmed stop recovers unknown-usage settlement after a successor.

Mac all 484 tests, fmt, warnings-denied Clippy, generated OpenAPI comparison and
fixed-commit fixture verify passed. Linux's 108 related regressions passed. The
actual Orca 1.4.219 gate passed in 58.583 seconds under isolated amd64 emulation,
including the new CLI stop, parent/child exit, saved files, settlement, replay and
successor creation. A split Xvfb display-number pipe startup race was reproduced
and fixed in the manual runner. No login/model, runtime activation or service
change. Hosted full/joint/TLS results are on the PR. The guide pins #76; automatic
successor dispatch, hard deadlines and cross-host live-agent acceptance remain
separate. Real registration stays deferred to joint adoption.

## Bound capture after confirmed stop

Core #77 signed head a57f88af575a1c28424cfc0e329094ee3087f419 adds the JSON
service/CLI `dispatch capture`. Its private receipt binds portable work to the
closed Task/Attempt, execute effect, confirmed stop request and immutable plan.
Exact replay verifies the artifact without rereading the source or closing another
terminal. Unknown/manual-only cancellation, foreign plans, unrelated inputs and
incomplete/corrupt claims are refused. Runtime/profile selection stays advisory;
no successor launch authority or new source lease is introduced.

Mac full 493 tests, fmt, warnings-denied Clippy and generated OpenAPI comparison
passed. Linux's 117 related regressions and final 18 relevant regressions passed.
The final real Orca 1.4.219 manual gate passed in 91.968 seconds under isolated
amd64 emulation: actual CLI stop, bound capture, saved-work restoration, a new
Attempt of the same Task and replay. No actual model/account or service change.
The runner stopped its owned processes and private containers exited. Hosted
full/joint/TLS and fixed-commit fixture evidence remain on the implementation PR.

The adoption guide pins #77 and consolidates the current evidence; this progress
record retains earlier results. Full one-operation handoff, hard deadlines and
cross-host live-agent acceptance remain separate. Real registration stays deferred
to joint adoption. This follow-up changes documentation only.

## Guarded successor creation

Core #78 signed head 6e9ae252e381f5aa1ed115056cc16faa83a73338 adds
`attempt create --predecessor`. The Task transaction compares the expected
latest closed predecessor before creating its successor. A stale controller
cannot silently attach to a different Attempt. Exact replay returns its recorded
successor after later work; a changed predecessor conflicts. Existing creation
policy, current signed Contract approval and Attempt budgets remain in force.

Mac all 499 tests, fmt, warnings-denied Clippy, OpenAPI comparison and fixed-commit
fixture verification passed. Linux's 83 related regressions passed. The official
Orca 1.4.219 gate passed in 117.809 seconds under isolated amd64 Linux emulation:
confirmed parent/child stop, bound capture, dirty-work restoration, guarded
successor and replay. Owned server/display and disposable container exited.
No actual account/model or service change. Hosted full/joint/TLS evidence is on
the implementation PR. The guide pins #78 and explains the precondition.

No automatic transport, new execution authority or daemon is introduced.
One-operation handoff, hard deadlines and cross-host live-agent acceptance remain
separate. Real registration stays deferred to joint adoption. This follow-up
changes documentation only.

## Shared Skill resume integration follow-up

The adoption guide now pins dotfiles #32 at
`da95d3d3ef9832dd19d74be1d288c429c60e6654` and Core #78 at
`9c1e54abe157570bdba9290f00957f7b6b0d268d`. The shared Skill distinguishes
Core-managed individual stop/bound capture from standalone workspace closure.
It takes the predecessor from the capture receipt and refuses automatic ID
replacement, unknown termination and unsupported remote dispatch. Controller
ledgers remain on the trusted host.

Correct the documented order to restore, prepare/approve the destination
Contract, create the guarded same-Task successor and dispatch. Attempts bind
at creation; a later Contract approval cannot rebind one. The Core follow-up
changes documentation only and passed required local fmt, all-target Clippy
and all 499 tests. Its 120 recorded implementation inputs are unchanged.

The Skill change passed 21 targeted Mac tests, including the three opt-in pinned
dsh synthetic tests. The existing model/tool test now asserts explicit shared
slash-Skill body expansion without adding a test process or CI job. Separate
actual-harness and ordinary-prompt probes distinguish explicit expansion from
metadata-only loading. Autonomous agent discovery, real accounts and live
cross-host handoff remain unverified. Detailed evidence is pinned from the guide.

This adoption-doc follow-up changes no runtime, Skill, Nix or service. Validate
formatting, existing path checks, pinned links/anchors and local references.
Published-head CI results will be recorded in the PR body. No merge or activation.

## Approved successor dispatch controller follow-up

Update the adoption sequence to use `dispatch resume` after explicit restored
input verification and current destination Contract approval. The new service
composes guarded creation, readiness, start and dispatch. A bare `attempt create`
does not prepare a worker for `dispatch run`. Stable request IDs recover known
preparation failures and never reopen closed or unknown work.

Document the existing conservative budget rule: settled unknown source usage
blocks new reservations in that window regardless of nominal capacity. Native
usage collection and settlement remain work; synthetic success uses explicitly
known fixture usage. Do not turn missing usage into zero. The guide now pins Core #79 at
`a92f86c24748452182a51db35fdd38494290b40f` and dotfiles #32 at
`c027bad993f4d27f2bbdc77666b20dae155bd5f7`.

Core passed all 509 Mac tests, fmt, warnings-denied all-target Clippy, OpenAPI
comparison and fixed-commit fixture verification with unchanged source tree and
no reused evidence. Linux passed 93 related regressions. Official Orca 1.4.219
passed the final unchanged-timeout native gate in 246.145 seconds: parent/child
stop, bound capture, dirty restore, destination approval, same-Task successor
dispatch, completion collection and replay without another launch. The runner
retains partial stop-test output on timeout. An earlier native timeout is not
counted as a pass. The synthetic worker declares known zero model usage and
invokes no model. Owned processes and disposable containers exited.

The updated Skill passed 18 related Mac tests with 74 assertions. Published-head
Linux checks all passed: 121 default tests with three native skips and a separate
three-test pinned native gate. Explicit synthetic slash-Skill expansion and the
ordinary metadata-only control are measured; autonomous discovery and live
handoff remain unverified. No new daemon, mandatory CI job, runtime activation
or service change. Hosted Core results and this documentation-only follow-up
remain recorded on their PRs. Real registration stays deferred to joint adoption.
