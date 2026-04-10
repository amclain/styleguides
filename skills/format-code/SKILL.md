---
name: format-code
description: Fix code style violations autonomously. Use when the user says "format", "fix style", "clean up code", or as a post-generation formatting pass. This is the mode code generators must use for post-generation review.
---

# Format Code

Fix style violations in the project's code autonomously. Do not prompt the user for each change - apply all fixes directly, run tests, and report a summary.

This skill is a thin entry point. The orchestration logic (task decomposition, model assignments, required reading, scope handling, group cohesion exceptions, quality signals) lives in `general/review-orchestration.md`. This file specifies only the fix-mode behavior that wraps the framework.

## Loading the Style Guide

The style guide must be loaded before reviewing. Derive the styleguides repo path from one of:
1. The `@` import in the project's CLAUDE.md (strip `general/CLAUDE.md` to get the repo root)
2. The `deps/styleguides/` directory if it exists

Read these files in full (single Read call per file, no offset or limit, per the "Reading This Guide" rule in `general/CLAUDE.md`):

1. `<repo_root>/general/CLAUDE.md` - general principles, operating modes, and the "Reading This Guide" rule
2. `<repo_root>/general/review-orchestration.md` - the multi-agent orchestration framework and per-language instantiations
3. `<repo_root>/<lang>/CLAUDE.md` - the language guide for the files being reviewed
4. `<repo_root>/<lang>/testing.md` - if any file in scope is a test file (typically `@` imported; load explicitly if not)
5. Any additional mechanics references the language guide specifies for frameworks in use

Do not improvise the orchestration or substitute training-data patterns for the rules. The framework captures specific failure modes that generic approaches miss.

## Mode: Fix

This skill operates in fix mode. It produces corrections and applies them directly, rather than presenting suggestions for user approval. Use `format-review` for the interactive review mode.

## Procedure

1. **Load the style guide** per the section above.
2. **Determine scope** per Section 3 Step 1 of the orchestration framework. Default is changed lines only (`git diff` and `git diff --staged`); `--all` reviews the entire codebase.
3. **Follow the framework** - produce a task manifest per Section 3 Steps 2-5, launch tasks per Step 6, compile results per Step 7. The framework specifies which tasks, which models, which files to read, and how to filter findings to the scope.
4. **Apply fixes** - the lead agent applies all confirmed violations directly using the Edit tool. Follow the framework's rule that the lead does not delegate style fixes to subagents (Sonnet lacks the judgment to distinguish similar cases).
5. **Run post-edit checks** - after applying fixes, re-run Task 1.1 with the language's post-edit checks (line length, anything else the language marks as post-edit) and feed the results through Task 1.6 again. Apply any verification fixes.
6. **Run the project's test suite** - style corrections must not change behavior.
7. **If tests fail**, diagnose and fix. Verify again that tests pass.
8. **Report a summary** of changes: file, rule, what was fixed.

## Important

- Do NOT delegate style fixes to Sonnet subagents. The lead applies all fixes directly. This is enforced by the framework.
- Do NOT change program logic or behavior - only fix style.
- ESpec matchers (`be_integer()`, `be_alive()`, `be_truthy()`) are function calls - do NOT remove their parentheses.
- Trailing commas are valid in collections but NOT in function argument lists.
- When in doubt about whether something is a violation, leave it as-is.
- Apply the framework's group cohesion exception: if a change is part of a group of related code, evaluate the group as a whole. This may mean touching unchanged lines within the group to maintain visual consistency.

## When Used as Post-Generation Review

When invoked as a subagent after code generation, scope to all files the generator created or modified. The generator should pass the list of files. Use `--all` semantics for those files (review the full content), since this is cleaning up the agent's own output rather than reviewing an existing codebase.
