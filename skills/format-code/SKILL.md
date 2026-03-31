---
name: format-code
description: Fix code style violations autonomously. Use when the user says "format", "fix style", "clean up code", or as a post-generation formatting pass. This is the mode code generators must use for post-generation review.
---

# Format Code

Fix style violations in the project's code autonomously. Do not prompt the user for each change - apply all fixes directly, run tests, and report a summary.

## Loading the Style Guide

The style guide must be loaded before reviewing. Derive the styleguides repo path from one of:
1. The `@` import in the project's CLAUDE.md (strip `general/CLAUDE.md` to get the repo root)
2. The `deps/styleguides/` directory if it exists

Read these files in order:
1. `<repo_root>/general/CLAUDE.md` - general principles and operating modes
2. The language guide detected from file extensions (e.g. `<repo_root>/elixir/CLAUDE.md`)
3. Any `@` imports at the top of the language guide (e.g. `elixir/testing.md`)

The style guide contains all the rules. Apply them as documented.

## Scope

Default: only files changed since the last commit (`git diff` and `git diff --staged`). Read full files for context but fix only code in the changed lines. Do not reformat pre-existing code that was not touched by the generator - even if it has style issues. Pre-existing code is the project author's responsibility. Reformatting untouched code creates noise in diffs and may change intentional formatting choices.

If invoked with `--all`, review the entire codebase.

## Procedure

1. Load the style guide (see above)
2. Identify changed files via `git diff --name-only` and `git diff --staged --name-only`
3. Read each changed file
4. Identify style violations against the loaded rules
5. Fix each violation using the Edit tool
6. After all fixes, run the project's test suite
7. If tests fail, diagnose and fix - style corrections must not change behavior
8. Report a summary of changes (file, rule, what was fixed)

## Important

- Do NOT change program logic or behavior - only fix style
- ESpec matchers (`be_integer()`, `be_alive()`, `be_truthy()`) are function calls - do NOT remove their parentheses
- Trailing commas are valid in collections but NOT in function argument lists
- When in doubt about whether something is a violation, leave it as-is

## When Used as Post-Generation Review

When invoked as a subagent after code generation, scope to all files the generator created or modified. The generator should pass the list of files. Fix everything - this is cleaning up the agent's own output, not reviewing human code.
