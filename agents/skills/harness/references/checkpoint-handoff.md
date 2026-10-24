# Checkpoint handoff

Dependencies: Orca MCP or the installed Orca CLI; a built `harness-core` containing
`checkpoint create|verify|restore`; Git; an authorized artifact transfer path.
The standalone controller supports the observed local workspace-close protocol
on Orca 1.4.215 and 1.4.219. Core-managed dispatch requires a version supported
by its installed adapter. Other versions need adapter revalidation rather than
an automatic fallback to raw terminal close.
Use the operator-provided Core executable on each host. Do not install global
packages or assume identical executable paths, repositories or account homes.

## Choose the control path

Determine whether Core owns the source Task before stopping it. For Core-managed
work retain the Task ID, Attempt ID, original immutable DispatchPlan, and trusted
Workspace/operator ledgers. Follow the Core sequence below. Require the installed
Core to expose `dispatch stop`, `dispatch capture` and
`attempt create --predecessor` in its help. A missing capability blocks
continuation; do not substitute a workspace-wide close, direct runtime launch
or unguarded creation.

Run ledger operations in the trusted controller context. Keep operator and
Workspace ledgers, approval keys and publishing credentials off Workers. The
current dispatch adapter requires its local filesystem and Orca runtime; plain
SSH or a paired remote Orca connection does not make that adapter remote-capable.
If the selected topology is unsupported, report the missing boundary and prepare
only the work that can be saved safely. Do not copy ledgers to make it work.

For standalone Orca work use `handoff capture|show` and the standalone sequence
below. If Core ownership or its recorded inputs are unknown, resolve that state
before choosing a stop path.

## Core-managed stop, capture, restore, continue

1. Save the objective, accepted decisions, constraints, checks and next action.
   Resolve the destination profile and data/group permission before transferring
   anything. Keep the source group in the capture request; destination overrides
   require their own permitted placement
2. Use an authorized controller outside the source worktree and its terminals.
   Stop the recorded execution using the original plan and stable request ID:

   ```sh
   harness-core --json dispatch stop \
     --ledger <workspace-ledger> --operator-ledger <operator-ledger> \
     --orca <absolute-source-cli> --task <task-id> --attempt <source-attempt-id> \
     --request-id <stop-request-id> --input <source-plan.json> \
     --reason 'Continue in a new Attempt'
   ```

   Require recorded confirmed termination. `cancelled` alone or explicit human
   reconciliation is not backend stop evidence. An unknown result retains the
   old budget hold and blocks a successor. Do not close the whole worktree
3. Preserve selected work with the same original plan:

   ```sh
   harness-core --json dispatch capture \
     --ledger <workspace-ledger> --operator-ledger <operator-ledger> \
     --orca <absolute-source-cli> --task <task-id> --attempt <source-attempt-id> \
     --request-id <capture-request-id> --input <source-plan.json> \
     --checkpoint-input <checkpoint-request.json> --destination <new-capture-directory>
   ```

   Include the primary repository at the plan's materialized
   `repositories/<primary_repository>` path. All selected repositories and
   assets must belong to that materialization. Require the returned receipt to
   match the source Task/Attempt and plan digest. This operation checks recorded
   stop evidence and does not close another terminal or launch a successor
4. Retain the private receipt in the controller. Transfer only its `checkpoint/`
   package through the authorized path, with `checkpoint_digest` sent through the
   trusted control channel. Use the checkpoint verify/restore commands in the
   standalone sequence below, import through Orca and run project checks.
   Restoring files does not create execution authority
5. Prepare a new destination DispatchPlan and obtain the required current
   Contract approval for changed inputs or placement. Create the successor in
   the same Task with the source Attempt ID from the capture receipt:

   ```sh
   harness-core --json attempt \
     --ledger <workspace-ledger> --operator-ledger <operator-ledger> create \
     --task <task-id> --request-id <resume-request-id> \
     --predecessor <closed-source-attempt-id>
   ```

   `predecessor_conflict` means the Task advanced. Inspect the Task rather than
   replacing the expected ID automatically. Replaying the same request ID and
   predecessor returns its recorded successor even after later Attempts. Changing
   the predecessor for that ID is `request_conflict`. Require the returned
   predecessor to match the receipt. A `created` Attempt has not started a worker
