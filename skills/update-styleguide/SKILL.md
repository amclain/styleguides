---
name: update-styleguide
description: Update the style guide to the latest version. Use when the user says "update styleguide", "update style guide", "pull styleguide", or "update formatting rules".
---

# Update Styleguide

Pull the latest style guide changes from the remote repository.

## Finding the Styleguide Repo

Check memory for `styleguides_repo_path`. If not in memory, derive it from the `@` import in the project's CLAUDE.md - strip `general/CLAUDE.md` from the path to get the repo root. If no `@` import exists, check `deps/styleguides/`.

## Update Procedure

1. `cd` into the styleguides repo directory
2. Run `git pull --ff-only`
3. If successful:
   - Re-copy skills to the project's `.claude/skills/` (they may have been updated)
   - Report what changed: number of new commits, or "already up to date"
4. If `--ff-only` fails (diverged history):
   - Inform the user: "The style guide has diverged from the remote. This may need manual resolution."
   - Do not force-pull or reset
5. If the remote is unreachable (offline, network error):
   - Inform the user: "Could not reach the remote repository. The existing style guide version will continue to be used."
   - Continue without error - this is not a failure

## Re-copying Skills

After a successful pull, update the project's local skill copies:

```
cp <repo_root>/skills/format-code/SKILL.md .claude/skills/format-code/SKILL.md
cp <repo_root>/skills/format-review/SKILL.md .claude/skills/format-review/SKILL.md
cp <repo_root>/skills/format-rewrite/SKILL.md .claude/skills/format-rewrite/SKILL.md
cp <repo_root>/skills/style-report/SKILL.md .claude/skills/style-report/SKILL.md
cp <repo_root>/skills/update-styleguide/SKILL.md .claude/skills/update-styleguide/SKILL.md
```

This ensures the project has the latest skill versions after an update.
