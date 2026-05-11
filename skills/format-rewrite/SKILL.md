---
name: format-rewrite
description: Rewrite a codebase (or monorepo subdirectory) to match the style guide, ignoring codebase precedence. Use when the user says "rewrite", "reformat the project", "/format-rewrite", or after scaffolding a new project whose boilerplate should be rewritten rather than learned from.
---

# Format Rewrite

Rewrite the project's code to match the style guide as written. Unlike `format-code` (default fix mode), this skill does NOT defer to codebase precedence - it treats existing patterns as candidates for rewriting, not as established conventions to respect.

Typical use: a freshly scaffolded project whose existing patterns came from a generator (Mix, Nerves, `west init`, etc.) rather than from the team's considered style. The setup developer runs this once; subsequent developers pull the rewritten codebase and use `format-code` / `format-review` normally.

This skill is a thin entry point. The orchestration logic (task decomposition, model assignments, required reading, scope handling, quality signals) lives in `general/review-orchestration.md`. This file specifies only the rewrite-mode behavior that wraps the framework.

## Loading the Style Guide

Same as `format-code`. Derive the styleguides repo path from the `@` import in the project's CLAUDE.md or from `deps/styleguides/`. Read in full (single Read call per file, no offset or limit). If the Read tool errors that a file exceeds its size limit, read it in sequential chunks via `offset`+`limit` and treat the union as a single full read; do not skip the file or read only part of it.

1. `<repo_root>/general/CLAUDE.md`
2. `<repo_root>/general/review-orchestration.md`
3. `<repo_root>/<lang>/CLAUDE.md`
4. `<repo_root>/general/testing.md` if any test files are in scope (cross-language testing principles)
5. `<repo_root>/<lang>/testing.md` if any test files are in scope
6. Any additional mechanics references the language guide specifies

## Mode: Rewrite

This skill passes `--all --rewrite` to the orchestration framework:

- `--all` - every file in scope, not just changed lines.
- `--rewrite` - the Code Style Pass (Task 1.5) skips the codebase-precedence check. The guide is applied as written. Patterns the codebase uses consistently but that deviate from the guide ARE flagged and fixed.

### Exhaustive Apply

The reviewers produce findings; the lead consolidates them into the apply list at compile-results (Procedure Step 7 below); then the apply phase (Procedure Step 8 below) executes that list exhaustively.

Compile-results is where the lead's judgment lives. The lead may (and should) filter reviewer false positives - a finding that misreads the code, applies the wrong rule, or proposes a fix that introduces a different violation. False-positive filtering at compile-results requires stating the reasoning: which finding, why it is a false positive, what the lead reviewed to make that call. The filtered list becomes the apply list.

Once compile-results produces the apply list, the apply phase is mechanical. The lead has no authority to skip, defer, or reclassify items at apply time. A finding made it through compile-results because the lead already judged it real; reaching for "this one is cosmetic" or "this list is too large to be practical" at the apply phase is reopening a decision that was already closed.

Partial apply contaminates the codebase in a way that breaks the dev-phase pipeline. Downstream review stages (test validation, logic review, security review) read the post-`--rewrite` tree as the new baseline and produce their own findings against that baseline. If the post-`--rewrite` tree still carries violations the lead silently skipped at apply time, the downstream stages either flag them as inconsistencies (creating noise the lead must triage) or build later changes around them (entrenching the violations and forcing a workflow rollback to the style step when the inconsistency is noticed). The cost of "I'll skip these - they're cosmetic" is not a slightly incomplete diff; it is invalidating every dev-phase stage that ran afterward.

Two specific lead self-narratives the rule rules out at the apply phase:

- "These findings are cosmetic-only and don't affect agent comprehension." Cosmetic-vs-functional is not a category the lead is authorized to construct in `--rewrite` mode. The compile-results step was the place to filter; if a finding is on the apply list, the lead already decided it is a real violation.
- "The list is too large to be practical to apply in one pass." Practicality of a single pass is not the metric. If the apply list is large, split into multiple apply rounds - each round applies its assigned subset exhaustively. Splitting is bookkeeping; truncation is dropping work.

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

4. **Produce the task manifest** per Section 3 Steps 2-5 of the framework, with `--all --rewrite` semantics.

5. **Enumerate dispatches before launching.** Write out the dispatches you are about to make as a numbered list. Each item: task type (1.1-1.6), model, file scope, required reading. Compare your list against the framework's Section 3 Step 4 manifest schema and Step 6 launch rules - count of dispatches, model assignments, dependency ordering. If the list deviates from the framework (fewer dispatches, model substitution, merged tasks, in-context execution of any reviewer task), stop and explain the deviation; do not proceed with it. This step exists because the lead's natural reflex is to optimize away dispatches that "look mechanical" or "don't need an agent." The framework's task breakdown is load-bearing and the cold-context property is what's being preserved, not LLM reasoning. See orchestration framework Section 1.

6. **Launch tasks** per Section 3 Step 6 of the framework. Tasks 1.1, 1.2, 1.3, 1.4, and 1.5 in parallel; Task 1.6 after 1.1 completes.

7. **Compile results** per Section 3 Step 7 of the framework. This is also where false-positive filtering happens for `--rewrite` mode - see § Exhaustive Apply above.

8. **Apply fixes** - the lead agent applies all confirmed violations directly using the Edit tool. This rule covers fix application only, not reviewer-task execution (those remain dispatched per Step 6). Do NOT delegate style fixes to Sonnet subagents. The apply phase is mechanical execution of the post-filter list per § Exhaustive Apply - the lead has no authority to skip, defer, or reclassify items at apply time.

9. **Run post-edit checks** - after applying fixes, re-dispatch Task 1.1 with the language's post-edit checks (line length, anything else the language marks as post-edit), then re-dispatch Task 1.6 to classify the new results. Apply any verification fixes. "Re-dispatch" means launch the task as a fresh subagent per the framework - do not run the checks inline in the lead's context.

10. **Run the project's test suite** - rewrites must not change behavior. If tests fail, diagnose and fix; verify tests pass.

11. **Report a summary** of changes: file count, rules most commonly applied, anything notable. Tell the user to review with `git diff` and commit on their own.

## Git Constraints

Git operations are read-only. This skill reads git state (`git status`, `git diff`, `git log`, `git check-ignore`) but never writes. Do not `git add`, `git commit`, `git stash`, `git restore`, or `git checkout <file>`. After applying fixes, the working tree holds the rewrite as unstaged changes; the user reviews and commits.

This constraint is documented in `general/CLAUDE.md`'s Style Review section and applies to every formatter skill.

## Working Tree State

Rewrites of fresh scaffolds typically run on a dirty working tree - the scaffold generator has just produced boilerplate that hasn't been committed yet. Do not refuse to run on a dirty tree, and do not prompt the user to commit or stash first. The scope confirmation in step 2 is the user's opportunity to back out; once they confirm, proceed.

## Important

- Do NOT execute reviewer tasks (1.1-1.6) in lead context. Every reviewer task is a dispatch, including mechanical-check tasks that look like simple grep/awk runs. The framework's cold-context property requires fresh subagents.
- Do NOT delegate style fixes to Sonnet subagents. The lead applies all fixes directly.
- Do NOT change program logic or behavior - only fix style.
- ESpec matchers (`be_integer()`, `be_alive()`, `be_truthy()`) are function calls - do NOT remove their parentheses.
- Trailing commas are valid in collections but NOT in function argument lists.
- Apply the framework's group cohesion exception where relevant.
- The diff will be large. That is expected. The user runs `/format-rewrite` because they want the full sweep.
