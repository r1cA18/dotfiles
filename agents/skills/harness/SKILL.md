---
name: harness
description: Allocate work, reconnect, branch, or move unfinished work between local and cloud hosts or agent runtimes through Orca and verified Core checkpoints. Use for /harness offload, handoff, reconnect, branch, or status. Use session-handoff for context recovery without host or runtime lifecycle changes.
---

# Harness

Manage development sessions through Orca MCP when its operations are available.
Otherwise load the installed `orca-cli` skill and use its version-matched CLI.
Use Core's external `handoff capture` controller for stop-and-capture and
checkpoints for portable source and context. Do not build a scheduler,
terminal UI, second task ledger, or OS-name routing policy.

Respect the active product's delegation policy. This skill does not authorize
sub-agents, external model calls, new paid resources, credential copying, policy
changes, or production activation. Preparing a handoff is distinct from starting
its receiving agent. Do not invoke another agent to bypass a single-agent rule.

## Interpret the request

Accept the intent and independent overrides, for example:

- `/harness offload --host <host>`
- `/harness handoff --host <host> --runtime <runtime> --profile <profile> --group <group>`
- `/harness reconnect --host <host>`
- `/harness branch --host <host>`
- `/harness status`

These are skill arguments interpreted by the active agent, not a second native
command registry. dsh exposes user-invocable skills through `/name`; use the
active client's supported skill gesture elsewhere.

Preserve runtime, model profile and group unless the owner explicitly overrides
them. A profile selects model and connection; a runtime selects the harness.
Resolve the profile against the destination's device binding. Never silently
change group, model, billing route or runtime because a binding is unavailable.
Check the current group and destination account assignment before sending work.
For native Codex/Claude profiles use `harness-profile resolve-core` with the
selected destination's private binding and operator ledger. Follow
[profile setup](../../../docs/guides/model-connections.md) for its explicit
references. Its result is advisory plan input, not an execution approval or proof
of login. For Core-managed execution use the approved `DispatchPlan` and
`dispatch run`; never convert `registry_checked` into start authority.
A group override requires the existing policy to permit the source data there.
Missing authority blocks execution, not preparation of a private local artifact.

## Discover and select

Read Orca's hosts, project host setups and terminal state. Prefer explicit
selectors and copy full IDs from tool results. For automatic allocation choose
from existing eligible hosts using required tools, device access and observed
available resources. Do not infer eligibility from `darwin` or `linux`.
Do not install a new server or create a cloud machine to satisfy a missing host.

Distinguish a registered SSH target from a paired remote runtime. Use a ready
project host setup or a paired runtime accepted by the installed API. A successful
plain SSH connection does not prove Orca can create its remote terminal.
A disconnected or unsupported target is unavailable, not permission to route to
another account. Report the missing connection and continue preparatory work.

## Execute one operation

For `status`, report host, worktree, terminal, selected runtime/profile/group,
checkpoint digest and known blockers. Preserve unknown states as unknown.

For `reconnect`, attach the existing terminal on its execution host. Do not
create another runtime. Use native resume only when the installed driver has
verified that capability for this account and session.

For `offload`, prepare a new worktree or folder on the selected host through
Orca. Resolve the destination profile. Start through the configured runtime
launcher and report the full worktree ID and terminal receipt. An accepted input
is not proof of an agent turn or task completion. Never resend on silence.

For `handoff`, read [checkpoint handoff](references/checkpoint-handoff.md).
Use the same sequence for both directions and for a runtime/group change on the
same host. Continue only after confirmed source termination and verified restore.
If the source is the terminal running this agent, arrange an already-authorized
controller outside that worktree before calling `handoff capture`. Without one save
the context and checkpoint and report `prepared`; do not kill the only controller
or claim a completed live handoff. No receiving agent may start in that state.

For `branch`, preserve the source session and restore into a distinct worktree.
Treat this as a separate task and do not grant it the source's publish authority.

For Core-managed tasks retain the Task ID and record a successor Attempt through
the existing service before continuing. Retain Contract and policy bindings;
checkpoint restoration grants neither execution nor publication authority.
If required approval does not cover the new binding, prepare its existing Core
approval request instead of rewriting the old Contract or ledger.

## Report truth

Report `prepared`, `source_stopped`, `restored`, `input_accepted` or `turn_started`
according to actual receipts. A checkpoint is an artifact, not an ownership
lease. Source stop confirmation is not permanent publication fencing. Do not
claim outage-safe migration, native-session cloning or exclusive ownership until
the corresponding Core dispatch and Publisher enforce those properties.

A capture receipt of `captured` means the source was stopped before that artifact
was made. It does not mean restored or resumed. Repeating a completed capture
only verifies its existing artifact. For any incomplete receipt inspect
`handoff show` and reconcile manually; never retry by selecting a fresh operation
directory automatically.
