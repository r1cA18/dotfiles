# Checkpoint handoff

Dependencies: Orca MCP or the installed Orca CLI; a built `harness-core` containing
`checkpoint create|verify|restore`; Git; an authorized artifact transfer path.
Use the operator-provided Core executable on each host. Do not install global
packages or assume identical executable paths, repositories or account homes.

## Stop, capture, restore, continue

1. Read source and destination terminal state from the correct Orca host
2. Save a concise context: objective, decisions, constraints, tests, remaining work
3. Resolve destination capability and runtime/profile/group before stopping work
4. From a controller outside the source workspace request Orca's workspace-wide
   terminal close and require its confirmed-success result. A timeout, disconnected
   host or `unverifiable` result is `outcome_unknown`. Do not start a successor
5. Run `harness-core --json checkpoint create --input <request.json> --destination <new-package>` on the source host after stopping all writers
6. Retain the returned digest independently of the transferred package
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

```json
{
  "schema_version": 1,
  "selection": {"runtime": "dsh", "profile": "personal.default", "group": "personal"},
  "context": "Continue the current task. The failing check and next action are ...",
  "repositories": [
    {"name": "app", "path": "/absolute/source/repo", "untracked": ["notes/task.md"]}
  ],
  "assets": [
    {"path": "input/sample.json", "source": "/absolute/input/sample.json"}
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
