---
name: add-skill
description: "Add an external skill from GitHub to dotfiles with Nix management and pack assignment"
argument-hint: "<github-url or owner/repo>"
allowed-tools: "Bash,Read,Write,Edit,AskUserQuestion,Agent,WebFetch,Grep,Glob"
---

Add an external GitHub skill to the Nix-managed skill system.

Input: $ARGUMENTS (GitHub URL or owner/repo format)

## Step 1: Parse input

Accept any of these formats:
- `https://github.com/ParthJadhav/app-store-screenshots`
- `github.com/ParthJadhav/app-store-screenshots`
- `ParthJadhav/app-store-screenshots`

Extract owner and repo name.

## Step 2: Investigate the skill

Use WebFetch to read the GitHub repo:
- README.md for description and purpose
- Find SKILL.md files (check `skills/`, root, or nested directories)
- Check if it's a skill (has SKILL.md) or a plugin (has plugin.json)
- Identify what the skill does and which domain it belongs to

If it's a **plugin** (has plugin.json), inform the user:
"This is a full plugin, not a skill. Install with: `claude plugin install <name>`"
Then offer to add it to the appropriate pack's `plugins` list in skill-packs.nix.
Stop here for plugins.

## Step 3: Determine configuration

Figure out:
- The `subdir` where SKILL.md lives (e.g., "skills", ".", or nested path)
- The skill ID(s) that will be discovered
- Whether `filter.maxDepth` is needed

## Step 4: Select pack

Use AskUserQuestion to ask which pack this skill belongs to:

Options based on the skill's purpose:
- ios (Swift/iOS/macOS development)
- web (Web frontend, React, TypeScript)
- media (Video, audio, image processing)
- research (Academic, papers, literature)
- publishing (Articles, blog, SNS)
- vault (Knowledge management)
- global (Always loaded, no pack)
- new pack (Create a new pack for this)

Pre-select the most likely pack based on Step 2 analysis.

## Step 5: Apply changes

### 5a. Add flake input

Edit `~/dotfiles/flake.nix`, add to inputs section:

```nix
# <description from README>
<repo-name> = {
  url = "github:<owner>/<repo>";
  flake = false;
};
```

Place it near the other skill inputs (anthropic-skills, difit-skills).

### 5b. Add source to agent-skills.nix

Edit `~/dotfiles/nix/home-manager/programs/agent-skills.nix`:

Add to `sources`:
```nix
<repo-name> = {
  path = inputs.<repo-name>;
  subdir = "<subdir>";  # where SKILL.md lives
};
```

If the skill should be global, also add to `skills.enable`:
```nix
enable = [ ... "<skill-id>" ];
```

### 5c. Add to pack (if not global)

Edit `~/dotfiles/nix/lib/skill-packs.nix`:

Add the skill ID to the selected pack's `skills` list.

### 5d. Update skill-packs.nix source references

If the skill-packs.nix `mkSkillPacksLib` in flake.nix needs the new source, update the `sources` attrset there too.

## Step 6: Verify

Run:
```bash
cd ~/dotfiles && nix flake update <repo-name> && nix build .#darwinConfigurations.RMB.system --dry-run
```

If evaluation succeeds, report success.

## Step 7: Commit

Stage and commit all changed files:
```bash
cd ~/dotfiles && git add flake.nix flake.lock nix/home-manager/programs/agent-skills.nix nix/lib/skill-packs.nix
git commit -m "feat(skills): add <skill-name> to <pack> pack"
```

The auto-rebuild hook will run `dr` automatically after commit if .nix files changed.

## Step 8: Summary

Print:
- Skill name and description
- Pack assignment
- Committed (hash)
