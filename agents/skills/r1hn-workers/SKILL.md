---
name: r1hn-workers
description: >-
  Run heavy or long work on another of the owner's r1hn workers (a home
  server) instead of this machine, and bring the result back: dispatch a
  task in a git repository, watch it, answer its questions and approvals,
  collect the answer and move the session and its workspace back. Use when
  builds, test suites or long agent runs would load this machine, when the
  owner asks to move work or a session to another worker or back, or to see
  which worker has free CPU, memory and disk. Never moves company work.
  Triggers: "run it on the server", "move this to the other machine",
  "dispatch to the worker", "bring it back", "which worker is free".
  日本語トリガー:「サーバーで回して」「向こうのマシンに移して」「ワーカーに投げて」「戻して」「どのマシンが空いてる」「重いビルドを逃がして」
---

# r1hn workers

Each of the owner's machines runs its own r1hnd (a worker) with its own
accounts. Groups are the same on every worker; work moves between workers
inside its group, never across groups. A move carries the session (journal,
client transcript, permission mode) and its git workspace: branch, commits
and uncommitted changes. Ignored files (`.env`, build output) and anything
outside git do not move. Nothing is pushed to GitHub by a move.

## Rules

- Never move or dispatch work of a company group. Groups listed in
  `[worker] stay_groups` are refused by r1hn; if a group looks like company
  work and is not listed, ask the owner before moving it
- Never move a session another agent is using. Move only sessions you made
  or the owner named, and only when they are idle
- Do not edit `config.toml`, tokens or the other worker's checkout by hand
- Never print tokens; r1hn keeps them in its state directory
- Commit work on a branch on the worker; do not push unless the owner asks

## 1. Choose a worker

```bash
r1hn worker list            # every worker: online, CPUs, load, free memory and disk, running sessions
r1hn worker status NAME     # limits per turn, groups that stay, accounts per group
```

Inside a session the view shows your own group only. Prefer the worker
with low load and free memory for builds and test suites. A worker whose
`[worker.limits]` is enforced runs each turn in a capped scope, so a build
there cannot take the whole machine; size the task to those limits (for
example `cargo -j` no higher than its CPUs).

## 2. Dispatch a task

From the repository (the current directory, or `--cwd DIR`):

```bash
r1hn dispatch --to NAME "Run the test suite, fix what fails, commit on branch fix/x"
r1hn dispatch --to NAME --model claude/sonnet --title "tests" "..."
r1hn dispatch --to NAME --wait "..."    # stay and print the turn
```

It prints the session id, the directory and branch on the worker, and the
next commands. Commit or stash what should not travel; untracked files git
does not ignore do travel. Start a branch first (`git switch -c ...`) when
the work should land on its own branch.

To move an existing idle session instead:

```bash
r1hn session move ID --to NAME
```

For isolated work, create the task worktree before dispatch and pass its
path explicitly. Start from the intended base ref:

```bash
git worktree add -b fix/task <task-path> <base-ref>
r1hn dispatch --to NAME --cwd <task-path> "<task>"
```

For work on this machine, start a worktree thread in r1 code or run
`r1hn session start --cwd <task-path>` and follow it with
`r1hn session ask ID "<task>"`. Keep the session ID and returned workspace
path with the task so you can reconnect and review its work.

## 3. Monitor

```bash
r1hn session watch ID            # rows until the running turn ends
r1hn session watch ID --follow   # keep going until stopped
r1hn session list                # here: moved sessions show "moved -> NAME"
```

The commands find the session wherever it runs now; `--worker NAME` names
the worker when the lookup cannot.

## 4. Questions, approvals and more work

```bash
r1hn session reply ID "/allow"              # its open approval (or "/deny")
r1hn session reply ID "Use the second option"
r1hn session ask ID "What is left?"         # send and print the turn
```

`approval ...` and `question ...` rows in `watch` are what it waits for.
Approvals also reach the owner's phone and inbox; do not allow something
the owner would not, ask them instead.

## 5. Collect and bring it back

```bash
r1hn session collect ID          # state, last answer, files it saved
r1hn session collect ID --back   # move it here with its workspace, then the same
```

`--back` is refused while a turn runs: wait with `watch` first. The work
comes back in place when this checkout is clean and behind it, else in a
separate worktree beside the repository; the path and branch are printed.
Review the diff there, then continue here or hand it to the owner.

## Failure handling

| Message | What to do |
| --- | --- |
| `stay on the worker` / `stay_groups` | company or pinned group: run it here, do not work around it |
| `[[dir]] rule` | the directory belongs to another group on the worker: stop and tell the owner |
| `no usable ... account in group` | the worker has no account for that provider: try another `--model`, or ask the owner to log one in there |
| `does not exist on worker` (group) | ask the owner to run `r1hn group sync --from NAME` |
| clone or fetch failed, timed out | the worker cannot reach the remote without a prompt; ask the owner |
| `turn is running` | wait (`watch`) and retry |
| `is moving to` | a move is in flight; retry in a moment. A half-done move: `r1hn session move ID --to NAME` again finishes it, `--cancel` lifts it |
| peer offline, 502 | the worker is down or unreachable: run the work here |
| `Session ... stays here, idle` after dispatch | the move failed; the new session is idle here. Fix the cause and run `r1hn session move ID --to NAME` |
