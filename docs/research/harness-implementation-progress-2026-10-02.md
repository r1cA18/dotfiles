---
title: Harness実装と統合の進捗
created: 2026-10-02
type: research
tags: [harness, integration, progress]
---

# Harness implementation progress

## Objective

Address the cross-repository review findings and prepare researched, versioned model instruction profiles. Continue the approved Harness implementation in reviewable pull requests. Account/profile distribution remains a separate change from session management.

## Acceptance criteria

- Concurrent Times requests cannot apply the same mutation twice; changed payloads cannot reuse an old receipt silently
- Olympus instructions have one current architecture and distinguish rebuildable views from operational state
- Account launchers retain distinct Orca account identities even when emails match
- Model profiles have dated primary evidence, exact model selection, prompt composition, and reproducible tests
- API contract metadata distinguishes implemented services from unavailable transports
- Each change has local verification and a separate delivery record; no unrelated working changes are included

## Baseline and decisions

- Core operation/canonical branch: 13 tests passed
- Olympus Times/Schedule routes: 9 tests passed, but a separate concurrent duplicate-request reproduction persisted both writes and returned one receipt UNIQUE error
- A fresh vault also exposed a temporary-file name collision during concurrent config initialization
- Same-email Orca accounts are collapsed by the current ccspace helper; use immutable account ID instead
- Model-specific instruction compilation is a later extension in the Core architecture. Prepare an explicit opt-in compiler and profiles; retain native runtime prompts and the shared/project instruction hierarchy
- Main checkouts contain unrelated changes. Use isolated temporary clones for Olympus/Core work and preserve the original files

## Delivered units