6. Resolve the destination's native login reference and group again. Start the
   new Attempt through the matching approved `dispatch run` plan. Report the
   actual execution receipt; never reuse the old execution effect or claim native
   session continuity. Unsupported remote dispatch remains incomplete

Stop replay requires the same request ID and reason; capture replay requires the
same request and output directory. Exact replay reads durable results without
another close or capture. A partial/corrupt output or lost termination result
requires inspection and reconciliation; a fresh request ID/directory is not an
automatic retry. Keep terminal Attempts closed. This sequence uses the existing
services separately; it is not a one-command cross-host controller or a new daemon.

## Standalone Orca stop, capture, restore, continue

1. Read source and destination terminal state from the correct Orca host
2. Save a concise context: objective, decisions, constraints, tests, remaining work
3. Resolve destination capability and runtime/profile/group before stopping work
   using `harness-profile doctor --manifest <catalog> --bindings <device-file>
   --group <group> --profile <profile>` on that host. Doctor validates declarations;
   `ready` does not prove native login or inference. Confirm those separately
4. From a controller outside the source workspace and its terminals run
   `harness-core --json handoff capture --input <capture-request.json> --destination <new-operation> --orca <absolute-source-cli>`
   on the source host. This can be invoked over SSH. Use `orca-ide` on Linux
5. Require `state: captured`. Core records the stop intent, confirms Orca's
   workspace-wide close and then creates `<new-operation>/checkpoint`. A timeout,
   disconnected host or unverifiable receipt never permits successor start
6. Retain `checkpoint_digest` independently of that package. Use
   `harness-core --json handoff show --source <operation>` to inspect an incomplete receipt. Exact completed replay
   verifies the artifact without stopping newly created terminals. Incomplete
   operations need manual reconciliation; do not pick a fresh directory to retry
7. Transfer the package through an authorized private path. Copy only
   `manifest.json` and its referenced `blobs/<sha256>` objects. Never copy account
   homes, SSH keys, ignored files, live databases or raw transcripts
8. Run `harness-core --json checkpoint verify --source <package> --digest <expected-digest>` on the destination
9. Run `harness-core --json checkpoint restore --source <package> --destination <new-workspace> --digest <expected-digest>`
10. Import the restored repository/folder through the installed Orca API. Retain
    existing project identity when the destination has a ready host setup
11. Apply the current project instructions and required build checks. Re-resolve
    the selected profile through destination device bindings before runtime start
12. Start the configured runtime through Orca. Confirm the actual receipt and
    report worktree/terminal IDs and the checkpoint digest

For a branch omit the source stop and use separate task and publication authority.
For self-handoff without an outside controller stop at a prepared checkpoint;
repeat capture after confirmed termination before starting a successor.

## Create request

Use version 1 JSON. Source paths are host-local and do not enter the portable
manifest. Always list required untracked paths explicitly; do not select all
untracked paths as a convenience. Assets support work without a repository.

For `handoff capture`, wrap this request as
`{"source_worktree":"/absolute/source/worktree","checkpoint":<request>}`. All
selected inputs must be within that one stopped Orca worktree. Keep the operation
directory outside it. The private capture receipt is not a portable artifact.
For a branch use `checkpoint create` directly and preserve the source terminals.

```json
{
  "schema_version": 1,
  "selection": {"runtime": "dsh", "profile": "personal.default", "group": "personal"},
  "context": "Continue the current task. The failing check and next action are ...",
  "repositories": [
    {"name": "app", "path": "/absolute/source/worktree/repo", "untracked": ["notes/task.md"]}
  ],
  "assets": [
    {"path": "input/sample.json", "source": "/absolute/source/worktree/input/sample.json"}
  ]
}
```

Restore produces `repositories/<name>`, `assets/<path>` and `handoff.json`.
Repositories retain commit objects and staged/unstaged differences and restore
with detached HEAD. No original remote URL or credential configuration is copied.
Restore never runs setup hooks, installs a skill or starts an agent. Reconnect to
an original native session requires that runtime's independent resume capability.

Checkpoints currently require POSIX filesystems. Git submodules must be separate
repository entries. Repository filters such as LFS require an asset adapter and
are refused. Limits: 32 repositories, 1024 selected untracked paths per repository,
1024 standalone assets, 256 MiB per object and 512 MiB total referenced objects.
A checkpoint does not capture ignored build output, external object storage,
running processes or all files in an account home.
