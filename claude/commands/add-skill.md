---
name: add-skill
description: "Add an external skill from GitHub to dotfiles with global Nix management"
argument-hint: "<github-url or owner/repo>"
allowed-tools: "Bash,Read,Write,Edit,AskUserQuestion,Agent,WebFetch,Grep,Glob"
---

Add an external GitHub skill to the Nix-managed global skill set.

Input: $ARGUMENTS (GitHub URL or owner/repo format)

## Step 1: Parse input

Accept any of these formats:

- `https://github.com/ParthJadhav/app-store-screenshots`
- `github.com/ParthJadhav/app-store-screenshots`
- `ParthJadhav/app-store-screenshots`

Extract owner and repo name.

## Step 2: Investigate the repo

- Read README.md for purpose and dependencies
- Find SKILL.md files
- Determine the source `subdir`
- Determine discovered skill IDs
- If it is a plugin, do not add it as a skill. Tell the user to manage it in the relevant user-level agent config instead.

## Step 3: Apply changes

Add a flake input in `~/dotfiles/flake.nix`:

```nix
<repo-name> = {
  url = "github:<owner>/<repo>";
  flake = false;
};
```

Add a source in `~/dotfiles/nix/home-manager/programs/agent-skills.nix`:

```nix
<repo-name> = {
  path = inputs.<repo-name>;
  subdir = "<subdir>";
};
```

Add every discovered skill ID to `skills.enable`. All skills are global.

## Step 4: Verify

Run:

```bash
cd ~/dotfiles
nix flake update <repo-name>
nix build .#darwinConfigurations.RMB.system --dry-run
```

## Step 5: Summary

Print:

- Skill IDs added
- Source repository
- Verification result
- Reminder to run `dr` if not already applied