- [dotfiles #14](https://github.com/r1cA18/dotfiles/pull/14): 16 model profile candidates and opt-in compiler; five tests passed and packaged Nix list/render passed
- [dotfiles #15](https://github.com/r1cA18/dotfiles/pull/15): account identity and picker; two regression tests passed and both Nix helper builds passed
- [Olympus #3](https://github.com/r1cA18/olympus/pull/3): durable mutation reservation and atomic writes; 386 tests and all six workspace typechecks passed
- [Core #34](https://github.com/r1cA18/harness-core/pull/34): transport metadata and staged integration ownership; 14 integration tests, formatting, and Clippy passed

- [Core #35](https://github.com/r1cA18/harness-core/pull/35): verified operator/Workspace ledger storage, writer exclusion, atomic event persistence and blob store; all 24 integration tests, formatting, and Clippy passed

Both dotfiles PRs passed all GitHub CI checks. Olympus/Core had no reported remote checks; their checks above are local. All five PR clones are clean after signed commits and push. PRs are open. No merge, deployment, live credential distribution, native agent invocation, or model-quality evaluation was performed. X full-content retrieval failed through both built-in Web and an isolated browser.

## Delivery and integration

Core dependency order is #31 -> #32 -> #34 -> #35. Ledger storage is now executable; it does not provide Contract/Attempt state transitions or authentication. Whole-tail deletion still needs an independently trusted chain-head anchor.

Olympus schema v17 deliberately avoids the separate pending v16 migration. Integrate that migration before a combined deployment. The supported vault topology remains one gateway writer; unknown file/receipt outcomes require explicit reconciliation.

Account launchers register host-local profiles only. Control Host distribution remains separate from Orca session ownership. Model profiles remain opt-in candidates with behavior_validation=not_run; no performance or cost claim is established.

Original checkouts' unrelated working changes were preserved. No merge or deployment was performed.

## Remaining

Task Contract/Attempt lifecycle; account groups and budget reservation; calendar dispatch and wait/resume; trusted verification/review/human approval; profile distribution; Orca profile injection and model-quality evaluation; Life OS UI. Existing ownership decisions do not claim these execution paths are complete.

## Next implementation unit

Follow the Core foundation sequence: #12 repository verification profiles and #13 Account Groups. Then bind Contract/Attempt lifecycle to the ledger and reserve usage per group before dispatch. Calendar-triggered waiting/resume must use the same policy path; no second dispatcher may execute an occurrence.

## Follow-up review and Orca diagnosis: 2026-10-04

The checked delivery PRs remain open. Foundation verification is not end-to-end execution or daily-life readiness. Integrate the migrations and test one complete policy/Attempt/execution/evidence path before claiming operational completion.

Installed Orca 1.4.219 rejects divergent SQLite and legacy JSON profile state. The existing dotfiles orcaSettings activation directly patches legacy JSON without updating SQLite authority. Its retained Nix backup timestamp matches the JSON save timestamp reported in the conflict dialog (2026-10-02 13:35:36), making the activation a strong cause candidate; no exclusive cause or older-version usage is proven. Current profile state was not rolled back or altered by this investigation. Remove the direct JSON writer or replace it with a version-verified supported settings operation in a separate change. The five delivered PRs do not directly patch Orca legacy profile JSON.

## Phase implementation authorization: 2026-10-04

The owner explicitly changed this session to phase Issue -> implementation PR -> independent non-author subagent review -> repair -> merge. Native delegation is authorized for this work without changing global Codex defaults. Reviewed dotfiles #14 and #15 and Core #31, #32, #34 were merged at the reviewed heads. Orca SQLite was selected by the owner; dotfiles #17 removes the unsupported legacy JSON activation writer and passed independent review plus all remote checks before merge. Home Manager activation remains unapplied.

Core #35 review found dangling managed symlinks accepted as absence. Repair and fresh independent review precede its merge. Olympus #3 includes a previously unpublished large parent baseline; publish/review that parent separately and retarget the hardening PR rather than silently merging broad changes. The pending v16 reviews migration must be presence-checked after v17 before combined deployment.

The deleted desklab environment has no references in the clean dotfiles repository. Do not guess that another host alias represents it. New cloud environment management belongs in Core's operator registry; resource registration/retirement is distinct from cloud provisioning/destruction. Separate private Web UI and CLI repositories will consume versioned API/event endpoints. Core has no knowledge of its subscribers.

No production deployment, paid provisioning, destructive cloud operation, or public publication has been performed. Existing dirty checkouts remain preserved.

## Phase delivery continued: 2026-10-04 (Claude Code session)

Merged after independent review: Core #38 (verification, two review rounds), Core #39 (SSH authority + operator transaction, two rounds, Linux CI green), Olympus #3 then #5 (mutation receipts, schema v18 with presence-guarded reviews column; owner's local uncommitted v16 change must drop its own SCHEMA_VERSION=16 when rebased). Core #30 closed as stale; its CI fact moved into #39.

Process error: Core #38 was merged while its Linux CI was red because the wait and merge commands were chained. The failure was a pre-existing flock inheritance flake fixed by #39's explicit unlock; main CI is green after #39.

In flight: Core #13 Account Groups (approval-gated mutations), Core #37 repair (lock-free reads, `stream.caught_up {head}`, Problem-typed retryable errors, WhoIs cache, limits, exit-code alignment), harness-cli #2 and harness-web #2 (read-only clients, review rounds ongoing).

Remaining after these: #36 environments (registration/retirement only) and client add/remove UI, MVP chain #3 -> #4 -> #5 -> #6 -> #7 -> #8, #33 budgets and wait queue, #29 schedules, #22 router, #27 Olympus integration, profile distribution, model profile injection.

## Milestone: 2026-10-04 17:05

Merged after independent review: Core #37 (lock-free reads, SSE with `stream.caught_up`, URI Problem types), #44 (trusted Unix-socket ingress, self-node refusal), #46 (HTTP approval routes, part of #45); harness-cli #2 and #4; harness-web #2, #4 and #5.

In review/repair: Core #40 Account Groups and #41 environments (gate-time signature verification, registry trust root), #43 Task Contract (registry trust root P2), #47 Attempt log (evidence-less verify P2), #48 capability ports (re-review), #49 Orca/ccspace adapters (first review). In implementation: Core #5 execution, #6 verification evidence, #33 budgets (paused behind #40/#41), #50 follow-ups; harness-cli #5 approval flow.

Recurring review finding: stored approvals trusted on read. Shared brief rule now requires gate-time binding and signature re-verification, mutation testing, and a signer registry trust root (`signers.pinned` + `approval.consumed` with registry digest).

## Milestone: 2026-10-04 20:05

Merged since 17:05: Core #48 (capability ports; coordinator resolved main conflicts, independently checked), #54 (ingress/approval follow-ups, verify-time history verification), harness-cli #6 #7 #8 (approval inspect/sign/submit, output escaping, contract refresh), harness-web #7 #8 #9 (approvals view), Olympus #7 #8 #9 (read-only Harness status view and contract refresh).

Coordinator decision: the signer trust root is the protected live `approvers/allowed_signers`; retired keys stay with `valid-before`; history is re-verified with `ssh-keygen -O verify-time=<UTC>Z`. Ledger-stored registry snapshots are informational. This supersedes the earlier `signers.pinned` rule. A missing `Z` in #40 made verify-time local time (fixed in branches).

Incident: #49/#51 test fixtures leaked orphaned fake-orca worker shells (owner-reported loop, 184 processes). They were killed and a temporary reaper ran for 1h (no leaks after 19:27); a process-hygiene rule was added; the fixture fix is in progress. All subagents hit the spend limit at 19:33 and were resumed after the 19:50 reset.

Open security findings in repair: #52 `git replace`/grafts can bind evidence of other content to a head (main's `harness verify` is being checked too); #53 expired-unsettled holds released budget; #51 resume skipped the approval re-check and an unknown start could be retried.

Remaining: merge chains #40 -> #41 -> #53 -> #56, #43 -> #47 -> #52 -> #55, #49 -> #51; then #16, #29, #8 (real repository end to end), client environment/group/budget views, profile distribution, and model profile injection.

## Single-agent resumption: 2026-10-05

Resumed the interrupted integration without spawning agents or restarting broad mutation loops. Rechecked current PR heads and existing review findings. Core #40 was repaired/reviewed locally, aligned with main, and merged only after fmt, Clippy, full tests, OpenAPI equality, and both remote checks succeeded. #41 was reviewed and aligned with #40; its local gates and final remote checks passed. #53 review found an additional trust gap: BudgetService rebuilt Account Groups without checking their stored signatures. A fixture replaces a group signature with a stranger signature while keeping the canonical ledger chain coherent; the old budget service accepts it. The repair re-verifies group history before budget projection; the regression rejects reads, reserve, and resume. The integrated budget branch passed 238 tests. #56 HTTP registry integration preserves its server-resolved SSH verifier and passed 245 tests with OpenAPI consistency. Content-identical merge commits align the stack without repeat local tests. The fake-worker residual count after the suites was zero. Production deployment and the Task/Attempt execution chain remain unverified. The prior full-tail/backdated-history caveats are still limitations; timestamp consistency does not provide an independent trusted time anchor.

## Foundation integration completed: 2026-10-05

Merged Core #40 (Account Groups), #41 (environment registry), #53 (budget and queue), and #56 (HTTP registry routes) after local gates and both remote fixture checks passed at each exact final head. Found and reproduced an additional budget-consumer gap: a coherent operator ledger with a forged stored group signature was accepted. Budget projection now verifies Group authority through the shared HistoryVerifier; regression coverage includes reserve and queue consumers. Foundation integration passed 245 tests.

Task chain integration continues: #43 passed 281 tests; #47 passed 301 after timestamp-consistent forged-stream fixtures; #52 is being integrated with the latest foundation. No native agent launch, production deployment, or resource provisioning was performed. Original dirty checkouts are preserved.

## MVP chain integrated: 2026-10-05

Merged #43 (Contract), #47 (Attempt log), #52 (fixed-snapshot Evidence), #51 (Manual/Local execution), and #55 (bounded review and Human Gate), each after both final-head CI fixtures succeeded. Integration preserved both Local launch fields and verifier head bindings; historical outcome approval verification now uses the common consumed-approval API. A repeatedly flaky one-second HTTP assertion was replaced with direct connection-state validation.

The combined Workspace integration (#58) passed 358 Rust tests locally. PR #59 adds the reproducible CLI validation script and report. An actual Core commit reached signed succeeded with isolated test authority; restart recovery and known failed versus outcome_unknown distinctions passed. Owner credentials and human review timing were not used or measured. The committed smoke Evidence is distinguished from the separate full Rust gate. Issue #8 remains open for its remaining real-owner measurement criteria. Fixture orphan-process count after all local runs: zero.

## Resumption complete: 2026-10-05

Owner selected existing PR integration plus the local MVP exercise as this resumption scope. All ten remaining Core PRs (#40, #41, #43, #47, #51, #52, #53, #55, #56, #58) and new validation PR #59 are merged. Every final head had both fixture checks successful before merge. Main at 4dd4beb has exactly the verified validation branch tree. Core, harness-cli, harness-web and Olympus have no open PRs at the final check.

Reproduction and limits are committed in Core docs/mvp-validation.md and scripts/validate-mvp.py. Local integrated tests: 358 passed; CLI exercise: recovery/unknown, known failure and signed success passed; no orphan fixture processes. Issue #8 intentionally remains open for actual owner review-time/usage measurements. Future schedules, routing, client mutations, model injection, gateway and learning-loop work is outside the scope selected for this resumption. Original local dirty checkouts were preserved.

## GitHub management and research: 2026-10-05

Owner requested separate management of Harness verification/environment work and small unrelated desktop fixes. Latest published dotfiles main already contains model-profile delivery #14 and account-identity delivery #15; these are retained rather than duplicated or downgraded. Original dirty checkouts remain unchanged except for the installer bug repair and newly written research notes.

Small main-bound changes: Aerospace shortcuts, Darwin server fonts and native installer dependencies. The Devin installer stdin redirection discarded the piped script; the repair downloads to a temporary file before executing it with closed interactive stdin. Main-only regression suite passed 62 tests with 4 Nix-only skips using a 15-second timeout; the default five-second suite timed out on existing workspace tests. Selected Nix formatting/deadnix and program-directory statix passed. Full system evaluation did not complete and activation was not performed.

A separate feature branch holds the pending flake refactor/lock update, homelab runtime, server management and model-default changes. It is an environment-management draft, not a statement that remote execution is ready. Remote workspace provisioning and Mac-independent session reconnect are not implemented end to end. Linux account paths remain a concrete gap.

Research notes: olympus-harness-integration-2026-10-05.md and remote-development-readiness-2026-10-05.md. Code inspection used Olympus published main rather than its separate uncommitted work. Core Contract/Attempt services are implemented locally but their HTTP transports are still planned. Completion-driven Inbox, source-ID mapping and Schedule ownership need follow-up. UI rendering, live Core connection and owner-key validation remain unverified.
