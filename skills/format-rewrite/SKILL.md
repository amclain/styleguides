---
name: format-rewrite
description: Rewrite a codebase (or monorepo subdirectory) to match the style guide, ignoring codebase precedence. Use when the user says "rewrite", "reformat the project", "/format-rewrite", or after scaffolding a new project whose boilerplate should be rewritten rather than learned from.
---

# Format Rewrite

Rewrite the project's code to match the style guide as written. Unlike `format-code` (default fix mode), this skill does NOT defer to codebase precedence - it treats existing patterns as candidates for rewriting, not as established conventions to respect.

Typical use: a freshly scaffolded project whose existing patterns came from a generator (Mix, Nerves, `west init`, etc.) rather than from the team's considered style. The setup developer runs this once; subsequent developers pull the rewritten codebase and use `format-code` / `format-review` normally.

This skill is a thin entry point. The orchestration logic (task decomposition, model assignments, required reading, scope handling, quality signals) lives in `general/review-orchestration.md`. This file specifies only the rewrite-mode behavior that wraps the framework.

## Loading the Style Guide

Same as `format-code`. Derive the styleguides repo path from the `@` import in the project's CLAUDE.md or from `deps/styleguides/`. Read in full:

1. `<repo_root>/general/CLAUDE.md`
2. `<repo_root>/general/review-orchestration.md`
3. `<repo_root>/<lang>/CLAUDE.md`
4. `<repo_root>/<lang>/testing.md` if any test files are in scope
5. Any additional mechanics references the language guide specifies

## Mode: Rewrite

This skill passes `--all --rewrite` to the orchestration framework:

- `--all` - every file in scope, not just changed lines.
- `--rewrite` - the Code Style Pass (§1.5) skips the codebase-precedence check. The guide is applied as written. Patterns the codebase uses consistently but that deviate from the guide ARE flagged and fixed.

## Scope

The skill accepts an optional argument: a path to the top-level directory to rewrite. Absent argument means the whole project.

- `/format-rewrite` - whole project
- `/format-rewrite apps/firmware` - single app in a monorepo
- `/format-rewrite libs/shared_lib` - single library in a monorepo

Paths are interpreted relative to the project root (the cwd Claude was invoked in). File detection filters by language extension within the given scope. If multiple languages are present, run the orchestration once per language.

## Procedure

1. **Load the style guide** per the section above.
2. **Confirm scope with the user.** Before running, print the top-level directory to be rewritten (relative to the project root) and ask the user to confirm. Single prompt, no tool call needed. Example:
   ```
   Rewrite will run on: apps/firmware
   Proceed? (y/n)
   ```
   If the scope is the whole project, print `.` or the project's directory name - whichever reads better. Do not print absolute paths.
3. **On confirmation**, proceed with the framework. On rejection, stop without changes.
4. **Follow the framework** with `--all --rewrite` semantics - produce a task manifest per §3, launch tasks per Step 6, compile results per Step 7.
5. **Apply fixes** - the lead agent applies all confirmed violations directly using the Edit tool. Do NOT delegate style fixes to Sonnet subagents.
6. **Run post-edit checks** - re-run Task 1.1 with post-edit checks, feed through Task 1.6, apply verification fixes.
7. **Run the project's test suite** - rewrites must not change behavior. If tests fail, diagnose and fix; verify tests pass.
8. **Report a summary** of changes: file count, rules most commonly applied, anything notable. Tell the user to review with `git diff` and commit on their own.

## Git Constraints

Git operations are read-only. This skill reads git state (`git status`, `git diff`, `git log`, `git check-ignore`) but never writes. Do not `git add`, `git commit`, `git stash`, `git restore`, or `git checkout <file>`. After applying fixes, the working tree holds the rewrite as unstaged changes; the user reviews and commits.

This constraint is documented in `general/CLAUDE.md`'s Style Review section and applies to every formatter skill.

## Working Tree State

Rewrites of fresh scaffolds typically run on a dirty working tree - the scaffold generator has just produced boilerplate that hasn't been committed yet. Do not refuse to run on a dirty tree, and do not prompt the user to commit or stash first. The scope confirmation in step 2 is the user's opportunity to back out; once they confirm, proceed.

## Important

- Do NOT delegate style fixes to Sonnet subagents. The lead applies all fixes directly.
- Do NOT change program logic or behavior - only fix style.
- ESpec matchers (`be_integer()`, `be_alive()`, `be_truthy()`) are function calls - do NOT remove their parentheses.
- Trailing commas are valid in collections but NOT in function argument lists.
- Apply the framework's group cohesion exception where relevant.
- The diff will be large. That is expected. The user runs `/format-rewrite` because they want the full sweep.
