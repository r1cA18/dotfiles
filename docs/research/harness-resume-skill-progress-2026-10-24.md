# Guarded resume through the shared harness Skill

## Objective and boundaries

Connect the owner-approved same-Task/new-Attempt flow to the existing shared
`harness` Skill. Core #78 is the implemented CLI reference. Distinguish its
individual dispatch stop and bound capture from standalone workspace-wide Orca
capture. Preserve the Type 2 Skill plus existing reference structure and the
current Claude/Codex/dsh distribution. No new native command registry, daemon,
credential transfer, approval authority or production activation.

## Acceptance and state

The shared instructions must select the correct stop path, retain the capture
receipt's predecessor, require guarded creation support and stop on stale or
unknown state. Keep ledgers on the trusted controller. Verify command shapes
against the actual Core CLI, validate metadata and references, and check shared
asset loading where the pinned runtime supports an isolated synthetic test.

Implemented the two control paths in the existing Skill and checkpoint
reference. Retain the source Attempt from the bound receipt and require guarded
creation support in installed Core. Never substitute workspace-wide termination
for an individual dispatch stop or move controller ledgers onto a Worker.

Review found an incorrect ordering in the previous adoption runbook. Prepare
the destination plan and approve the current Contract before creating its
successor. Attempts bind at creation; later Contract changes deny start rather
than rebinding. The Core runbook correction is published in #78 at
`9c1e54abe157570bdba9290f00957f7b6b0d268d`. All 120 tracked code/test/artifact
inputs match the previously tested implementation. No runtime behavior changed
in that Core follow-up; local fmt, all-target warnings-denied Clippy and all 499
tests passed, with three native opt-in skips. Fixed-commit fixture verification
also passed with no source change or result reuse.

## Verification and review

Mac targeted Skill/runtime tests passed: 21 tests, zero failures, 86 assertions.
This includes the three opt-in native dsh tests, using the Nix-pinned
`0.2.1-rc.2` binary and an in-process loopback synthetic provider. Extend the
existing first native test to assert explicit slash expansion of a shared Skill
body before the model/tool round trip. No extra test process or CI job is added.

A separate isolated probe loaded the actual updated `harness` Skill with
`/harness status`. Its body reached the first model request. A control request
without the slash included only metadata, not the body. Both returned exit zero
against a fixed synthetic response with one loopback request. This proves client
expansion, not autonomous agent selection or execution of the Skill's operations.
No real account, provider, model or inference credential was used.

Reproduce the maintained checks with:

```sh
nix shell --no-write-lock-file --inputs-from . nixpkgs#bun nixpkgs#python3 \
  --command bun test tests/skill-tools.test.ts tests/harness-runtime.test.ts
```

For the existing native tests, build the pinned `deepseek-harness` flake output
without activation and set `HARNESS_TEST_DSH_BINARY` to its `bin/dsh` executable
when running `bun test tests/harness-runtime-native.test.ts` in the same pinned
Bun environment. The native test never contacts a real provider.

| Check        | Assessment                               | Evidence                                                                                                                                                 |
| ------------ | ---------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Format       | OK                                       | Skill validator: zero errors and warnings; existing metadata/reference regression now includes `harness`                                                 |
| Intent       | OK                                       | Host/runtime lifecycle stays in `harness`; context-only recovery stays in `session-handoff`                                                              |
| Behavior     | OK for the documented component sequence | Actual Core CLI help matches stop/capture/guarded-create shapes; Core lifecycle tests cover the gate; one-operation live handoff remains unverified      |
| Dependencies | Partly verified                          | Mac pinned dsh slash expansion and synthetic tool flow passed; CLI capability checks remain mandatory; other clients and live remote topology unverified |
| Structure    | OK                                       | Type 2 single Skill plus the existing checkpoint reference; shared source remains `agents/skills/`                                                       |
| Discovery    | Unverified                               | Explicit dsh slash expansion measured; automatic selection and Claude/Codex trigger behavior not measured                                                |
| Duplication  | OK                                       | Keep operation authority in Core and context-only recovery in `session-handoff`; no second command registry or ledger                                    |

Self-review used the Skill Builder quality checklist and post-review workflow
in the current agent. Corrected stop-path ambiguity and approval ordering; no
outstanding critical/warning findings. Verdict: Ready for this scoped shared
workflow change. Published-head hosted Linux checks will be recorded separately.

## Remaining work

An external controller still needs to compose transfer, restore, approval,
guarded successor creation and dispatch. The current dispatch adapter's local
filesystem boundary is unchanged. Live cross-host execution and native account
adoption remain unverified. Real registrations and subscription acceptance stay
with the owner's joint adoption test. No production activation or merge.

## Approved successor dispatch follow-up

Connect the existing Skill to Core's new `dispatch resume --predecessor`
operation after explicit restore and current destination Contract approval.
The service composes guarded creation, readiness, start and dispatch with stable
request identities. Do not send a merely `created` Attempt to `dispatch run`.
Keep explicit capability discovery and receipt-derived predecessor selection.
Document unknown-usage budget refusal and inspection after preparation failure.
No new runtime, registry, permission or deployment is introduced.

The validator reports zero errors/warnings and actual Core CLI help matches the
new resume invocation. Local Bun 1.4.2 ran the 18 relevant Skill/runtime tests:
17 passed in the permitted run; the trigger fixture hit the default five-second
test limit. Rechecking only that fixture with a 20-second test limit passed in
10.399 seconds. The earlier sandbox run was denied process-group signaling and
is not a product failure. No production timeout or test source was changed.

The actual updated Skill body expanded into one loopback request on pinned dsh
0.2.1-rc.2 and exited zero in a 60-second diagnostic probe. A first 20-second
probe produced no request and its reporter failed before recording exit status.
The ordinary-prompt control then failed the launcher's existing five-second
version probe. Do not count that control as passed or infer autonomous Skill
discovery. The previous revision's control remains historical evidence only.
No real provider or credential was used. Core native acceptance and hosted
published-head checks are still in progress.

On 2026-10-27, recovered the same published base and changed files into an
independent clone after the earlier temporary object's alternate store lost
objects. Committed path bytes and symlink contents match the saved checkout.
The second ordinary-prompt control did finish before interruption: exit zero,
one synthetic request, metadata present and body absent. The earlier failed
control remains a failed run; automatic Skill discovery is still unverified.
Fresh local checks passed: 18 tests, zero failures, 74 assertions in 4.75 seconds.
The validator reports zero errors/warnings. Pinned treefmt and its fail-on-change
check passed with the cache disabled to keep cache writes out of the user home.
Published-head evidence follows in the PR. No activation or merge.
